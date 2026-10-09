// support-assistant: Ryan, GACOM's support assistant.
//
// Actions (POST JSON, signed-in users only):
//   { action: 'start',   message, categoryHint?, deviceInfo? }      -> creates a ticket and runs the assistant
//   { action: 'message', ticketId, message, attachments? }          -> adds a user message; the assistant answers
//                                                                       only while no person is involved
// Response: { success, ticket_id, user_message, messages: [assistant messages], mode }
//
// Secrets stay here: GEMINI_API_KEY (and the Supabase service key) are read from the environment.
// The model never triggers privileged actions. It only returns data that is validated, and the
// database re-checks the rules (money, account, security and safety tickets are never auto resolved).
//
// Env: GEMINI_API_KEY (required), GEMINI_MODEL (optional, default gemini-3.5-flash-lite),
//      ALLOWED_ORIGINS (optional, default https://gamicom.net), SUPABASE_URL, SUPABASE_ANON_KEY,
//      SUPABASE_SERVICE_ROLE_KEY (provided by Supabase).
import {
  HttpError, asUuid, fetchWithTimeout, redact, requireUser, secureServe, serviceClient, UNTRUSTED_NOTICE,
} from '../_shared/security.ts'
import {
  buildSystemPrompt, buildUserPrompt, cleanDeviceInfo, clean, decide, fallbackClassification, looksLikeInjection,
  responseSchema, scrubSecrets, validateModelOutput, wantsHuman,
  type CategoryInfo, type Decision, type KbHit,
} from './logic.ts'

const MAX_MESSAGE = 2000
const MODEL = Deno.env.get('GEMINI_MODEL') || 'gemini-3.5-flash-lite'

// deno-lint-ignore no-explicit-any
type Db = any

/** Maps database errors from the support functions to messages that are safe to show. */
function dbError(error: { message?: string; code?: string } | null | undefined): HttpError {
  const m = String(error?.message ?? '')
  if (/rate limited/i.test(m) || error?.code === '54000') {
    return new HttpError(429, 'You are sending messages too quickly. Please wait a minute and try again.', { 'Retry-After': '60' })
  }
  if (/ticket not found/i.test(m)) return new HttpError(404, 'We could not find that conversation.')
  if (/closed/i.test(m)) return new HttpError(409, 'This conversation is closed. Please start a new one.')
  if (/empty/i.test(m)) return new HttpError(400, 'Please type a message.')
  console.error('[support-assistant] db error:', redact(m).slice(0, 300))
  return new HttpError(500, 'Something went wrong. Please try again.')
}

async function loadCategories(svc: Db): Promise<CategoryInfo[]> {
  const { data, error } = await svc.from('support_categories')
    .select('key,label,team_key,default_priority,auto_resolve_allowed').eq('active', true)
  if (error || !Array.isArray(data) || data.length === 0) {
    return [{ key: 'other', label: 'Something else', team_key: 'care', default_priority: 'normal', auto_resolve_allowed: false }]
  }
  return data as CategoryInfo[]
}

async function callGemini(system: string, user: string, categoryKeys: string[]): Promise<unknown | null> {
  const apiKey = Deno.env.get('GEMINI_API_KEY')
  if (!apiKey) {
    console.error('[support-assistant] GEMINI_API_KEY is not set')
    return null
  }
  try {
    const res = await fetchWithTimeout(
      `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(MODEL)}:generateContent`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'x-goog-api-key': apiKey },
        body: JSON.stringify({
          systemInstruction: { parts: [{ text: `${system}\n\n${UNTRUSTED_NOTICE}` }] },
          contents: [{ role: 'user', parts: [{ text: user }] }],
          generationConfig: {
            temperature: 0.2,
            maxOutputTokens: 700,
            responseMimeType: 'application/json',
            responseSchema: responseSchema(categoryKeys),
          },
        }),
      },
      15_000,
    )
    if (!res.ok) {
      console.error('[support-assistant] gemini status', res.status)
      return null
    }
    const data = await res.json()
    return data?.candidates?.[0]?.content?.parts?.[0]?.text ?? null
  } catch (e) {
    console.error('[support-assistant] gemini failed:', redact(String((e as Error)?.message ?? e)).slice(0, 200))
    return null
  }
}

interface RunInput {
  svc: Db
  userId: string
  ticketId: string
  text: string
  isNew: boolean
  hint: string | null
  device: Record<string, unknown>
  canAnswerFollowUp?: boolean
}

