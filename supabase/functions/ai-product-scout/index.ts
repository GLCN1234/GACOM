// AI product scout — now on Grok (xAI) instead of Gemini, specifically
// because the Gemini quota shared across this project's other AI
// features (blog, curriculum questions, newsletter) was exhausted.
// Uses xAI's Responses API with the web_search tool for real, grounded
// results (not the model's own unguided memory) — same anti-
// hallucination requirement as before, just a different provider.
//
// Requires a NEW secret: XAI_API_KEY (from console.x.ai — this is a
// separate key from GEMINI_API_KEY, on a separate quota).
import { createClient } from 'jsr:@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const XAI_ENDPOINT = 'https://api.x.ai/v1/responses'
const XAI_MODEL = 'grok-4.6'
const MARKUP_MULTIPLIER = 1.20 // 20% added profit
const MAX_PRODUCTS_PER_RUN = 6
const DELIVERY_ESTIMATE_TEXT = '4-6 weeks (may arrive sooner, but not later)'

const SYSTEM_PROMPT = `You are a product scout for GACOM, a Nigerian gaming
social platform with a marketplace selling gaming-related physical
products (peripherals, merch, collectibles, accessories) to an African
gaming audience. Use real-time web search to find REAL, currently-sold
products with REAL source URLs and REAL current prices — never invent a
product, price, or link. Use your own judgment: only propose products you
genuinely believe would sell well to this specific audience, not just
anything you find. Return between 1 and ${MAX_PRODUCTS_PER_RUN} products.
Prices you find should be converted to Nigerian Naira (NGN) if not already
in NGN, using a reasonable current exchange rate. Return ONLY valid JSON,
no markdown fences, no commentary — nothing before or after the JSON
object.`

function buildPrompt(): string {
  return `Find real gaming products worth adding to the marketplace right now. Return this exact JSON shape:
{
  "products": [
    {
      "name": "product name",
      "description": "2-3 sentence description",
      "category": "one short category word e.g. Peripherals, Merch, Collectibles, Accessories",
      "source_price_ngn": 12345,
      "source_url": "the real URL where you found this",
      "reasoning": "one sentence on why this suits GACOM's audience"
    }
  ]
}`
}

async function callGrokGrounded(apiKey: string, prompt: string): Promise<string> {
  const response = await fetch(XAI_ENDPOINT, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${apiKey}` },
    body: JSON.stringify({
      model: XAI_MODEL,
      input: [{ role: 'user', content: `${SYSTEM_PROMPT}\n\n${prompt}` }],
      tools: [{ type: 'web_search' }],
    }),
  })
  if (!response.ok) throw new Error(`xAI API error (${response.status}): ${await response.text()}`)
  const data = await response.json()

  // Responses-API shape: data.output is an array of items; the text lives
  // in the message-type item's content array. Walking it defensively and
  // surfacing the raw payload on failure, since this exact shape hasn't
  // been verified against a real response from this project yet.
  const messageItem = (data.output ?? []).find((item: any) => item.type === 'message')
  const text = messageItem?.content?.find((c: any) => c.type === 'output_text')?.text
    ?? messageItem?.content?.[0]?.text
  if (!text) throw new Error(`Could not find text in xAI response. Raw payload: ${JSON.stringify(data).slice(0, 2000)}`)
  return text.trim()
}

function parseJson(raw: string): any {
  const match = raw.match(/\{[\s\S]*\}/)
  const cleaned = (match ? match[0] : raw).replace(/^```json\s*/i, '').replace(/```$/, '').trim()
  return JSON.parse(sanitizeJsonControlChars(cleaned))
}

// Same fix applied to the blog/newsletter functions — the model can embed
// literal newlines/tabs inside a JSON string value instead of escaping
// them, which breaks JSON.parse. Only touches characters actually inside
// a string literal, leaving structural JSON whitespace untouched.
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
    const xaiKey = Deno.env.get('XAI_API_KEY')
    if (!xaiKey) throw new Error('XAI_API_KEY not configured')

    const raw = await callGrokGrounded(xaiKey, buildPrompt())
    const parsed = parseJson(raw)
    const candidates: any[] = Array.isArray(parsed.products) ? parsed.products : []

    if (candidates.length === 0) {
      return new Response(JSON.stringify({ success: true, note: 'AI found nothing worth proposing this run.', added: 0 }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }

    const rows = candidates.slice(0, MAX_PRODUCTS_PER_RUN)
      .filter(c => c.name && c.source_price_ngn && c.source_url)
      .map(c => {
        const sourcePrice = Number(c.source_price_ngn)
        return {
          name: String(c.name).slice(0, 200),
          description: String(c.description ?? '').slice(0, 1000),
          category: String(c.category ?? 'Accessories').slice(0, 50),
          price: Math.round(sourcePrice * MARKUP_MULTIPLIER),
          source_price: sourcePrice,
          source_url: String(c.source_url).slice(0, 500),
          is_ai_sourced: true,
          review_status: 'pending_review',
          is_active: true,
          stock: 5,
          images: [],
          seller_id: null,
          delivery_estimate: DELIVERY_ESTIMATE_TEXT,
        }
      })

    if (rows.length === 0) {
      return new Response(JSON.stringify({ success: true, note: 'AI proposals were missing required fields, none inserted.', added: 0 }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }

    const { error: insertError } = await supabase.from('products').insert(rows)
    if (insertError) throw insertError

    return new Response(JSON.stringify({ success: true, added: rows.length, note: 'Awaiting review in the admin dashboard.' }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })

  } catch (error) {
    console.error('ai-product-scout error:', error)
    return new Response(JSON.stringify({ success: false, error: (error as Error).message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
  }
})
