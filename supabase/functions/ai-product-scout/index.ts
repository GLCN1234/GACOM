// AI product scout — Groq's browser_search for real current products,
// autonomous (real search grounding means low hallucination risk, so
// no review queue). Each product now gets a real image via Unsplash
// (same integration already used for blog covers and game icons —
// this was simply never wired here before, a real gap, not a flaky
// bug). Also raised from 6 to 12 products per run since 1-6 wasn't
// enough for a real storefront.
//
// Requires GROQ_API_KEY and UNSPLASH_ACCESS_KEY (same secrets already
// set up for the blog and icon-seeder functions).
import { createClient } from 'jsr:@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const GROQ_ENDPOINT = 'https://api.groq.com/openai/v1/chat/completions'
const GROQ_MODEL = 'openai/gpt-oss-20b'
const UNSPLASH_SEARCH_ENDPOINT = 'https://api.unsplash.com/search/photos'
const MARKUP_MULTIPLIER = 1.10 // 10% added profit (was 20% earlier this session — using the figure most recently stated)
const MAX_PRODUCTS_PER_RUN = 5 // reduced further — cross-checking each price across multiple sources for 8 products in one low-effort pass may be why it gave up entirely last run
const DELIVERY_ESTIMATE_TEXT = '1-4 weeks within Nigeria (may arrive within 7 days, but won\'t pass 4 weeks)'

const SYSTEM_PROMPT = `You are a product scout for GACOM, a Nigerian gaming
social platform with a marketplace selling gaming-related physical
products (peripherals, merch, collectibles, accessories) to an African
gaming audience. Use the browser_search tool to find REAL, currently-sold
products with REAL source URLs — never invent a product, price, or link.

Search Nigerian e-commerce platforms specifically — Jumia, Konga, and
Slot Nigeria are the primary, trusted sources, since they list real
current prices already in Naira (avoiding currency-conversion errors
entirely, which is the single biggest source of price mistakes). Jumia
first, as the largest and most reliable. A confirmed price from one of
these platforms alone is reliable enough to use — you don't need a
second matching source for every product, but if you happen to check a
second one and the prices genuinely disagree, prefer the Jumia/Konga
listing over a foreign or unofficial one, and mark it low confidence
rather than guessing which is right.

Aim to propose a genuinely broad batch — around ${MAX_PRODUCTS_PER_RUN}
distinct products across different categories (peripherals, merch,
collectibles, accessories) rather than just one or two. It's fine to
propose fewer if that's genuinely all you can verify — never invent
products just to hit the target. Return ONLY valid JSON, no markdown
fences, no commentary.`

function buildPrompt(): string {
  return `Search Jumia, Konga, and Slot Nigeria for a genuinely broad batch of real gaming products worth adding to the marketplace right now — aim for around ${MAX_PRODUCTS_PER_RUN}, spread across different categories. Return this exact JSON shape:
{
  "products": [
    {
      "name": "product name",
      "description": "2-3 sentence description",
      "category": "one short category word e.g. Peripherals, Merch, Collectibles, Accessories",
      "image_keywords": "2-4 words for a stock photo search matching this exact product, e.g. 'wireless gaming mouse' or 'gaming headset black'",
      "source_price_ngn": 12345,
      "price_confidence": "high if multiple sources agreed closely, low if sources varied or you only found one",
      "source_url": "the real URL where you found this",
      "reasoning": "one sentence on why this suits GACOM's audience"
    }
  ]
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
      temperature: 0.6,
      max_completion_tokens: 8192,
      reasoning_effort: 'low',
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

// Same Unsplash pattern already used for blog covers and game icons —
// free, properly licensed, hotlinking is how they want it used.
// Returns null on any failure so a bad image search never blocks the
// product itself from being listed (it just shows a fallback icon).
async function fetchProductImage(accessKey: string, keywords: string): Promise<string | null> {
  try {
    const url = `${UNSPLASH_SEARCH_ENDPOINT}?query=${encodeURIComponent(keywords)}&per_page=1&orientation=squarish`
    const res = await fetch(url, { headers: { 'Authorization': `Client-ID ${accessKey}` } })
    if (!res.ok) return null
    const data = await res.json()
    const photo = data?.results?.[0]
    if (!photo) return null
    if (photo.links?.download_location) {
      fetch(photo.links.download_location, { headers: { 'Authorization': `Client-ID ${accessKey}` } }).catch(() => {})
    }
    return photo.urls?.small ?? photo.urls?.regular ?? null
  } catch {
    return null
  }
}

function parseJson(raw: string): any {
  const match = raw.match(/\{[\s\S]*\}/)
  if (!match) {
    // The model didn't return anything resembling JSON at all — most
    // likely it declined/apologized instead of completing the task.
    // Surface its actual words instead of a confusing parse error.
    throw new Error(`AI did not return JSON — its actual response was: "${raw.slice(0, 300)}"`)
  }
  const cleaned = match[0].replace(/^```json\s*/i, '').replace(/```$/, '').trim()
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

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  )

  try {
    const groqKey = Deno.env.get('GROQ_API_KEY')
    if (!groqKey) throw new Error('GROQ_API_KEY not configured')
    const unsplashKey = Deno.env.get('UNSPLASH_ACCESS_KEY')

    const raw = await callGroqWithSearch(groqKey, buildPrompt())
    const parsed = parseJson(raw)
    const candidates: any[] = Array.isArray(parsed.products) ? parsed.products : []

    if (candidates.length === 0) {
      return new Response(JSON.stringify({ success: true, note: 'Nothing worth proposing this run.', added: 0 }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }

    const filtered = candidates.slice(0, MAX_PRODUCTS_PER_RUN)
      .filter(c => c.name && c.source_price_ngn && c.source_url)

    const rows = []
    for (const c of filtered) {
      const sourcePrice = Number(c.source_price_ngn)
      let imageUrl: string | null = null
      if (unsplashKey && c.image_keywords) {
        imageUrl = await fetchProductImage(unsplashKey, String(c.image_keywords))
        // Small pause between Unsplash calls — well within their 50/hr
        // free-tier limit even at MAX_PRODUCTS_PER_RUN, just a safety margin.
        await new Promise((r) => setTimeout(r, 250))
      }
      rows.push({
        name: String(c.name).slice(0, 200),
        description: String(c.description ?? '').slice(0, 1000),
        category: String(c.category ?? 'Accessories').slice(0, 50),
        price: Math.round(sourcePrice * MARKUP_MULTIPLIER),
        source_price: sourcePrice,
        source_url: String(c.source_url).slice(0, 500),
        price_confidence: String(c.price_confidence ?? 'unknown').toLowerCase().includes('low') ? 'low' : 'high',
        is_ai_sourced: true,
        review_status: 'approved',
        is_active: true,
        stock: 5,
        images: imageUrl ? [imageUrl] : [],
        seller_id: null,
        delivery_estimate: DELIVERY_ESTIMATE_TEXT,
      })
    }

    if (rows.length === 0) {
      return new Response(JSON.stringify({ success: true, note: 'Proposals were missing required fields, none inserted.', added: 0 }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }

    const { error: insertError } = await supabase.from('products').insert(rows)
    if (insertError) throw insertError

    return new Response(JSON.stringify({ success: true, added: rows.length, withImages: rows.filter(r => r.images.length > 0).length }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })

  } catch (error) {
    console.error('ai-product-scout error:', error)
    return new Response(JSON.stringify({ success: false, error: (error as Error).message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
  }
})
