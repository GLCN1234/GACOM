// Called right after a new order is inserted (from cart_screen.dart). Emails
// everyone in store_staff_roles with can_manage_orders = true so they package
// and approve the order.
//
// Security notes:
//   - the caller must be signed in AND own the order (or be an admin); before,
//     anyone could trigger emails for any order id
//   - everything interpolated into the email is HTML-escaped
//   - at most one notification per order per isolate-minute (rate limit) and
//     a hard cap on managers emailed
import { secureServe, requireUser, rateLimit, serviceClient, fetchWithTimeout, asUuid, escapeHtml, requireEnv, HttpError, ADMIN_ROLES, redact } from '../_shared/security.ts'

const RESEND_ENDPOINT = 'https://api.resend.com/emails'
const FROM_ADDRESS = 'GACOM Store <orders@gamicom.net>'

secureServe('notify-order-received', async (req, ctx) => {
  const { user } = await requireUser(req)
  rateLimit(`notify-order:${user.id}`, 10, 60_000)

  const body = await ctx.readJson()
  const orderId = asUuid(body.orderId, 'orderId')
  const resendKey = requireEnv('RESEND_API_KEY')

  const supabase = serviceClient() // caller authenticated above
  const { data: order } = await supabase.from('orders').select('*').eq('id', orderId).maybeSingle()
  if (!order) throw new HttpError(404, 'Order not found')
  if (order.user_id !== user.id) {
    const { data: prof } = await supabase.from('profiles').select('role').eq('id', user.id).maybeSingle()
    if (!ADMIN_ROLES.includes(String(prof?.role ?? ''))) throw new HttpError(403, 'Not authorised')
  }
  rateLimit(`notify-order-id:${orderId}`, 1, 10 * 60_000) // one email burst per order

  const { data: managers, error: mErr } = await supabase.from('store_staff_roles').select('user_id').eq('can_manage_orders', true).limit(20)
  if (mErr) throw mErr
  if (!managers || managers.length === 0) {
    return ctx.json({ success: true, note: 'No order managers assigned yet — nobody to notify.' })
  }

  // deno-lint-ignore no-explicit-any
  const itemsHtml = (Array.isArray(order.items) ? order.items : []).slice(0, 100).map((i: any) =>
    `<li>Product ${escapeHtml(i.product_id)} × ${escapeHtml(i.quantity)} — ₦${escapeHtml(i.total_price)}</li>`).join('')

  const html = `<!DOCTYPE html><html><body style="font-family:Arial,sans-serif;background:#0a0a0a;color:#eaeaea;padding:24px;max-width:600px;margin:0 auto;">
      <h1 style="color:#ff6b1a;font-size:20px;">New Order — ${escapeHtml(order.reference)}</h1>
      <p>Status: <strong>${escapeHtml(order.status)}</strong></p>
      <p>Delivery to: ${escapeHtml(order.delivery_state ?? 'unspecified')} (est. ${escapeHtml(order.delivery_days ?? '?')} days)</p>
      <ul>${itemsHtml}</ul>
      <p>Subtotal: ₦${escapeHtml(order.subtotal)} · Delivery: ₦${escapeHtml(order.delivery_fee)} · <strong>Total: ₦${escapeHtml(order.total)}</strong></p>
      <p style="color:#888;font-size:12px;">Log in to the admin dashboard to package and approve this order.</p>
    </body></html>`

  let sent = 0
  for (const m of managers) {
    const { data: userRes } = await supabase.auth.admin.getUserById(m.user_id)
    const email = userRes?.user?.email
    if (!email) continue
    try {
      const res = await fetchWithTimeout(RESEND_ENDPOINT, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${resendKey}` },
        body: JSON.stringify({ from: FROM_ADDRESS, to: [email], subject: `New order ${String(order.reference).slice(0, 60)}`, html }),
      }, 10_000)
      if (res.ok) sent++
    } catch (e) {
      console.error('[notify-order-received] send failed:', redact(String(e)))
    }
  }
  return ctx.json({ success: true, notified: sent })
}, { maxBodyBytes: 2 * 1024 })
