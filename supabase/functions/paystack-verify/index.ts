// Confirms a Paystack payment with Paystack itself, then credits the wallet or
// activates an Edu subscription. Previously unauthenticated: anyone could
// trigger crediting for any reference. Now:
//   - the caller must be signed in and the reference must belong to them
//     (wallet_transactions.user_id / edu_subscriptions.user_id)
//   - the amount credited is Paystack's own confirmed amount, never the client's
//   - crediting stays idempotent inside credit_wallet_from_reference
// The same crediting logic runs from the signed webhook (paystack-webhook).
import {
  secureServe, requireUser, requireEnv, rateLimit, serviceClient, fetchWithTimeout,
  asString, HttpError, redact,
} from '../_shared/security.ts'

secureServe('paystack-verify', async (req, ctx) => {
  const { user } = await requireUser(req)
  rateLimit(`paystack-verify:${user.id}`, 30, 60_000)

  const body = await ctx.readJson()
  const reference = asString(body.reference, 'reference', { max: 100, pattern: /^[A-Za-z0-9_.=-]+$/ })
  const secretKey = requireEnv('PAYSTACK_SECRET_KEY')

  const svc = serviceClient() // caller authenticated above

  // The reference must be one of this user's own.
  const isEdu = reference.startsWith('EDU_')
  const { data: owned } = isEdu
    ? await svc.from('edu_subscriptions').select('id, amount, status').eq('reference', reference).eq('user_id', user.id).maybeSingle()
    : await svc.from('wallet_transactions').select('id').eq('reference', reference).eq('user_id', user.id).maybeSingle()
  if (!owned) throw new HttpError(404, 'Payment record not found')

  // A subscription reference activates once. Replaying an old, already-used reference must not
  // grant another month (Paystack keeps reporting that payment as successful forever).
  if (isEdu && owned.status === 'active') return ctx.json({ success: true, subscription: 'active' })
  if (isEdu && owned.status !== 'pending') throw new HttpError(409, 'This payment has already been used')

  const vRes = await fetchWithTimeout(
    `https://api.paystack.co/transaction/verify/${encodeURIComponent(reference)}`,
    { headers: { 'Authorization': `Bearer ${secretKey}` } },
    20_000,
  )
  const v = await vRes.json().catch(() => ({}))
  if (!v?.status || v.data?.status !== 'success') {
    // gateway_response is a short human string from Paystack ("Declined"); safe to relay.
    const msg = typeof v?.data?.gateway_response === 'string' ? v.data.gateway_response.slice(0, 120) : 'Payment not successful'
    return ctx.json({ success: false, error: msg })
  }

  const amountKobo = Number(v.data.amount)
  if (!Number.isFinite(amountKobo) || amountKobo <= 0) throw new HttpError(502, 'Payment provider returned an invalid amount')
  const amountNaira = amountKobo / 100

  if (isEdu) {
    const expectedNaira = (owned.amount ?? 0) / 100
    if (Math.abs(amountNaira - expectedNaira) > 0.01) return ctx.json({ success: false, error: 'Amount mismatch' }, 400)
    const auth = v.data.authorization
    const authCode = auth?.reusable ? String(auth.authorization_code) : null
    const expiresAt = new Date()
    expiresAt.setMonth(expiresAt.getMonth() + 1)
    const { error } = await svc.from('edu_subscriptions').update({
      status: 'active',
      expires_at: expiresAt.toISOString(),
      authorization_code: authCode,
      payment_channel: auth?.channel ? String(auth.channel) : null,
      auto_renew: authCode !== null,
      renewal_failed_count: 0,
    }).eq('reference', reference).eq('user_id', user.id)
    if (error) {
      console.error('[paystack-verify] edu update failed:', redact(String(error.message)))
      throw new HttpError(500, 'Could not activate the subscription. Please contact support.')
    }
    return ctx.json({ success: true, subscription: 'active' })
  }

  const { data, error } = await svc.rpc('credit_wallet_from_reference', { p_reference: reference, p_amount: amountNaira })
  if (error) {
    console.error('[paystack-verify] credit failed:', redact(String(error.message)))
    throw new HttpError(500, 'Could not credit the wallet. Please contact support.')
  }
  return ctx.json(data)
}, { maxBodyBytes: 4 * 1024 })
