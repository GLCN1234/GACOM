// Ryan writes the social missions for a season. Admin only.
// Ryan reads the brand accounts and the missions that already exist, writes new ones,
// and saves them as DRAFTS (is_active = false) so an admin reads them before players do.
//
// Needs GROQ_API_KEY (already set for the blog writer).
import { secureServe, requireAdmin, fetchWithTimeout, redact, HttpError } from '../_shared/security.ts'

const GROQ_ENDPOINT = 'https://api.groq.com/openai/v1/chat/completions'
const GROQ_MODEL = 'openai/gpt-oss-20b'
const TYPES = ['social_link', 'clip', 'follow', 'code_word']
const PLATFORMS = ['x', 'instagram', 'tiktok', 'youtube', 'facebook', 'any']

const SYSTEM = `You are Ryan, the voice of GACOM (gamicom.net), a Nigerian gaming and student platform.
You write daily social missions for the GACOM Agon launch. Players are students and gamers who voluntarily
help spread the brand: following the pages, posting about GACOM, tagging it, and showing their gameplay.
Rules:
- Plain, warm, short. Nigerian youth tone, no slang that confuses, no emojis, no hashtags you were not given.
- Never use the word "AI". Never promise money. Never ask for passwords or private details.
- Each mission is one clear action a student can finish in under five minutes.
- Vary the actions across the days: follow, post, screen-record gameplay, share a result, make content, explain a game.
- A mission that asks for a post must say to tag the brand account and to include the player's personal mission code.
- Return ONLY valid JSON. No markdown fences, no commentary.`

interface Brand { platform: string; handle: string; url: string; hashtags: string | null }

function clean(s: unknown, max: number): string {
  return String(s ?? '').replace(/<[^>]*>/g, '').replace(/\s+/g, ' ').trim().slice(0, max)
}

function buildPrompt(brands: Brand[], existing: string[], days: number, perDay: number, focus: string): string {
  const accounts = brands.map((b) => `- ${b.platform}: @${b.handle} (${b.url})${b.hashtags ? ` hashtags: ${b.hashtags}` : ''}`).join('\n')
  return `Brand accounts:\n${accounts || '(none set yet)'}\n
Missions that already exist (do not repeat them):\n${existing.length ? existing.map((t) => `- ${t}`).join('\n') : '(none)'}\n
Write ${perDay} mission(s) for each of ${days} day(s), numbered from day 1.${focus ? `\nExtra direction from the team: ${focus}` : ''}
Allowed types: social_link (a post link), clip (a gameplay screen recording link or upload), follow (follow a brand account), code_word (a word hidden in a GACOM page or video; include "answer").
A "platform" must be one of: ${PLATFORMS.join(', ')}, and must be a platform that has a brand account above unless it is "any".
Return this exact JSON shape:
{"missions":[{"day":1,"title":"under 60 characters","description":"one sentence","instructions":"2 to 4 short sentences telling the player exactly what to do","type":"social_link","platform":"x","tag_text":"what to tag or include, e.g. the brand handle","answer":"only for code_word","points":10}]}
"points" is house points between 5 and 25: follows 5 to 8, posts 10 to 15, gameplay clips 15 to 25.`
}

