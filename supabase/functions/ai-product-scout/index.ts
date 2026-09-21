// AI product scout — on Groq now, using their built-in browser_search
// tool for real current products (not the model's own memory, and not
// xAI which needs paid billing). Autonomous: real search means real
// hallucination risk is low, so this publishes directly, no review
// queue — matches the explicit request to make this fully autonomous.
//
// Requires GROQ_API_KEY (same free-tier key as the blog function).
import { createClient } from 'jsr:@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const GROQ_ENDPOINT = 'https://api.groq.com/openai/v1/chat/completions'
const GROQ_MODEL = 'openai/gpt-oss-20b'
const MARKUP_MULTIPLIER = 1.20 // 20% added profit
const MAX_PRODUCTS_PER_RUN = 6
const DELIVERY_ESTIMATE_TEXT = '4-6 weeks (may arrive sooner, but not later)'

const SYSTEM_PROMPT = `You are a product scout for GACOM, a Nigerian gaming
social platform with a marketplace selling gaming-related physical
products (peripherals, merch, collectibles, accessories) to an African
gaming audience. Use the browser_search tool to find REAL, currently-sold
products with REAL source URLs and REAL current prices — never invent a
product, price, or link. Use your own judgment: only propose products you
genuinely believe would sell well to this specific audience. Return
between 1 and ${MAX_PRODUCTS_PER_RUN} products. Prices you find should be
converted to Nigerian Naira (NGN) if not already in NGN, using a
reasonable current exchange rate. Return ONLY valid JSON, no markdown
fences, no commentary.`

function buildPrompt(): string {
  return `Search for real gaming products worth adding to the marketplace right now. Return this exact JSON shape:
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
    const parsed = parseJson(raw)
    const candidates: any[] = Array.isArray(parsed.products) ? parsed.products : []

    if (candidates.length === 0) {
      return new Response(JSON.stringify({ success: true, note: 'Nothing worth proposing this run.', added: 0 }),
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
          review_status: 'approved',
          is_active: true,
          stock: 5,
          images: [],
          seller_id: null,
          delivery_estimate: DELIVERY_ESTIMATE_TEXT,
        }
      })

    if (rows.length === 0) {
      return new Response(JSON.stringify({ success: true, note: 'Proposals were missing required fields, none inserted.', added: 0 }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }

    const { error: insertError } = await supabase.from('products').insert(rows)
    if (insertError) throw insertError

    return new Response(JSON.stringify({ success: true, added: rows.length }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })

  } catch (error) {
    console.error('ai-product-scout error:', error)
    return new Response(JSON.stringify({ success: false, error: (error as Error).message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
  }
})
