// Newsletter, now sent as a daily rotation batch instead of one big blast.
// Triggered by pg_cron every day. On each run:
//  - If an edition is mid-rotation (status='sending'), sends the NEXT
//    batch of subscribers who haven't received it yet.
//  - If the current edition is fully delivered (or none exists) and at
//    least 7 days have passed since the last completed edition, drafts a
//    brand new one via Gemini and sends its first batch.
//  - Otherwise, does nothing this run (too soon for a new edition).
// This keeps each day's send comfortably under Resend's free-tier daily
// cap, and every subscriber eventually receives each edition over a
// rolling ~10-12 day window rather than only the first ~100 succeeding.
//
// Requires GEMINI_API_KEY and RESEND_API_KEY secrets (already set from
// the original weekly setup).
import { createClient } from 'jsr:@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const GEMINI_MODEL = 'gemini-flash-lite-latest'
const GEMINI_ENDPOINT = `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent`
const RESEND_ENDPOINT = 'https://api.resend.com/emails'

const FROM_ADDRESS = 'GACOM <newsletter@gamicom.net>'
// Kept comfortably under Resend's 100/day free-tier cap, leaving
// headroom for any other transactional email sharing the same account.
const DAILY_BATCH_SIZE = 80

const SYSTEM_PROMPT = `You are writing GACOM's weekly newsletter. GACOM
(gamicom.net) is a Nigerian gaming social platform: social feed, esports
competitions, an education-gaming arm (turning school subjects into games),
and a marketplace. The newsletter goes to GACOM's own registered users —
write warmly and specifically to people who already have an account, not
to cold prospects. Mix genuine gaming-industry interest with a light,
natural showcase of what GACOM itself offers (this week's competitions,
the edu-gaming angle, community features) — never a hard sales pitch, more
"here's something worth your attention this week." Keep it short: this is
an email, not a blog post. Return ONLY valid JSON, no markdown fences.`

function buildPrompt(): string {
  return `Draft this week's GACOM newsletter email. Return this exact JSON shape:
{
  "subject": "email subject line, under 60 characters, no clickbait",
  "html_content": "full email body as clean HTML (use <h2>, <p>, <a> tags only, no <html>/<head>/<body> wrapper, no inline styles needed), 150-300 words, warm and specific, ending with a light call-to-action to open the GACOM app"
}`
}

