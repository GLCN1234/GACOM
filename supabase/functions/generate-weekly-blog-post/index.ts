// Weekly AI blog drafter. Triggered by pg_cron every Wednesday.
// Picks a trending gaming-industry angle, drafts a full post via Gemini,
// and inserts it as an UNPUBLISHED draft for a human editor to review,
// tweak, and publish from the admin dashboard's Blog Posts section.
import { createClient } from 'jsr:@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const GEMINI_MODEL = 'gemini-flash-lite-latest'
const GEMINI_ENDPOINT = `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent`

const CATEGORIES = ['News', 'Esports', 'Reviews', 'Tips', 'Tournaments', 'Community']

const SYSTEM_PROMPT = `You are GACOM's in-house gaming journalist. GACOM (gamicom.net) is a
Nigerian gaming social platform combining social feed, esports competitions, an
education-gaming arm, and a marketplace. You write sharp, current, genuinely
interesting blog posts about the gaming industry for a young, mobile-first
Nigerian and African gaming audience. Never invent specific unverifiable facts,
statistics, or quotes — write about GENRES of trending topics (a type of game
mechanic, an industry pattern, a genre's evolution, community/esports culture,
tips and strategy) rather than claiming specific breaking news you cannot verify.
Return ONLY valid JSON, no markdown fences, no commentary.`

function buildPrompt(): string {
  return `Draft one blog post for GACOM's blog. Pick ONE angle from: a gaming genre
trend, an esports/competitive scene topic, a practical tips-and-strategy piece,
a community culture observation, or a reflection on mobile gaming growth in Africa.

Return this exact JSON shape:
{
  "title": "punchy, specific title, under 70 characters",
  "excerpt": "1-2 sentence hook/summary, under 160 characters",
  "content": "the full post, 500-800 words, in markdown with a few subheadings (##), written in an engaging, knowledgeable voice — no invented statistics or fake quotes",
  "category": "one of: ${CATEGORIES.join(', ')}",
  "tags": ["3 to 5 relevant lowercase tags"]
}`
}

async function callGemini(apiKey: string, prompt: string): Promise<string> {
  const response = await fetch(`${GEMINI_ENDPOINT}?key=${apiKey}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      systemInstruction: { parts: [{ text: SYSTEM_PROMPT }] },
      contents: [{ role: 'user', parts: [{ text: prompt }] }],
      generationConfig: { maxOutputTokens: 2048, temperature: 0.9 },
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

function slugify(title: string): string {
  return title.trim().toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '')
    + '-' + Date.now()
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const geminiKey = Deno.env.get('GEMINI_API_KEY')
    if (!geminiKey) throw new Error('GEMINI_API_KEY not configured')

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    )

    const raw = await callGemini(geminiKey, buildPrompt())
    const post = parseJson(raw)

    if (!post.title || !post.content) throw new Error('Gemini response missing required fields')

    const { data, error } = await supabase.from('blog_posts').insert({
      title: post.title,
      slug: slugify(post.title),
      excerpt: post.excerpt ?? null,
      content: post.content,
      category: CATEGORIES.includes(post.category) ? post.category : 'News',
      tags: Array.isArray(post.tags) ? post.tags : [],
      author_id: null,
      is_published: false,
      is_ai_generated: true,
      read_time_minutes: Math.max(2, Math.round((post.content as string).split(/\s+/).length / 200)),
    }).select().single()

    if (error) throw error

    return new Response(JSON.stringify({ success: true, post_id: data.id, title: data.title }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })

  } catch (error) {
    console.error('generate-weekly-blog-post error:', error)
    return new Response(JSON.stringify({ success: false, error: (error as Error).message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
  }
})
