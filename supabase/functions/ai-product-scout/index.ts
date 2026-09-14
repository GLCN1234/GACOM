// AI product scout — back on Gemini (free), but using its OWN separate
// API key (GEMINI_API_KEY_SCOUT) instead of the GEMINI_API_KEY shared by
// blog generation, curriculum questions, and the newsletter. That
// sharing was the actual cause of the quota error — not Gemini itself.
// A second free-tier Google Cloud project/key gives this feature its own
// quota pool at zero cost.
//
// Setup: create a new API key at aistudio.google.com under a project
// separate from your existing one, then:
//   supabase secrets set GEMINI_API_KEY_SCOUT=your_new_key_here
import { createClient } from 'jsr:@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const GEMINI_MODEL = 'gemini-flash-lite-latest'
const GEMINI_ENDPOINT = `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent`
const MARKUP_MULTIPLIER = 1.20 // 20% added profit
const MAX_PRODUCTS_PER_RUN = 6
const DELIVERY_ESTIMATE_TEXT = '4-6 weeks (may arrive sooner, but not later)'

const SYSTEM_PROMPT = `You are a product scout for GACOM, a Nigerian gaming
social platform with a marketplace selling gaming-related physical
products (peripherals, merch, collectibles, accessories) to an African
gaming audience. You do NOT have live web search — rely only on well-
established, widely-known products you are genuinely confident actually
exist (major brands, well-known product lines), never obscure or
recently-launched items you're unsure about. Getting a product, price, or
URL wrong is a real problem, not a minor one — when in doubt, propose
fewer products rather than guess. Never invent a product, price, or link;
if you cannot recall a real source URL with confidence, omit that product
entirely rather than fabricate one. Use your own judgment: only propose
products you genuinely believe would sell well to this specific audience.
Return between 1 and ${MAX_PRODUCTS_PER_RUN} products — fewer is fine.
Prices you find should be converted to Nigerian Naira (NGN) if not
already in NGN, using a reasonable current exchange rate. Return ONLY
valid JSON, no markdown fences, no commentary.`

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

async function callGeminiGrounded(apiKey: string, prompt: string): Promise<string> {
  const response = await fetch(`${GEMINI_ENDPOINT}?key=${apiKey}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      systemInstruction: { parts: [{ text: SYSTEM_PROMPT }] },
      contents: [{ role: 'user', parts: [{ text: prompt }] }],
      // No grounding tool — that specifically requires a linked billing
      // account even on an otherwise-free project. This means results
      // come from the model's own training knowledge, not live search,
      // which carries real hallucination risk (a product, price, or link
      // that doesn't actually exist). The pending_review queue is now
      // the ONLY safety net — every AI-proposed product needs a genuine,
      // careful check before approving, not a quick glance.
      generationConfig: { maxOutputTokens: 2048, temperature: 0.6 },
    }),
  })
  if (!response.ok) throw new Error(`Gemini API error: ${await response.text()}`)
  const data = await response.json()
  const text = data?.candidates?.[0]?.content?.parts
    ?.map((p: any) => p.text).filter(Boolean).join('\n')
  if (!text) throw new Error(`Gemini returned no content: ${JSON.stringify(data)}`)
  return text.trim()
}

function parseJson(raw: string): any {
  const match = raw.match(/\{[\s\S]*\}/)
  const cleaned = (match ? match[0] : raw).replace(/^```json\s*/i, '').replace(/```$/, '').trim()
  return JSON.parse(cleaned)
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  )

  try {
    // Deliberately a DIFFERENT secret name from the one blog/questions/
    // newsletter use, so this can be a separate free-tier key with its
    // own quota rather than competing for the same one.
    const geminiKey = Deno.env.get('GEMINI_API_KEY_SCOUT')
    if (!geminiKey) throw new Error('GEMINI_API_KEY_SCOUT not configured — set up a second, separate Gemini API key for this feature.')

    const raw = await callGeminiGrounded(geminiKey, buildPrompt())
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
