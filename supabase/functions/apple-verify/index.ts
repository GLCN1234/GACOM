// Confirms an iOS In-App Purchase with Apple, then credits the wallet or
// activates Premium. The app only tells us a transaction id; everything that
// matters (product, bundle, expiry) is read from Apple's own servers.
//
// Secrets to set (see the apply instructions):
//   APPLE_ISSUER_ID, APPLE_KEY_ID, APPLE_PRIVATE_KEY (contents of the .p8),
//   APPLE_BUNDLE_ID (com.mobtechsynergies.gacom)
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, 'Content-Type': 'application/json' } })

function b64url(input: ArrayBuffer | Uint8Array | string): string {
  const bytes = typeof input === 'string' ? new TextEncoder().encode(input) : new Uint8Array(input)
  let s = ''
  for (const b of bytes) s += String.fromCharCode(b)
  return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')
}

function decodePayload(jws: string): Record<string, unknown> {
  const part = jws.split('.')[1]
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
  for (const host of ['api.storekit.itunes.apple.com', 'api.storekit-sandbox.itunes.apple.com']) {
    const res = await fetch(`https://${host}/inApps/v1/transactions/${encodeURIComponent(id)}`, {
      headers: { Authorization: `Bearer ${token}` },
    })
    if (res.status === 200) {
      const body = await res.json()
      if (body.signedTransactionInfo) return decodePayload(body.signedTransactionInfo as string)
    }
  }
  return null
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors })
  try {
    const authHeader = req.headers.get('Authorization') ?? ''
    const userClient = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_ANON_KEY')!, {
      global: { headers: { Authorization: authHeader } },
    })
    const { data: userData } = await userClient.auth.getUser()
    const user = userData?.user
    if (!user) return json({ success: false, error: 'Please sign in again' }, 401)

    const { transaction_id } = await req.json()
    if (!transaction_id) return json({ success: false, error: 'transaction_id is required' }, 400)

    for (const k of ['APPLE_ISSUER_ID', 'APPLE_KEY_ID', 'APPLE_PRIVATE_KEY', 'APPLE_BUNDLE_ID']) {
      if (!Deno.env.get(k)) return json({ success: false, error: `Server is missing ${k}` }, 500)
    }

    const tx = await fetchTransaction(String(transaction_id), await appleToken())
    if (!tx) return json({ success: false, error: 'Apple could not confirm this purchase yet. It will retry.' })
    if (tx.bundleId !== Deno.env.get('APPLE_BUNDLE_ID')) return json({ success: false, error: 'Wrong app' }, 400)
    if (tx.revocationDate) return json({ success: false, error: 'This purchase was refunded' })

    const admin = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!)
    const { data, error } = await admin.rpc('apple_apply_transaction', {
      p_user: user.id,
      p_transaction_id: String(tx.transactionId),
      p_original_transaction_id: tx.originalTransactionId ? String(tx.originalTransactionId) : null,
      p_product_id: String(tx.productId),
      p_environment: tx.environment ? String(tx.environment) : null,
      p_expires_at: tx.expiresDate ? new Date(Number(tx.expiresDate)).toISOString() : null,
    })
    if (error) return json({ success: false, error: error.message }, 500)
    return json(data)
  } catch (err) {
    return json({ success: false, error: String(err) }, 500)
  }
})
