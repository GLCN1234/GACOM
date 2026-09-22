// Blog drafter — Groq for real current gaming news via browser_search,
// plus a real cover image from Unsplash (free, CC0-licensed, hotlinking
// required by their own guidelines — not a workaround, this is how
// they want it used). Triggered daily by pg_cron. Publishes directly.
//
// Requires GROQ_API_KEY and UNSPLASH_ACCESS_KEY (unsplash.com/developers
// — free "Demo" tier, 50 requests/hour, far more than one post/day needs).
import { createClient } from 'jsr:@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const GROQ_ENDPOINT = 'https://api.groq.com/openai/v1/chat/completions'
const GROQ_MODEL = 'openai/gpt-oss-20b'
const UNSPLASH_SEARCH_ENDPOINT = 'https://api.unsplash.com/search/photos'

const CATEGORIES = ['News', 'Esports', 'Reviews', 'Tips', 'Tournaments', 'Community']

const SYSTEM_PROMPT = `You are GACOM's in-house gaming journalist. GACOM
(gamicom.net) is a Nigerian gaming social platform combining a social
feed, esports competitions, an education-gaming arm, and a marketplace.
Use the browser_search tool to find ACTUAL current gaming news — real
stories from the last few days: game releases, esports results, industry
announcements, community moments. Do not write generic genre commentary —
write about something that genuinely happened, that you found via search.
Then, naturally, tie it to GACOM: how this news connects to what GACOM's
own community cares about, plays, or could engage with — a real
extension of that broader conversation, not a forced product plug. Return
ONLY valid JSON, no markdown fences, no commentary before or after it.`

function buildPrompt(): string {
  return `Search for real, current gaming news from the past few days, pick the most interesting story for a young Nigerian/African gaming audience, and draft a blog post about it. Return this exact JSON shape:
{
  "title": "a specific, current headline-style title, under 70 characters",
  "excerpt": "1-2 sentence summary of the real story",
  "content": "full post as clean HTML using ONLY <p> and <a> tags — NO headings, NO <h1>/<h2>/<h3> at all, just flowing narrative paragraphs like a real news article, 300-500 words: cover the real news accurately, then a natural closing paragraph tying it to GACOM's own community",
  "category": "one of: ${CATEGORIES.join(', ')}",
  "image_keywords": "2-4 words describing the visual subject of this story for a stock photo search, e.g. 'esports tournament arena' or 'mobile gaming controller'"
}`
}

async function callGroqWithSearch(apiKey: string, prompt: string): Promise<string> {
  const response = await fetch(GROQ_ENDPOINT, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${apiKey}` },
    body: JSON.stringify({
      model: GROQ_MODEL,
      messages: [
        { role: 'system', content: SYSTEM_PROMPT },
        { role: 'user', content: prompt },
      ],
      temperature: 0.7,
      max_completion_tokens: 2048,
      top_p: 1,
      stream: false,
      tool_choice: 'required',
      tools: [{ type: 'browser_search' }],
    }),
  })
  if (!response.ok) throw new Error(`Groq API error (${response.status}): ${await response.text()}`)
  const data = await response.json()
  const text = data?.choices?.[0]?.message?.content
  if (!text) throw new Error(`Groq returned no content: ${JSON.stringify(data).slice(0, 1500)}`)
  return text.trim()
}

// Returns the image URL plus an attribution line — Unsplash's own
// guidelines require crediting the photographer with a link back to
// their profile, and a "download" ping when a photo is actually used
// (which this is: chosen to illustrate a published post). Returns null
// on any failure so a bad image search never blocks the actual post.
async function fetchUnsplashImage(accessKey: string, keywords: string): Promise<{ url: string; attributionHtml: string } | null> {
  try {
    const searchUrl = `${UNSPLASH_SEARCH_ENDPOINT}?query=${encodeURIComponent(keywords)}&per_page=1&orientation=landscape`
    const res = await fetch(searchUrl, { headers: { 'Authorization': `Client-ID ${accessKey}` } })
    if (!res.ok) return null
    const data = await res.json()
    const photo = data?.results?.[0]
    if (!photo) return null

    // Required by Unsplash's API guidelines whenever a photo is actually
    // used (not just displayed in search results) — best-effort, doesn't
    // block the post if it fails.
    if (photo.links?.download_location) {
      fetch(photo.links.download_location, { headers: { 'Authorization': `Client-ID ${accessKey}` } }).catch(() => {})
    }

    const photographerName = photo.user?.name ?? 'Unsplash'
    const photographerLink = photo.user?.links?.html ?? 'https://unsplash.com'
    const attributionHtml = `<p style="font-size:12px;color:#888;">Photo by <a href="${photographerLink}?utm_source=gacom&utm_medium=referral">${photographerName}</a> on <a href="https://unsplash.com/?utm_source=gacom&utm_medium=referral">Unsplash</a></p>`

    return { url: photo.urls?.regular ?? photo.urls?.small, attributionHtml }
  } catch {
    return null
  }
}

function parseJson(raw: string): any {
  const match = raw.match(/\{[\s\S]*\}/)
  const cleaned = (match ? match[0] : raw).replace(/^```json\s*/i, '').replace(/```$/, '').trim()
  return JSON.parse(sanitizeJsonControlChars(cleaned))
}

function sanitizeJsonControlChars(text: string): string {
  let result = ''
  let inString = false
  let escaped = false
  for (const char of text) {
    if (inString) {
      if (escaped) {
        result += char
        escaped = false
      } else if (char === '\\') {
        result += char
        escaped = true
      } else if (char === '"') {
        result += char
        inString = false
      } else if (char === '\n') {
        result += '\\n'
      } else if (char === '\r') {
        result += '\\r'
      } else if (char === '\t') {
        result += '\\t'
      } else {
        result += char
      }
    } else {
      result += char
      if (char === '"') inString = true
    }
  }
  return result
}

function slugify(title: string): string {
  return title.trim().toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '')
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  )

  try {
    const groqKey = Deno.env.get('GROQ_API_KEY')
    if (!groqKey) throw new Error('GROQ_API_KEY not configured')

    const raw = await callGroqWithSearch(groqKey, buildPrompt())
    const draft = parseJson(raw)
    if (!draft.title || !draft.content) throw new Error('Groq response missing required fields')

    const category = CATEGORIES.includes(draft.category) ? draft.category : 'News'
    const slug = `${slugify(draft.title)}-${Date.now().toString(36)}`

    let coverImageUrl: string | null = null
    let content = draft.content.trim()
    const unsplashKey = Deno.env.get('UNSPLASH_ACCESS_KEY')
    if (unsplashKey && draft.image_keywords) {
      const image = await fetchUnsplashImage(unsplashKey, String(draft.image_keywords))
      if (image) {
        coverImageUrl = image.url
        content = `${content}\n${image.attributionHtml}`
      }
    }

    const { data, error } = await supabase.from('blog_posts').insert({
      title: draft.title.trim(),
      slug,
      excerpt: draft.excerpt?.trim() || null,
      content,
      category,
      cover_image_url: coverImageUrl,
      author_id: null,
      is_ai_generated: true,
      is_published: true,
      published_at: new Date().toISOString(),
    }).select().single()
    if (error) throw error

    return new Response(JSON.stringify({ success: true, post: data }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })

  } catch (error) {
    console.error('generate-weekly-blog-post error:', error)
    return new Response(JSON.stringify({ success: false, error: (error as Error).message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
  }
})
