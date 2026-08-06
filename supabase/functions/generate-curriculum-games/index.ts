import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const GROQ_MODEL = 'llama-3.3-70b-versatile'
const GROQ_ENDPOINT = 'https://api.groq.com/openai/v1/chat/completions'
const BATCH_SIZE = 15
const QUESTIONS_PER_LEVEL = 60
const BATCHES_PER_LEVEL = QUESTIONS_PER_LEVEL / BATCH_SIZE

const LEVELS = [
  { key: 'foundation', label: 'Foundation', instruction: 'Very basic recall and recognition. Single-step. Beginner-friendly, gentle introduction to the world.' },
  { key: 'beginner', label: 'Beginner', instruction: 'Simple application, one or two steps. The adventure starts picking up pace.' },
  { key: 'intermediate', label: 'Intermediate', instruction: 'Multi-step challenges requiring real understanding. Stakes rise in the story.' },
  { key: 'advanced', label: 'Advanced', instruction: 'Complex reasoning, harder calculations, edge cases. The adventure nears its climax.' },
  { key: 'challenge', label: 'Boss Battle', instruction: 'WAEC/NECO/JAMB exam-level mastery, disguised as the final boss fight of the adventure. Tricky, exam-style traps woven into the story climax.' },
]

const TOTAL_BATCHES = 1 + LEVELS.length * BATCHES_PER_LEVEL

const QUESTION_TYPES = [
  'multiple_choice (4 options A B C D)',
  'true_false (statement with True or False answer, include explanation)',
  'fill_blank (sentence with ___ gap, student fills in)',
  'calculation (show full working in steps)',
  'spot_the_error (show wrong working, student identifies the mistake and corrects it)',
]

const GACOM_GAME_DESIGNER_SYSTEM_PROMPT = `You are the Gacom Edu Gaming AI Game Designer.

Your responsibility is NOT to generate quizzes, worksheets, flashcards, or examination questions.
Your responsibility is to transform every learning objective into a game children genuinely enjoy playing — like Roblox, Minecraft, Mario, Pokémon, Zelda, or an exciting adventure game, not schoolwork.

GOLDEN RULE: If the child feels like they are studying, you have failed. They should think "I want to beat this level," never "I am learning Mathematics."

HIDE THE LEARNING — wrap the academic question in narrative:
Never: "What is 7 + 5?"
Instead: "The bridge needs 12 magic stones. You already collected 7. Find the remaining stones before sunset."

FAILURE IS NARRATIVE — never say "Wrong." Instead: "The bridge collapses — try a different path."

REWARDS ARE THEMED — XP, Coins, Knowledge Crystals — not plain "+10 points."

BOSS BATTLES — the final level is the story's climax: a named boss defeated by demonstrating full mastery.

Every question must still be a real, gradeable academic question underneath. Never sacrifice academic accuracy for the sake of story.

CRITICAL: Respond with ONLY a raw JSON object as instructed in each request. No markdown code fences, no explanation text before or after.`

