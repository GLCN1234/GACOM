// Starts a Paystack checkout for the signed-in user and records the pending
// transaction server side. The secret key lives only in Supabase secrets.
//
// Security notes:
//   - the paying email and the user id come from the verified JWT, not the body
//   - amount (kobo) and reference are validated; callback_url must be on an
//     allowed origin (no open redirect back to an attacker's site)
//   - errors never echo Paystack/database internals
import {
  secureServe, requireUser, requireEnv, rateLimit, serviceClient, fetchWithTimeout,
  asInt, asString, HttpError, isOriginAllowed, redact,
} from '../_shared/security.ts'

const MIN_KOBO = 10_000          // 100 NGN
const MAX_KOBO = 2_000_000_000   // 20,000,000 NGN
const DEFAULT_CALLBACK = 'https://gamicom.net/#/store'

function safeCallback(raw: unknown): string {
  if (typeof raw !== 'string' || !raw || raw.length > 500) return DEFAULT_CALLBACK
  try {
    const u = new URL(raw)
    if (u.username || u.password) return DEFAULT_CALLBACK
    if (isOriginAllowed(u.origin) && (u.protocol === 'https:' || u.hostname === 'localhost' || u.hostname === '127.0.0.1')) return raw
  } catch { /* fall through */ }
  return DEFAULT_CALLBACK
}

secureServe('paystack-init', async (req, ctx) => {
  const { user } = await requireUser(req)
  rateLimit(`paystack-init:${user.id}`, 10, 60_000)

  const body = await ctx.readJson()
  const amount = asInt(body.amount, 'amount', { min: MIN_KOBO, max: MAX_KOBO })
  const reference = asString(body.reference, 'reference', { max: 100, pattern: /^[A-Za-z0-9_.=-]+$/ })
  const email = user.email
  if (!email) throw new HttpError(400, 'Your account has no email address')
  const secretKey = requireEnv('PAYSTACK_SECRET_KEY')

  const res = await fetchWithTimeout('https://api.paystack.co/transaction/initialize', {
    method: 'POST',
    headers: { 'Authorization': `Bearer ${secretKey}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      email,
      amount,
      reference,
      callback_url: safeCallback(body.callback_url),
      channels: ['card', 'bank', 'ussd', 'qr', 'mobile_money', 'bank_transfer'],
    }),
  }, 20_000)
  const data = await res.json().catch(() => ({}))
  if (!data?.status) {
    console.error('[paystack-init] initialize failed:', redact(String(data?.message ?? res.status)))
    throw new HttpError(400, 'Payment could not be started. Please try again.')
  }

  // Service role only after the caller is authenticated and input validated.
  const svc = serviceClient()
  const { data: profile, error: pErr } = await svc.from('profiles').select('wallet_balance').eq('id', user.id).single()
  if (pErr || !profile) {
    console.error('[paystack-init] profile read failed:', redact(String(pErr?.message ?? 'no profile')))
    throw new HttpError(500, 'Could not start payment. Please try again.')
  }
  const balance = profile.wallet_balance ?? 0

  const { error: insErr } = await svc.from('wallet_transactions').insert({
    user_id: user.id,
    type: 'deposit',
    amount: amount / 100,
    balance_before: balance,
    balance_after: balance,
    reference,
    status: 'pending',
    description: 'Wallet funding via Paystack',
  })
  if (insErr) {
    console.error('[paystack-init] pending insert failed:', redact(String(insErr.message)))
    throw new HttpError(500, 'Could not record the payment. Please try again.')
  }

  return ctx.json({
    authorization_url: data.data.authorization_url,
    access_code: data.data.access_code,
    reference: data.data.reference,
  })
})
