// Called right after a new order is inserted (from cart_screen.dart).
// Emails everyone in store_staff_roles with can_manage_orders = true so
// they know to package/approve the order — this is the "we receive an
// email when an order comes in" piece of the fulfillment workflow.
import { createClient } from 'jsr:@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}
const RESEND_ENDPOINT = 'https://api.resend.com/emails'
const FROM_ADDRESS = 'GACOM Store <orders@gamicom.net>'

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const { orderId } = await req.json()
    if (!orderId) throw new Error('orderId is required')

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    )
    const resendKey = Deno.env.get('RESEND_API_KEY')
    if (!resendKey) throw new Error('RESEND_API_KEY not configured')

    const { data: order, error: orderError } = await supabase
      .from('orders').select('*').eq('id', orderId).single()
    if (orderError) throw orderError

    const { data: managers, error: managersError } = await supabase
      .from('store_staff_roles').select('user_id').eq('can_manage_orders', true)
    if (managersError) throw managersError

    if (!managers || managers.length === 0) {
      return new Response(JSON.stringify({ success: true, note: 'No order managers assigned yet — nobody to notify.' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }

    const itemsHtml = (order.items ?? []).map((i: any) =>
      `<li>Product ${i.product_id} × ${i.quantity} — ₦${i.total_price}</li>`).join('')

    const html = `<!DOCTYPE html><html><body style="font-family:Arial,sans-serif;background:#0a0a0a;color:#eaeaea;padding:24px;max-width:600px;margin:0 auto;">
      <h1 style="color:#ff6b1a;font-size:20px;">New Order — ${order.reference}</h1>
      <p>Status: <strong>${order.status}</strong></p>
      <p>Delivery to: ${order.delivery_state ?? 'unspecified'} (est. ${order.delivery_days ?? '?'} days)</p>
      <ul>${itemsHtml}</ul>
      <p>Subtotal: ₦${order.subtotal} · Delivery: ₦${order.delivery_fee} · <strong>Total: ₦${order.total}</strong></p>
      <p style="color:#888;font-size:12px;">Log in to the admin dashboard to package and approve this order.</p>
    </body></html>`

    let sent = 0
    for (const m of managers) {
      const { data: userRes } = await supabase.auth.admin.getUserById(m.user_id)
      const email = userRes?.user?.email
      if (!email) continue
      const res = await fetch(RESEND_ENDPOINT, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${resendKey}` },
        body: JSON.stringify({ from: FROM_ADDRESS, to: [email], subject: `New order ${order.reference}`, html }),
      })
      if (res.ok) sent++
    }

    return new Response(JSON.stringify({ success: true, notified: sent }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })

  } catch (error) {
    console.error('notify-order-received error:', error)
    return new Response(JSON.stringify({ success: false, error: (error as Error).message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
  }
})