async function callGroq(apiKey: string, prompt: string, maxTokens: number, attempt = 1): Promise<string> {
  const response = await fetch(GROQ_ENDPOINT, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${apiKey}` },
    body: JSON.stringify({
      model: GROQ_MODEL,
      messages: [
        { role: 'system', content: GACOM_GAME_DESIGNER_SYSTEM_PROMPT },
        { role: 'user', content: prompt },
      ],
      max_tokens: maxTokens,
      temperature: 0.8,
    }),
  })

  if (response.status === 429 && attempt <= 2) {
    const retryAfter = response.headers.get('retry-after')
    const waitMs = retryAfter ? parseFloat(retryAfter) * 1000 : 4000
    await new Promise(r => setTimeout(r, waitMs))
    return callGroq(apiKey, prompt, maxTokens, attempt + 1)
  }

  if (!response.ok) {
    const err = await response.text()
    if (err.includes('rate_limit_exceeded') && err.includes('tokens per day')) {
      throw new Error(`DAILY_QUOTA_EXCEEDED: ${err}`)
    }
    throw new Error(`Groq API error: ${err}`)
  }

  const data = await response.json()
  return data.choices[0].message.content.trim()
}

function parseBatchJSON(rawText: string, levelLabel: string): { questions: any[]; chapterUpdate: string } {
  let cleaned = rawText.trim()
  cleaned = cleaned.replace(/^```(?:json)?\s*/i, '').replace(/```\s*$/i, '').trim()
  try {
    const parsed = JSON.parse(cleaned)
    return { questions: parsed.questions ?? [], chapterUpdate: parsed.chapter_update ?? '' }
  } catch { /* fall through */ }
  const match = cleaned.match(/\{[\s\S]*\}/)
  if (match) {
    try {
      const parsed = JSON.parse(match[0])
      return { questions: parsed.questions ?? [], chapterUpdate: parsed.chapter_update ?? '' }
    } catch { /* fall through */ }
  }
  throw new Error(`Could not parse AI response for level ${levelLabel}`)
}

const WORLD_THEMES = [
  'Pizza Shop Adventure', 'Treasure Hunt', 'Space Mission', 'Pirate Voyage', 'Dragon Kingdom',
  'Robot Builder Lab', 'Candy Factory', 'Village Festival', 'Detective Mystery', 'Jungle Expedition',
  'Underwater City', 'Racing Championship', 'Farm Tycoon', 'Wizard Academy', 'City Builder',
]

async function generateQuestionBatch(
  apiKey: string, subject: string, classLevel: string, topic: string, content: string,
  level: typeof LEVELS[0], worldTheme: string, storyIntro: string, storyProgress: string,
): Promise<{ questions: any[]; chapterUpdate: string }> {
  const prompt = `Subject: ${subject}
Class Level: ${classLevel}
Topic: ${topic}
Difficulty Stage: ${level.label}
Stage Instructions: ${level.instruction}
World Theme: ${worldTheme}

The adventure so far:
${storyIntro}
${storyProgress || '(This is the first chapter — nothing has happened yet.)'}

Curriculum Content to teach:
${content.slice(0, 2000)}

Generate exactly ${BATCH_SIZE} questions for the "${level.label}" stage, continuing the SAME story above — reference what already happened, don't restart the premise or introduce a contradictory new goal.
Use a mix of these mechanics (wrap in story — never show raw academic phrasing): ${QUESTION_TYPES.join(' | ')}

Rules:
- Every question wrapped in the "${worldTheme}" narrative, consistent with the adventure so far
- Every question tests ONLY this curriculum topic, with a real, correct, gradeable answer
- Vary the mechanic — not all multiple choice
- "steps": real academic working needed to solve it
- "narrative_success": short fun in-world line for correct answer
- "narrative_failure": short gentle in-world line for wrong answer (never "wrong")
- "concept": one sentence, plain academic language, for parent/teacher review
- If "Boss Battle" stage, questions feel like a climactic showdown

Respond with ONLY this JSON object, nothing else:
{"questions":[{"type":"multiple_choice","question":"...","options":["A. ...","B. ...","C. ...","D. ..."],"answer":"A. ...","steps":["Step 1: ...","Step 2: ..."],"narrative_success":"...","narrative_failure":"...","concept":"..."}],"chapter_update":"One or two sentences: what this stretch of the adventure just accomplished, to carry forward into the next chapter."}`

  const rawText = await callGroq(apiKey, prompt, 4096)
  const { questions, chapterUpdate } = parseBatchJSON(rawText, level.label)
  const tagged = questions.map((q: any) => ({ ...q, level: level.key, level_label: level.label, world_theme: worldTheme }))
  return { questions: tagged, chapterUpdate }
}

async function generateStoryIntro(apiKey: string, subject: string, topic: string, worldTheme: string): Promise<string> {
  const prompt = `Write a short (3-4 sentence) adventure story intro that frames the topic "${topic}" (subject: ${subject}) as a "${worldTheme}"-themed quest. Shown to the student before they start playing — hook them immediately like the opening of a game.

Respond with ONLY the story text, no JSON, no quotes, no extra formatting.`
  try { return await callGroq(apiKey, prompt, 300) }
  catch { return `Your adventure into ${topic} begins now!` }
}

function batchToLevel(batchNumber: number): { level: typeof LEVELS[0]; batchInLevel: number } {
  const idx = batchNumber - 1
  const levelIdx = Math.floor(idx / BATCHES_PER_LEVEL)
  const batchInLevel = idx % BATCHES_PER_LEVEL
  return { level: LEVELS[levelIdx], batchInLevel }
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response(null, { headers: corsHeaders })

  try {
    const body = await req.json()
    const { curriculum_id, subject, class_level, topic, content, batch_number } = body

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    const groqKey = Deno.env.get('GROQ_API_KEY')
    if (!groqKey) throw new Error('GROQ_API_KEY not configured')

    if (body.mode === 'advance_queue') {
      return await handleAdvanceQueue(supabase, groqKey)
    }

    if (batch_number === 0) {
      const { data: curriculum } = await supabase
        .from('institution_curricula').select('institution_id').eq('id', curriculum_id).single()

      if (curriculum?.institution_id) {
        const { data: institution } = await supabase
          .from('institutions').select('ai_calls_used, ai_calls_limit').eq('id', curriculum.institution_id).single()
        if (institution) {
          const used = institution.ai_calls_used ?? 0
          const limit = institution.ai_calls_limit ?? 50
          if (used >= limit) {
            await supabase.from('institution_curricula').update({ status: 'failed' }).eq('id', curriculum_id)
            return new Response(JSON.stringify({ error: 'AI generation limit reached. Please upgrade your institution plan.' }),
              { status: 402, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
          }
        }
      }

      const worldTheme = WORLD_THEMES[Math.floor(Math.random() * WORLD_THEMES.length)]
      const storyIntro = await generateStoryIntro(groqKey, subject, topic, worldTheme)

      await supabase.from('institution_curricula').update({
        world_theme: worldTheme,
        story_intro: storyIntro,
        story_progress: '',
        generated_questions: [],
        status: 'processing',
        total_questions: 0,
      }).eq('id', curriculum_id)

      return new Response(
        JSON.stringify({ done: false, next_batch: 1, total_batches: TOTAL_BATCHES, progress_label: 'Story written', world_theme: worldTheme }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const { level, batchInLevel } = batchToLevel(batch_number)
    if (!level) throw new Error(`Invalid batch_number: ${batch_number}`)

    const { data: existing } = await supabase
      .from('institution_curricula').select('generated_questions, world_theme, story_intro, story_progress').eq('id', curriculum_id).single()

    const worldTheme = existing?.world_theme || 'Adventure'
    const currentQuestions = Array.isArray(existing?.generated_questions) ? existing.generated_questions : []

    const { questions: newQuestions, chapterUpdate } = await generateQuestionBatch(
      groqKey, subject, class_level, topic, content, level, worldTheme,
      existing?.story_intro || '', existing?.story_progress || '',
    )
    if (newQuestions.length > 0) newQuestions[newQuestions.length - 1].chapter_update = chapterUpdate

    const allQuestions = [...currentQuestions, ...newQuestions]
    const rollingProgress = `${existing?.story_progress || ''}\n${chapterUpdate}`.split('\n').filter(Boolean).slice(-3).join('\n')

    const isLastBatch = batch_number === TOTAL_BATCHES - 1

    await supabase.from('institution_curricula').update({
      generated_questions: allQuestions,
      total_questions: allQuestions.length,
      story_progress: rollingProgress,
      status: isLastBatch ? 'ready' : 'processing',
    }).eq('id', curriculum_id)

    if (isLastBatch) {
      const { data: curriculum } = await supabase
        .from('institution_curricula').select('institution_id').eq('id', curriculum_id).single()
      if (curriculum?.institution_id) {
        await supabase.rpc('increment_ai_calls', { inst_id: curriculum.institution_id })
      }
    }

    return new Response(
      JSON.stringify({
        done: isLastBatch,
        next_batch: isLastBatch ? null : batch_number + 1,
        total_batches: TOTAL_BATCHES,
        progress_label: `${level.label} — batch ${batchInLevel + 1}/${BATCHES_PER_LEVEL}`,
        total_questions: allQuestions.length,
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('generate-curriculum-games error:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})

// ── Background queue processor ──────────────────────────────────
// Called by a Supabase pg_cron job every minute, NOT by the browser.
// This is what lets generation keep running even if the institution
// admin closes the tab or shuts their laptop mid-upload. Each tick
// claims the oldest unfinished topic (claim_next_curriculum_batch
// uses FOR UPDATE SKIP LOCKED so two overlapping ticks never grab the
// same row) and advances it by several batches, staying under the
// 150s edge function limit.
const MAX_BATCHES_PER_TICK = 6
const TIME_BUDGET_MS = 100_000

async function handleAdvanceQueue(supabase: any, groqKey: string): Promise<Response> {
  const startTime = Date.now()
  const results: any[] = []

  for (let i = 0; i < MAX_BATCHES_PER_TICK; i++) {
    if (Date.now() - startTime > TIME_BUDGET_MS) break

    const { data: claimed, error: claimError } = await supabase.rpc('claim_next_curriculum_batch')
    if (claimError) { console.error('claim error:', claimError); break }
    if (!claimed || claimed.length === 0) break

    const result = await processOneBatch(supabase, groqKey, claimed[0])
    results.push(result)
    if (result.quota_exceeded) break
  }

  return new Response(JSON.stringify({ processed: results.length, results }),
    { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
}

async function processOneBatch(supabase: any, groqKey: string, row: any): Promise<any> {
  const curriculumId = row.id as string
  const nextBatch = row.next_batch_number as number

  try {
    if (nextBatch === 0) {
      const worldTheme = WORLD_THEMES[Math.floor(Math.random() * WORLD_THEMES.length)]
      const storyIntro = await generateStoryIntro(groqKey, row.subject, row.topic, worldTheme)

      await supabase.from('institution_curricula').update({
        world_theme: worldTheme, story_intro: storyIntro, story_progress: '',
        generated_questions: [], status: 'processing', total_questions: 0,
        next_batch_number: 1, batch_error_count: 0, processing_locked_at: null,
      }).eq('id', curriculumId)

      return { curriculum_id: curriculumId, batch: 0, progress_label: 'Story written' }
    }

    const { level, batchInLevel } = batchToLevel(nextBatch)
    if (!level) throw new Error(`Invalid batch_number: ${nextBatch}`)

    const { data: existing } = await supabase
      .from('institution_curricula').select('generated_questions, world_theme, story_intro, story_progress').eq('id', curriculumId).single()

    const worldTheme = existing?.world_theme || 'Adventure'
    const currentQuestions = Array.isArray(existing?.generated_questions) ? existing.generated_questions : []

    const { questions: newQuestions, chapterUpdate } = await generateQuestionBatch(
      groqKey, row.subject, row.class_level, row.topic, row.content, level, worldTheme,
      existing?.story_intro || '', existing?.story_progress || '',
    )
    if (newQuestions.length > 0) newQuestions[newQuestions.length - 1].chapter_update = chapterUpdate

    const allQuestions = [...currentQuestions, ...newQuestions]
    const rollingProgress = `${existing?.story_progress || ''}\n${chapterUpdate}`.split('\n').filter(Boolean).slice(-3).join('\n')
    const isLastBatch = nextBatch === TOTAL_BATCHES - 1

    await supabase.from('institution_curricula').update({
      generated_questions: allQuestions, total_questions: allQuestions.length,
      story_progress: rollingProgress, status: isLastBatch ? 'ready' : 'processing',
      next_batch_number: nextBatch + 1, batch_error_count: 0, processing_locked_at: null,
    }).eq('id', curriculumId)

    return { curriculum_id: curriculumId, batch: nextBatch, done: isLastBatch, progress_label: `${level.label} — batch ${batchInLevel + 1}/${BATCHES_PER_LEVEL}` }

  } catch (error) {
    const message = (error as Error).message
    console.error(`advance_queue error on ${curriculumId}, batch ${nextBatch}:`, error)
    if (message.startsWith('DAILY_QUOTA_EXCEEDED')) {
      // Not this topic's fault — Groq's free daily token cap was hit.
      // Don't count it as a strike, just release the lock so cron
      // picks this same topic back up once quota resets.
      await supabase.from('institution_curricula').update({ processing_locked_at: null }).eq('id', curriculumId)
      return { curriculum_id: curriculumId, batch: nextBatch, quota_exceeded: true }
    }
    const newErrorCount = (row.batch_error_count ?? 0) + 1
    await supabase.from('institution_curricula').update({
      batch_error_count: newErrorCount,
      status: newErrorCount >= 3 ? 'failed' : 'processing',
      processing_locked_at: null,
    }).eq('id', curriculumId)
    return { curriculum_id: curriculumId, batch: nextBatch, error: message }
  }
}