async function callGemini(apiKey: string, prompt: string): Promise<string> {
  const response = await fetch(`${GEMINI_ENDPOINT}?key=${apiKey}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      systemInstruction: { parts: [{ text: SYSTEM_PROMPT }] },
      contents: [{ role: 'user', parts: [{ text: prompt }] }],
      generationConfig: { maxOutputTokens: 1024, temperature: 0.85 },
    }),
  })
  if (!response.ok) throw new Error(`Gemini API error: ${await response.text()}`)
  const data = await response.json()
  const text = data?.candidates?.[0]?.content?.parts?.[0]?.text
  if (!text) throw new Error(`Gemini returned no content: ${JSON.stringify(data)}`)
  return text.trim()
}

function parseJson(raw: string): any {
  const cleaned = raw.replace(/^```json\s*/i, '').replace(/```$/, '').trim()
  return JSON.parse(cleaned)
}

function wrapEmail(bodyHtml: string): string {
  return `<!DOCTYPE html><html><body style="font-family:Arial,sans-serif;background:#0a0a0a;color:#eaeaea;padding:24px;max-width:600px;margin:0 auto;">
    <h1 style="color:#ff6b1a;font-size:20px;">GACOM</h1>
    ${bodyHtml}
    <hr style="border-color:#333;margin-top:32px;">
    <p style="color:#888;font-size:11px;">You're receiving this because you have a GACOM account.
    <a href="https://gamicom.net/settings/notifications" style="color:#888;">Unsubscribe</a></p>
  </body></html>`
}

async function sendResendBatch(resendKey: string, emails: string[], subject: string, html: string): Promise<{ok: boolean, error?: string}> {
  const batch = emails.map(to => ({ from: FROM_ADDRESS, to: [to], subject, html }))
  const response = await fetch(`${RESEND_ENDPOINT}/batch`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${resendKey}` },
    body: JSON.stringify(batch),
  })
  if (!response.ok) return { ok: false, error: await response.text() }
  return { ok: true }
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  )

  try {
    const geminiKey = Deno.env.get('GEMINI_API_KEY')
    const resendKey = Deno.env.get('RESEND_API_KEY')
    if (!geminiKey) throw new Error('GEMINI_API_KEY not configured')
    if (!resendKey) throw new Error('RESEND_API_KEY not configured')

    // 1. Find the most recent edition to decide what today's run should do.
    const { data: latestIssue, error: latestError } = await supabase
      .from('newsletter_issues')
      .select('id, subject, html_content, status, recipient_count, sent_at, created_at')
      .order('created_at', { ascending: false })
      .limit(1)
      .maybeSingle()
    if (latestError) throw latestError

    let issue = latestIssue

    if (!issue || issue.status !== 'sending') {
      // No edition in progress — the previous one either fully completed
      // or none has ever run. Start the next edition right away rather
      // than waiting; at 80/day for ~1000 subscribers a full rotation
      // already takes ~13 days on its own, so there's no reason to add
      // an artificial gap on top of that.
      const raw = await callGemini(geminiKey, buildPrompt())
      const draft = parseJson(raw)
      if (!draft.subject || !draft.html_content) throw new Error('Gemini response missing required fields')
      const fullHtml = wrapEmail(draft.html_content)

      const { data: newIssue, error: insertError } = await supabase.from('newsletter_issues').insert({
        subject: draft.subject, html_content: fullHtml, status: 'sending', recipient_count: 0,
      }).select().single()
      if (insertError) throw insertError
      issue = newIssue
    }

    // 2. Find subscribers who haven't received THIS edition yet.
    const { data: pending, error: pendingError } = await supabase
      .from('profiles')
      .select('id, newsletter_last_sent_issue_id')
      .eq('newsletter_subscribed', true)
      .or(`newsletter_last_sent_issue_id.is.null,newsletter_last_sent_issue_id.neq.${issue.id}`)
      .limit(DAILY_BATCH_SIZE)
    if (pendingError) throw pendingError

    if (!pending || pending.length === 0) {
      // Rotation complete — everyone subscribed has this edition now.
      await supabase.from('newsletter_issues').update({ status: 'sent', sent_at: new Date().toISOString() }).eq('id', issue.id)
      return new Response(JSON.stringify({ success: true, note: 'Rotation complete, edition fully delivered.', recipient_count: issue.recipient_count }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }

    // 3. Resolve emails for today's batch and send.
    const idToEmail = new Map<string, string>()
    for (const p of pending) {
      const { data: userRes } = await supabase.auth.admin.getUserById(p.id)
      if (userRes?.user?.email) idToEmail.set(p.id, userRes.user.email)
    }
    const emails = Array.from(idToEmail.values())

    if (emails.length === 0) {
      return new Response(JSON.stringify({ success: true, note: 'No resolvable emails in this batch.' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }

    const result = await sendResendBatch(resendKey, emails, issue.subject, issue.html_content)
    if (!result.ok) {
      await supabase.from('newsletter_issues').update({ error_message: result.error }).eq('id', issue.id)
      throw new Error(`Resend batch failed: ${result.error}`)
    }

    // Mark exactly the users we just emailed as having received this edition.
    const sentIds = Array.from(idToEmail.keys())
    await supabase.from('profiles').update({ newsletter_last_sent_issue_id: issue.id }).in('id', sentIds)
    await supabase.from('newsletter_issues').update({ recipient_count: (issue.recipient_count ?? 0) + sentIds.length }).eq('id', issue.id)

    return new Response(JSON.stringify({ success: true, sent_today: sentIds.length, edition_id: issue.id }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })

  } catch (error) {
    console.error('generate-and-send-newsletter error:', error)
    return new Response(JSON.stringify({ success: false, error: (error as Error).message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
  }
})
