import { extractText, getDocumentProxy } from 'npm:unpdf'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const GROQ_MODEL = 'llama-3.3-70b-versatile'
const GROQ_ENDPOINT = 'https://api.groq.com/openai/v1/chat/completions'
const MAX_CHARS = 20000

const SEGMENT_SYSTEM_PROMPT = `You are helping split a messy, unstructured school curriculum document into distinct teaching topics.

The document may have inconsistent formatting, missing headers, or mixed subjects and class levels. Do your best to infer boundaries from context — a change in subject matter, a new heading-like line, a shift in difficulty or vocabulary.

For each distinct topic you find, extract:
- subject: the school subject (Mathematics, English, Biology, etc.)
- class_level: best guess from this list only: Primary 1, Primary 2, Primary 3, Primary 4, Primary 5, Primary 6, JSS 1, JSS 2, JSS 3, SS 1, SS 2, SS 3. If genuinely unclear, use "JSS 1" as a placeholder — the human reviewing this will fix it.
- topic: a short topic name (e.g. "Fractions", "Photosynthesis")
- content: a focused 150-400 word extract or summary of the actual teaching content for this topic — not the whole document, just what's relevant to this topic

Respond with ONLY a JSON array, nothing else: [{"subject":"...","class_level":"...","topic":"...","content":"..."}]`

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response(null, { headers: corsHeaders })

  try {
    const { pdf_base64 } = await req.json()
    if (!pdf_base64) throw new Error('pdf_base64 is required')

    const groqKey = Deno.env.get('GROQ_API_KEY')
    if (!groqKey) throw new Error('GROQ_API_KEY not configured')

    const binary = atob(pdf_base64)
    const bytes = new Uint8Array(binary.length)
    for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i)

    const pdf = await getDocumentProxy(bytes)
    const { text: fullText, totalPages } = await extractText(pdf, { mergePages: true })

    let text = fullText.trim()
    const truncated = text.length > MAX_CHARS
    if (truncated) text = text.slice(0, MAX_CHARS)

    const groqRes = await fetch(GROQ_ENDPOINT, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${groqKey}` },
      body: JSON.stringify({
        model: GROQ_MODEL,
        messages: [
          { role: 'system', content: SEGMENT_SYSTEM_PROMPT },
          { role: 'user', content: `Document text:\n\n${text}` },
        ],
        max_tokens: 6000,
        temperature: 0.3,
      }),
    })

    if (!groqRes.ok) {
      const errText = await groqRes.text()
      if (errText.includes('rate_limit_exceeded') && errText.includes('tokens per day')) {
        throw new Error("Groq's free daily AI quota is used up for today — try again in a couple of hours.")
      }
      throw new Error(`Groq API error: ${errText}`)
    }

    const groqData = await groqRes.json()
    let raw = groqData.choices[0].message.content.trim()
    raw = raw.replace(/^```(?:json)?\s*/i, '').replace(/```\s*$/i, '').trim()

    let topics: any[]
    try {
      topics = JSON.parse(raw)
    } catch {
      const match = raw.match(/\[[\s\S]*\]/)
      if (!match) throw new Error('Could not parse AI segmentation response')
      topics = JSON.parse(match[0])
    }

    return new Response(
      JSON.stringify({ topics, total_pages: totalPages, truncated, chars_processed: text.length }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('extract-and-segment-curriculum error:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
