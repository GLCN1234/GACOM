// Paystack webhook receiver. Paystack signs the RAW request body with
// HMAC-SHA512 using the account secret key and sends it as x-paystack-signature.
// Nothing happens unless that signature matches (constant-time compare). The
// amount credited is re-confirmed with Paystack's verify API, never taken from
// the webhook body alone. Crediting is idempotent (credit_wallet_from_reference).
//
// Deploy with JWT verification OFF for this function only:
//   supabase functions deploy paystack-webhook --no-verify-jwt
// and set the Paystack dashboard webhook URL to
//   https://<project>.supabase.co/functions/v1/paystack-webhook
import {
  secureServe, requireEnv, serviceClient, fetchWithTimeout, readBodyText,
  hmacSha512Hex, constantTimeEqual, HttpError, redact,
} from '../_shared/security.ts'

secureServe('paystack-webhook', async (req, ctx) => {
  const secretKey = requireEnv('PAYSTACK_SECRET_KEY')
  const raw = await readBodyText(req, 256 * 1024)
  const sig = (req.headers.get('x-paystack-signature') ?? '').toLowerCase()
  const expected = await hmacSha512Hex(secretKey, raw)
  if (!sig || !constantTimeEqual(sig, expected)) throw new HttpError(401, 'Invalid signature')

  let event: { event?: string; data?: { reference?: string } }
  try { event = JSON.parse(raw) } catch { throw new HttpError(400, 'Invalid JSON body') }
  if (event.event !== 'charge.success') return ctx.json({ success: true, ignored: true })

  const reference = event.data?.reference
  if (typeof reference !== 'string' || !/^[A-Za-z0-9_.=-]{1,100}$/.test(reference)) {
    return ctx.json({ success: true, ignored: true })
  }
  // Edu subscriptions are activated by paystack-verify (owner-bound); the
  // webhook only completes wallet deposits.
  if (reference.startsWith('EDU_')) return ctx.json({ success: true, ignored: true })

  const vRes = await fetchWithTimeout(
    `https://api.paystack.co/transaction/verify/${encodeURIComponent(reference)}`,
    { headers: { 'Authorization': `Bearer ${secretKey}` } },
    20_000,
  )
  const v = await vRes.json().catch(() => ({}))
  const kobo = Number(v?.data?.amount)
  if (!v?.status || v.data?.status !== 'success' || !Number.isFinite(kobo) || kobo <= 0) {
    return ctx.json({ success: true, ignored: true })
  }

  const svc = serviceClient() // signature verified above
  const { error } = await svc.rpc('credit_wallet_from_reference', { p_reference: reference, p_amount: kobo / 100 })
  if (error) {
    console.error('[paystack-webhook] credit failed:', redact(String(error.message)))
    throw new HttpError(500, 'Could not process the event') // Paystack will retry
  }
  return ctx.json({ success: true })
}, { maxBodyBytes: 256 * 1024, ipRateLimit: { limit: 300, windowMs: 60_000 } })
