import { extractText, getDocumentProxy } from 'npm:unpdf'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const GROQ_MODEL = 'llama-3.3-70b-versatile'
const GROQ_ENDPOINT = 'https://api.groq.com/openai/v1/chat/completions'
const CHUNK_SIZE = 18000
const MAX_CHUNKS_PER_TICK = 3
const TIME_BUDGET_MS = 100_000

const SEGMENT_SYSTEM_PROMPT = `You are helping split a messy, unstructured school curriculum document into distinct teaching topics.

The document may have inconsistent formatting, missing headers, or mixed subjects and class levels. Do your best to infer boundaries from context — a change in subject matter, a new heading-like line, a shift in difficulty or vocabulary.

You are looking at ONE PART of a larger document. Topics may continue from the previous part or start fresh here.

For each distinct topic you find in THIS part, extract:
- subject: the school subject (Mathematics, English, Biology, etc.)
- class_level: best guess from this list only: Primary 1, Primary 2, Primary 3, Primary 4, Primary 5, Primary 6, JSS 1, JSS 2, JSS 3, SS 1, SS 2, SS 3. If genuinely unclear, use "JSS 1" as a placeholder — the human reviewing this will fix it.
- topic: a short topic name (e.g. "Fractions", "Photosynthesis")
- content: a focused 150-400 word extract or summary of the actual teaching content for this topic — not the whole document, just what's relevant to this topic

Respond with ONLY a JSON array, nothing else: [{"subject":"...","class_level":"...","topic":"...","content":"..."}]`

async function callGroqSegment(apiKey: string, chunkText: string, alreadyFound: string[]): Promise<any[]> {
  const context = alreadyFound.length > 0
    ? `Topics already identified in earlier parts of this document (avoid re-listing these unless this part clearly adds NEW content to one of them): ${alreadyFound.join(', ')}\n\n`
    : ''

  const res = await fetch(GROQ_ENDPOINT, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${apiKey}` },
    body: JSON.stringify({
      model: GROQ_MODEL,
      messages: [
        { role: 'system', content: SEGMENT_SYSTEM_PROMPT },
        { role: 'user', content: `${context}Document part text:\n\n${chunkText}` },
      ],
      max_tokens: 4096,
      temperature: 0.3,
    }),
  })

  if (!res.ok) {
    const errText = await res.text()
    if (errText.includes('rate_limit_exceeded') && errText.includes('tokens per day')) {
      throw new Error(`DAILY_QUOTA_EXCEEDED: ${errText}`)
    }
    throw new Error(`Groq API error: ${errText}`)
  }

  const data = await res.json()
  let raw = data.choices[0].message.content.trim()
  raw = raw.replace(/^```(?:json)?\s*/i, '').replace(/```\s*$/i, '').trim()
  try {
    return JSON.parse(raw)
  } catch {
    const match = raw.match(/\[[\s\S]*\]/)
    if (!match) throw new Error('Could not parse AI segmentation response')
    return JSON.parse(match[0])
  }
}

function chunkTextIntoParts(text: string, size: number): string[] {
  const chunks: string[] = []
  for (let i = 0; i < text.length; i += size) chunks.push(text.slice(i, i + size))
  return chunks
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response(null, { headers: corsHeaders })

  try {
    const body = await req.json()
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )
    const groqKey = Deno.env.get('GROQ_API_KEY')
    if (!groqKey) throw new Error('GROQ_API_KEY not configured')

    if (body.mode === 'advance_segmentation') {
      return await handleAdvanceSegmentation(supabase, groqKey)
    }

    const { pdf_base64, institution_id, uploaded_by, filename } = body
    if (!pdf_base64) throw new Error('pdf_base64 is required')

    const binary = atob(pdf_base64)
    const bytes = new Uint8Array(binary.length)
    for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i)

    const pdf = await getDocumentProxy(bytes)
    const { text: fullText, totalPages } = await extractText(pdf, { mergePages: true })
    const chunks = chunkTextIntoParts(fullText.trim(), CHUNK_SIZE)

    const { data: job, error } = await supabase.from('pdf_segmentation_jobs').insert({
      institution_id, uploaded_by, filename: filename ?? 'upload.pdf',
      text_chunks: chunks, next_chunk_index: 0, total_chunks: chunks.length,
      accumulated_topics: [], status: 'processing',
    }).select().single()

    if (error) throw new Error(error.message)

    return new Response(
      JSON.stringify({ job_id: job.id, total_chunks: chunks.length, total_pages: totalPages }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('extract-and-segment-curriculum error:', error)
    return new Response(
      JSON.stringify({ error: (error as Error).message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})

// ── Background chunk processor ──────────────────────────────────
// Called by pg_cron every minute. Claims one job, works through a
// few of its text chunks (staying under the 150s limit), saves
// progress after each chunk so nothing is lost between ticks, and
// releases the job for the next tick to continue — or marks it
// ready once every chunk has been processed. Same quota-aware
// behavior as the game generator: a daily-limit hit pauses this
// job without marking it failed.
async function handleAdvanceSegmentation(supabase: any, groqKey: string): Promise<Response> {
  const startTime = Date.now()

  const { data: claimed, error: claimError } = await supabase.rpc('claim_next_pdf_segmentation_job')
  if (claimError) {
    console.error('claim error:', claimError)
    return new Response(JSON.stringify({ processed: 0, error: claimError.message }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
  }
  if (!claimed || claimed.length === 0) {
    return new Response(JSON.stringify({ processed: 0 }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
  }

  const job = claimed[0]
  let chunkIndex = job.next_chunk_index as number
  const totalChunks = job.total_chunks as number
  const chunks = job.text_chunks as string[]
  let accumulated = (job.accumulated_topics as any[]) ?? []
  let errorCount = job.error_count as number
  const jobId = job.id as string

  let processedThisTick = 0
  let quotaHit = false

  for (let i = 0; i < MAX_CHUNKS_PER_TICK; i++) {
    if (chunkIndex >= totalChunks) break
    if (Date.now() - startTime > TIME_BUDGET_MS) break

    try {
      const alreadyFoundNames = accumulated.map((t: any) => t.topic).filter(Boolean)
      const newTopics = await callGroqSegment(groqKey, chunks[chunkIndex], alreadyFoundNames)
      accumulated = [...accumulated, ...newTopics]
      chunkIndex += 1
      errorCount = 0
      processedThisTick += 1

      await supabase.from('pdf_segmentation_jobs').update({
        next_chunk_index: chunkIndex,
        accumulated_topics: accumulated,
        error_count: 0,
      }).eq('id', jobId)

    } catch (error) {
      const message = (error as Error).message
      console.error(`segmentation error on job ${jobId}, chunk ${chunkIndex}:`, error)
      if (message.startsWith('DAILY_QUOTA_EXCEEDED')) {
        quotaHit = true
        break
      }
      errorCount += 1
      await supabase.from('pdf_segmentation_jobs').update({
        error_count: errorCount,
        status: errorCount >= 3 ? 'failed' : 'processing',
      }).eq('id', jobId)
      if (errorCount >= 3) break
    }
  }

  const isDone = chunkIndex >= totalChunks
  await supabase.from('pdf_segmentation_jobs').update({
    status: isDone ? 'ready' : 'processing',
    processing_locked_at: null,
  }).eq('id', jobId)

  return new Response(
    JSON.stringify({ processed: processedThisTick, job_id: jobId, chunk_index: chunkIndex, total_chunks: totalChunks, done: isDone, quota_exceeded: quotaHit }),
    { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
  )
}
