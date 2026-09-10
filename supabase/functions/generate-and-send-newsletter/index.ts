// Weekly newsletter. Triggered by pg_cron every Friday.
// Drafts a short newsletter via Gemini, logs it to newsletter_issues,
// then sends it to every subscribed user's email via Resend.
//
// Requires two secrets on this function: GEMINI_API_KEY (likely already
// set) and RESEND_API_KEY (new — from resend.com dashboard).
import { createClient } from 'jsr:@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const GEMINI_MODEL = 'gemini-flash-lite-latest'
const GEMINI_ENDPOINT = `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent`
const RESEND_ENDPOINT = 'https://api.resend.com/emails'

// Update this once you've verified a sending domain in Resend.
const FROM_ADDRESS = 'GACOM <newsletter@gamicom.net>'
const RESEND_BATCH_SIZE = 100 // Resend batch endpoint accepts up to 100 per call

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

function wrapEmail(subject: string, bodyHtml: string): string {
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

  let issueId: string | null = null

  try {
    const geminiKey = Deno.env.get('GEMINI_API_KEY')
    const resendKey = Deno.env.get('RESEND_API_KEY')
    if (!geminiKey) throw new Error('GEMINI_API_KEY not configured')
    if (!resendKey) throw new Error('RESEND_API_KEY not configured')

    // 1. Draft the newsletter content
    const raw = await callGemini(geminiKey, buildPrompt())
    const draft = parseJson(raw)
    if (!draft.subject || !draft.html_content) throw new Error('Gemini response missing required fields')

    const fullHtml = wrapEmail(draft.subject, draft.html_content)

    // 2. Log the issue as 'sending' before we start (avoids losing content if send fails partway)
    const { data: issue, error: issueError } = await supabase.from('newsletter_issues').insert({
      subject: draft.subject, html_content: fullHtml, status: 'sending',
    }).select().single()
    if (issueError) throw issueError
    issueId = issue.id

    // 3. Get all subscribed users' emails (profiles.newsletter_subscribed join auth.users)
    const { data: subscribers, error: subError } = await supabase
      .from('profiles').select('id').eq('newsletter_subscribed', true)
    if (subError) throw subError

    const emails: string[] = []
    for (const sub of subscribers ?? []) {
      const { data: userRes } = await supabase.auth.admin.getUserById(sub.id)
      if (userRes?.user?.email) emails.push(userRes.user.email)
    }

    if (emails.length === 0) {
      await supabase.from('newsletter_issues').update({
        status: 'sent', recipient_count: 0, sent_at: new Date().toISOString(),
        error_message: 'No subscribed users with an email were found.',
      }).eq('id', issueId)
      return new Response(JSON.stringify({ success: true, recipient_count: 0, note: 'no subscribers' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }

    // 4. Send in batches of 100 (Resend batch API limit)
    let sentCount = 0
    const failures: string[] = []
    for (let i = 0; i < emails.length; i += RESEND_BATCH_SIZE) {
      const chunk = emails.slice(i, i + RESEND_BATCH_SIZE)
      const result = await sendResendBatch(resendKey, chunk, draft.subject, fullHtml)
      if (result.ok) sentCount += chunk.length
      else failures.push(result.error ?? 'unknown batch error')
    }

    await supabase.from('newsletter_issues').update({
      status: failures.length > 0 && sentCount === 0 ? 'failed' : 'sent',
      recipient_count: sentCount,
      sent_at: new Date().toISOString(),
      error_message: failures.length > 0 ? `${failures.length} batch(es) failed: ${failures.join('; ')}` : null,
    }).eq('id', issueId)

    return new Response(JSON.stringify({ success: true, recipient_count: sentCount, failed_batches: failures.length }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })

  } catch (error) {
    console.error('generate-and-send-newsletter error:', error)
    if (issueId) {
      await supabase.from('newsletter_issues').update({
        status: 'failed', error_message: (error as Error).message,
      }).eq('id', issueId)
    }
    return new Response(JSON.stringify({ success: false, error: (error as Error).message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
  }
})