/** Classifies, answers or routes, and writes the assistant message. Never throws to the caller. */
async function runAssistant(i: RunInput): Promise<{ messages: unknown[]; mode: string }> {
  const { svc } = i
  const categories = await loadCategories(svc)
  const asked = wantsHuman(i.text)
  const injected = looksLikeInjection(i.text)

  let decision: Decision
  let kbIds: string[] = []
  try {
    const kbRes = await svc.rpc('support_svc_kb_search', { p_query: i.text, p_category: i.hint, p_limit: 3 })
    const kb: KbHit[] = Array.isArray(kbRes.data) ? kbRes.data.slice(0, 3) : []
    let history: { sender_type: string; body: string }[] = []
    if (!i.isNew) {
      const h = await svc.rpc('support_svc_conversation', { p_user: i.userId, p_ticket: i.ticketId, p_limit: 8 })
      history = Array.isArray(h.data) ? h.data : []
    }
    const raw = await callGemini(
      buildSystemPrompt(categories),
      buildUserPrompt({ text: i.text, history, hint: i.hint, kb }),
      categories.map((c) => c.key),
    )
    const model = raw == null ? null : validateModelOutput(raw, categories, kb.map((k) => k.id))
    decision = decide({ model, categories, text: i.text, userAskedHuman: asked, canAnswerFollowUp: i.canAnswerFollowUp })
    kbIds = model?.kb_ids ?? []
  } catch (e) {
    console.error('[support-assistant] run failed:', redact(String((e as Error)?.message ?? e)).slice(0, 200))
    decision = decide({ model: null, categories, text: i.text, userAskedHuman: asked })
  }

  // Diagnostics for technical problems: app version, platform and the last 5 recorded errors.
  let diag: Record<string, unknown> | null = null
  const cat = categories.find((c) => c.key === decision.cls.category)
  if (decision.mode !== 'answer' && (decision.technical || cat?.team_key === 'technical')) {
    const d = await svc.rpc('support_svc_diagnostics', { p_user: i.userId })
    diag = {
      app_version: String(i.device['app_version'] ?? 'unknown'),
      platform: String(i.device['platform'] ?? 'unknown'),
      recent_errors: Array.isArray(d.data?.recent_errors) ? d.data.recent_errors : [],
    }
  }

  // New tickets are classified. Follow-ups keep their routing unless the model raised a safety flag.
  const sendClass = i.isNew || decision.cls.safety_flag
  const meta = {
    kb_ids: kbIds,
    model: MODEL,
    injection_suspected: injected || undefined,
    human_requested: decision.human_requested ? 'true' : undefined,
  }
  const apply = async (cls: unknown, d: Decision, dg: unknown) =>
    await svc.rpc('support_svc_apply', {
      p_ticket: i.ticketId,
      p_class: cls,
      p_reply: d.reply,
      p_meta: meta,
      p_mode: d.mode,
      p_diag: dg,
    })

  let res = await apply(sendClass ? decision.cls : null, decision, diag)
  if (res.error) {
    // Last resort: still acknowledge and route, so the user is never left without a reply.
    console.error('[support-assistant] apply failed:', redact(String(res.error.message ?? '')).slice(0, 200))
    const safe: Decision = { mode: 'route', cls: fallbackClassification(i.text), reply: '', human_requested: false, technical: false }
    res = await apply(i.isNew ? safe.cls : null, safe, null)
    if (res.error) throw dbError(res.error)
  }
  return { messages: res.data?.messages ?? [], mode: String(res.data?.mode ?? decision.mode) }
}

secureServe('support-assistant', async (req, ctx) => {
  const { user } = await requireUser(req)
  const body = await ctx.readJson()
  const svc = serviceClient()
  const action = String(body.action ?? '')

  if (action === 'start') {
    const text = scrubSecrets(clean(body.message, MAX_MESSAGE))
    if (!text) throw new HttpError(400, 'Please type a message.')
    const hint = typeof body.categoryHint === 'string' && /^[a-z_]{2,40}$/.test(body.categoryHint) ? body.categoryHint : null
    const device = cleanDeviceInfo(body.deviceInfo)
    const opened = await svc.rpc('support_svc_open_ticket', { p_user: user.id, p_message: text, p_hint: hint, p_device: device })
    if (opened.error) throw dbError(opened.error)
    const ticketId = String(opened.data.ticket_id)
    let out: { messages: unknown[]; mode: string } = { messages: [], mode: 'route' }
    try {
      out = await runAssistant({ svc, userId: user.id, ticketId, text, isNew: true, hint, device })
    } catch (e) {
      if (e instanceof HttpError && e.status !== 500) throw e
      console.error('[support-assistant] start: assistant step failed, ticket kept')
    }
    return ctx.json({ success: true, ticket_id: ticketId, user_message: opened.data.message, messages: out.messages, mode: out.mode })
  }

  if (action === 'message') {
    const ticketId = asUuid(body.ticketId, 'ticketId')
    const text = scrubSecrets(clean(body.message, MAX_MESSAGE))
    const attachments = Array.isArray(body.attachments)
      ? body.attachments.filter((a: unknown) => typeof a === 'string' && a.length <= 300).slice(0, 5)
      : []
    if (!text && attachments.length === 0) throw new HttpError(400, 'Please type a message.')
    const posted = await svc.rpc('support_svc_post_user_message', {
      p_user: user.id, p_ticket: ticketId, p_body: text, p_attachments: attachments,
    })
    if (posted.error) throw dbError(posted.error)
    const p = posted.data
    // A person is already on it, or the ticket sits in a team queue: the assistant stays quiet.
    if (p.human_involved || p.routed || !text) {
      return ctx.json({ success: true, ticket_id: ticketId, user_message: p.message, messages: [], mode: 'human' })
    }
    const info = await svc.rpc('support_svc_ticket_info', { p_user: user.id, p_ticket: ticketId })
    const device = (info.data?.device_info ?? {}) as Record<string, unknown>
    let out: { messages: unknown[]; mode: string } = { messages: [], mode: 'route' }
    try {
      out = await runAssistant({
        svc, userId: user.id, ticketId, text, isNew: false, hint: String(p.category ?? '') || null, device,
        canAnswerFollowUp: p.auto_resolve_allowed === true,
      })
    } catch (e) {
      if (e instanceof HttpError && e.status !== 500) throw e
      console.error('[support-assistant] message: assistant step failed, message kept')
    }
    return ctx.json({ success: true, ticket_id: ticketId, user_message: p.message, messages: out.messages, mode: out.mode })
  }

  throw new HttpError(400, 'Unknown action')
}, { methods: ['POST'], maxBodyBytes: 16 * 1024, ipRateLimit: { limit: 60, windowMs: 60_000 } })