secureServe('ryan-mission-writer', async (req, ctx) => {
  const { svc } = await requireAdmin(req)
  const body = await ctx.readJson()
  const days = Math.min(Math.max(parseInt(body.days) || 1, 1), 14)
  const perDay = Math.min(Math.max(parseInt(body.per_day) || 2, 1), 4)
  const focus = clean(body.focus, 300)

  const seasonId = String(body.season_id ?? '')
  if (!/^[0-9a-f-]{36}$/i.test(seasonId)) throw new HttpError(400, 'Pick a season first')
  const { data: season } = await svc.from('mission_seasons').select('id,total_days').eq('id', seasonId).maybeSingle()
  if (!season) throw new HttpError(404, 'Season not found')
  const startDay = Math.max(parseInt(body.start_day) || 1, 1)

  const apiKey = Deno.env.get('GROQ_API_KEY')
  if (!apiKey) throw new HttpError(500, 'The writing service is not set up')

  const { data: brandRows } = await svc.from('brand_socials').select('platform,handle,url,hashtags').order('sort_order')
  const brands = (brandRows ?? []) as Brand[]
  if (brands.length === 0) throw new HttpError(400, 'Add the GACOM accounts under Brand accounts first')
  const { data: ex } = await svc.from('missions').select('title').eq('season_id', seasonId).limit(80)
  const existing = (ex ?? []).map((r: { title: string }) => String(r.title))

  const res = await fetchWithTimeout(GROQ_ENDPOINT, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${apiKey}` },
    body: JSON.stringify({
      model: GROQ_MODEL,
      messages: [{ role: 'system', content: SYSTEM }, { role: 'user', content: buildPrompt(brands, existing, days, perDay, focus) }],
      temperature: 0.8,
      max_completion_tokens: 3500,
      reasoning_effort: 'low',
      response_format: { type: 'json_object' },
      stream: false,
    }),
  }, 45_000)
  if (!res.ok) {
    console.error('[ryan-mission-writer] groq', res.status, redact((await res.text()).slice(0, 300)))
    throw new HttpError(502, 'Ryan could not write right now. Try again in a minute.')
  }
  const out = await res.json()
  let parsed: { missions?: unknown[] }
  try {
    const raw = String(out?.choices?.[0]?.message?.content ?? '').replace(/^```(?:json)?|```$/gm, '').trim()
    parsed = JSON.parse(raw)
  } catch {
    throw new HttpError(502, 'Ryan sent back something unreadable. Try again.')
  }

  const have = new Set(brands.map((b) => b.platform))
  const rows: Record<string, unknown>[] = []
  const secrets: Record<number, string> = {}
  for (const m of (parsed.missions ?? []) as Record<string, unknown>[]) {
    const type = String(m.type ?? '')
    const platform = String(m.platform ?? 'any')
    const title = clean(m.title, 80)
    const instructions = clean(m.instructions, 500)
    if (!TYPES.includes(type) || !PLATFORMS.includes(platform) || !title || !instructions) continue
    if (type === 'follow' && !have.has(platform)) continue
    if (platform !== 'any' && !have.has(platform)) continue
    if ((type === 'follow') && !['x', 'instagram', 'tiktok'].includes(platform)) continue
    if (type === 'code_word' && !clean(m.answer, 40)) continue
    const day = Math.min(Math.max(parseInt(String(m.day)) || 1, 1), days) + startDay - 1
    if (day > season.total_days) continue
    if (existing.some((t) => t.toLowerCase() === title.toLowerCase())) continue
    const points = Math.min(Math.max(parseInt(String(m.points)) || 10, 5), 25)
    if (type === 'code_word') secrets[rows.length] = clean(m.answer, 40)
    rows.push({
      season_id: seasonId, day_number: day, title,
      description: clean(m.description, 240) || null,
      instructions, type, platform: type === 'code_word' ? 'any' : platform,
      verify: 'auto_spotcheck', reward_house_points: points,
      tag_text: clean(m.tag_text, 120) || null,
      sort_order: 50, is_active: false, // drafts: an admin reviews and switches them on
    })
  }
  if (rows.length === 0) throw new HttpError(502, 'Ryan did not write anything usable. Try again.')

  const { data: saved, error } = await svc.from('missions').insert(rows).select('id')
  if (error) {
    console.error('[ryan-mission-writer] insert', redact(String(error.message)))
    throw new HttpError(500, 'Could not save the missions')
  }
  const secretRows = Object.entries(secrets).map(([i, answer]) => ({ mission_id: saved![Number(i)].id, answer }))
  if (secretRows.length) await svc.from('mission_secrets').insert(secretRows)

  return ctx.json({ success: true, created: rows.length, note: 'Saved as drafts. Review them, then switch them on.' })
}, { maxBodyBytes: 4 * 1024 })
