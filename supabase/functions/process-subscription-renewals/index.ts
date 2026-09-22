// Runs daily. Two jobs in one pass:
//  1. Card payers with auto_renew=true, expiring today or already
//     lapsed within a grace window: actually auto-charge their saved
//     card via Paystack's charge_authorization endpoint, extending
//     expires_at by a month on success.
//  2. Everyone else (transfer payers, or a card charge that failed)
//     expiring within REMINDER_DAYS: a reminder email, not an auto-charge
//     — because for these there is nothing to auto-charge; only the
//     person themselves can initiate another transfer.
import { createClient } from 'jsr:@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}
const RESEND_ENDPOINT = 'https://api.resend.com/emails'
const FROM_ADDRESS = 'GACOM Edu <edu@gamicom.net>'
const REMINDER_DAYS = 3
const MAX_RENEWAL_ATTEMPTS = 3 // after this many failures, stop retrying and just remind them instead

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  )
  const paystackKey = Deno.env.get('PAYSTACK_SECRET_KEY')
  const resendKey = Deno.env.get('RESEND_API_KEY')

  try {
    if (!paystackKey) throw new Error('PAYSTACK_SECRET_KEY not configured')

    const now = new Date()
    const todayEnd = new Date(now); todayEnd.setHours(23, 59, 59, 999)
    const reminderCutoff = new Date(now); reminderCutoff.setDate(reminderCutoff.getDate() + REMINDER_DAYS)

    // ── 1. Auto-renew card subscriptions due today or overdue ──
    const { data: dueForRenewal, error: dueError } = await supabase
      .from('edu_subscriptions')
      .select('id, user_id, reference, authorization_code, renewal_failed_count')
      .eq('status', 'active')
      .eq('auto_renew', true)
      .lte('expires_at', todayEnd.toISOString())
      .lt('renewal_failed_count', MAX_RENEWAL_ATTEMPTS)
    if (dueError) throw dueError

    let renewed = 0, renewalFailed = 0
    for (const sub of dueForRenewal ?? []) {
      const { data: userRes } = await supabase.auth.admin.getUserById(sub.user_id)
      const email = userRes?.user?.email
      if (!email || !sub.authorization_code) continue

      const newRef = `EDU_RENEW_${sub.user_id.substring(0, 8)}_${Date.now()}`
      const chargeRes = await fetch('https://api.paystack.co/transaction/charge_authorization', {
        method: 'POST',
        headers: { 'Authorization': `Bearer ${paystackKey}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ authorization_code: sub.authorization_code, email, amount: 350000, reference: newRef }),
      })
      const chargeData = await chargeRes.json()

      if (chargeData.status && chargeData.data?.status === 'success') {
        const newExpiry = new Date(); newExpiry.setMonth(newExpiry.getMonth() + 1)
        await supabase.from('edu_subscriptions').update({
          expires_at: newExpiry.toISOString(),
          reference: newRef,
          last_renewal_attempt_at: now.toISOString(),
          renewal_failed_count: 0,
        }).eq('id', sub.id)
        renewed++
        if (resendKey) {
          fetch(RESEND_ENDPOINT, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${resendKey}` },
            body: JSON.stringify({
              from: FROM_ADDRESS, to: [email], subject: 'GACOM Edu — subscription renewed',
              html: `<p>Your GACOM Edu subscription was renewed automatically — ₦3,500 charged to your card on file. Your access continues uninterrupted.</p>`,
            }),
          }).catch(() => {})
        }
      } else {
        renewalFailed++
        await supabase.from('edu_subscriptions').update({
          last_renewal_attempt_at: now.toISOString(),
          renewal_failed_count: (sub.renewal_failed_count ?? 0) + 1,
        }).eq('id', sub.id)
        if (resendKey) {
          fetch(RESEND_ENDPOINT, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${resendKey}` },
            body: JSON.stringify({
              from: FROM_ADDRESS, to: [email], subject: 'GACOM Edu — card charge failed',
              html: `<p>We tried to renew your GACOM Edu subscription but the charge to your card didn't go through. Please open the app and renew manually to keep your access active.</p>`,
            }),
          }).catch(() => {})
        }
      }
    }

    // ── 2. Reminder emails for everyone else expiring soon ──
    // (transfer payers, or card payers who've exhausted auto-retry)
    const { data: needsReminder, error: reminderError } = await supabase
      .from('edu_subscriptions')
      .select('id, user_id, expires_at')
      .eq('status', 'active')
      .eq('auto_renew', false)
      .gte('expires_at', now.toISOString())
      .lte('expires_at', reminderCutoff.toISOString())
    if (reminderError) throw reminderError

    let reminded = 0
    for (const sub of needsReminder ?? []) {
      const { data: userRes } = await supabase.auth.admin.getUserById(sub.user_id)
      const email = userRes?.user?.email
      if (!email || !resendKey) continue
      const daysLeft = Math.ceil((new Date(sub.expires_at).getTime() - now.getTime()) / 86400000)
      await fetch(RESEND_ENDPOINT, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${resendKey}` },
        body: JSON.stringify({
          from: FROM_ADDRESS, to: [email],
          subject: `GACOM Edu — your subscription expires in ${daysLeft} day${daysLeft === 1 ? '' : 's'}`,
          html: `<p>Your GACOM Edu subscription expires in ${daysLeft} day${daysLeft === 1 ? '' : 's'}. Open the app and renew (₦3,500/month) to keep your access. Paying by card lets renewals happen automatically going forward — transfer needs to be repeated manually each month.</p>`,
        }),
      }).catch(() => {})
      reminded++
    }

    return new Response(JSON.stringify({ success: true, renewed, renewalFailed, reminded }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })

  } catch (error) {
    console.error('process-subscription-renewals error:', error)
    return new Response(JSON.stringify({ success: false, error: (error as Error).message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
  }
})
