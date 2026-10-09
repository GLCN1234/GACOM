// Confirms an iOS In-App Purchase with Apple, then credits the wallet or
// activates Premium. The app only tells us a transaction id; everything that
// matters (product, bundle, expiry) is read from Apple's own servers using the
// App Store Server API (authenticated with our private key, over TLS), so the
// signed transaction we decode comes straight from Apple and not from the client.
//
// Secrets to set (see docs/APPSEC_AUDIT.md):
//   APPLE_ISSUER_ID, APPLE_KEY_ID, APPLE_PRIVATE_KEY (contents of the .p8),
//   APPLE_BUNDLE_ID (com.mobtechsynergies.gacom)
//   APPLE_ALLOW_SANDBOX=true  ONLY while App Review / TestFlight needs it.
//     Sandbox purchases are free, so with this unset they are refused and
//     cannot be turned into real wallet credit.
//
// Security notes:
//   - user identity from the JWT only; the purchase is bound to that user by
//     apple_apply_transaction (a transaction/subscription cannot move accounts)
//   - the product the client claims must match what Apple says it bought
//   - generic errors to the caller; detail only in server logs
import { secureServe, requireUser, requireEnv, rateLimit, serviceClient, fetchWithTimeout, asString, HttpError, redact } from '../_shared/security.ts'

function b64url(input: ArrayBuffer | Uint8Array | string): string {
  const bytes = typeof input === 'string' ? new TextEncoder().encode(input) : new Uint8Array(input)
  let s = ''
  for (const b of bytes) s += String.fromCharCode(b)
  return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')
}

function decodePayload(jws: string): Record<string, unknown> {
  const parts = jws.split('.')
  if (parts.length !== 3) throw new Error('Malformed signed transaction')
  const part = parts[1]
  const padded = part.replace(/-/g, '+').replace(/_/g, '/') + '==='.slice((part.length + 3) % 4)
  return JSON.parse(new TextDecoder().decode(Uint8Array.from(atob(padded), (c) => c.charCodeAt(0))))
}

async function appleToken(): Promise<string> {
  const issuer = Deno.env.get('APPLE_ISSUER_ID')!
  const keyId = Deno.env.get('APPLE_KEY_ID')!
  const bundle = Deno.env.get('APPLE_BUNDLE_ID')!
  const pem = Deno.env.get('APPLE_PRIVATE_KEY')!.replace(/\\n/g, '\n')
  const b64 = pem.replace(/-----[^-]+-----/g, '').replace(/\s+/g, '')
  const der = Uint8Array.from(atob(b64), (c) => c.charCodeAt(0))
  const key = await crypto.subtle.importKey('pkcs8', der, { name: 'ECDSA', namedCurve: 'P-256' }, false, ['sign'])
  const now = Math.floor(Date.now() / 1000)
  const header = b64url(JSON.stringify({ alg: 'ES256', kid: keyId, typ: 'JWT' }))
  const payload = b64url(JSON.stringify({ iss: issuer, iat: now, exp: now + 600, aud: 'appstoreconnect-v1', bid: bundle }))
  const sig = await crypto.subtle.sign({ name: 'ECDSA', hash: 'SHA-256' }, key, new TextEncoder().encode(`${header}.${payload}`))
  return `${header}.${payload}.${b64url(sig)}`
}

async function fetchTransaction(id: string, token: string): Promise<Record<string, unknown> | null> {
  // Real purchases live on the production host; App Review and sandbox
  // testers live on the sandbox host. Try production first.
  const allowSandbox = Deno.env.get('APPLE_ALLOW_SANDBOX') === 'true'
  const hosts = [
    { host: 'api.storekit.itunes.apple.com', env: 'Production' },
    ...(allowSandbox ? [{ host: 'api.storekit-sandbox.itunes.apple.com', env: 'Sandbox' }] : []),
  ]
  for (const { host, env } of hosts) {
    const res = await fetchWithTimeout(`https://${host}/inApps/v1/transactions/${encodeURIComponent(id)}`, {
      headers: { Authorization: `Bearer ${token}` },
    }, 15_000)
    if (res.status === 200) {
      const body = await res.json()
      if (body.signedTransactionInfo) {
        const tx = decodePayload(body.signedTransactionInfo as string)
        // The host we asked must agree with the environment Apple stamped on it.
        if (tx.environment && String(tx.environment).toLowerCase() !== env.toLowerCase()) return null
        return tx
      }
    }
  }
  return null
}

secureServe('apple-verify', async (req, ctx) => {
  const { user } = await requireUser(req)
  rateLimit(`apple:${user.id}`, 20, 60_000)

  const body = await ctx.readJson()
  const transactionId = asString(body.transaction_id, 'transaction_id', { max: 64, pattern: /^[0-9A-Za-z_\-]+$/ })
  const claimedProduct = body.product_id === undefined ? '' : asString(body.product_id, 'product_id', { max: 128, optional: true })

  const bundleId = requireEnv('APPLE_BUNDLE_ID')
  for (const k of ['APPLE_ISSUER_ID', 'APPLE_KEY_ID', 'APPLE_PRIVATE_KEY']) requireEnv(k)

  let tx: Record<string, unknown> | null
  try {
    tx = await fetchTransaction(transactionId, await appleToken())
  } catch (e) {
    if (e instanceof HttpError) throw e
    console.error('[apple-verify] apple lookup failed:', redact(String(e)))
    tx = null
  }
  if (!tx) return ctx.json({ success: false, error: 'Apple could not confirm this purchase yet. It will retry.' })
  if (tx.bundleId !== bundleId) return ctx.json({ success: false, error: 'Wrong app' }, 400)
  if (tx.revocationDate) return ctx.json({ success: false, error: 'This purchase was refunded' })
  if (String(tx.transactionId) !== transactionId) return ctx.json({ success: false, error: 'Transaction mismatch' }, 400)
  if (claimedProduct && String(tx.productId) !== claimedProduct) {
    return ctx.json({ success: false, error: 'Product mismatch' }, 400)
  }

  // Service role only after the caller and the purchase are verified.
  const admin = serviceClient()
  const { data, error } = await admin.rpc('apple_apply_transaction', {
    p_user: user.id, // from the verified JWT, never from the body
    p_transaction_id: String(tx.transactionId),
    p_original_transaction_id: tx.originalTransactionId ? String(tx.originalTransactionId) : null,
    p_product_id: String(tx.productId),
    p_environment: tx.environment ? String(tx.environment) : null,
    p_expires_at: tx.expiresDate ? new Date(Number(tx.expiresDate)).toISOString() : null,
  })
  if (error) {
    console.error('[apple-verify] apply failed:', redact(String(error.message ?? error)))
    return ctx.json({ success: false, error: 'Could not apply this purchase. Please try again.' }, 500)
  }
  return ctx.json(data)
})
