import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const GROQ_MODEL = 'llama-3.3-70b-versatile'
const GROQ_ENDPOINT = 'https://api.groq.com/openai/v1/chat/completions'

const LEVELS = [
  { key: 'foundation', label: 'Foundation', count: 60, instruction: 'Very basic recall and recognition. Single-step. Beginner-friendly, gentle introduction to the world.' },
  { key: 'beginner', label: 'Beginner', count: 60, instruction: 'Simple application, one or two steps. The adventure starts picking up pace.' },
  { key: 'intermediate', label: 'Intermediate', count: 60, instruction: 'Multi-step challenges requiring real understanding. Stakes rise in the story.' },
  { key: 'advanced', label: 'Advanced', count: 60, instruction: 'Complex reasoning, harder calculations, edge cases. The adventure nears its climax.' },
  { key: 'challenge', label: 'Boss Battle', count: 60, instruction: 'WAEC/NECO/JAMB exam-level mastery, disguised as the final boss fight of the adventure. Tricky, exam-style traps woven into the story climax.' },
]

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

GOLDEN RULE: If the child feels like they are studying, you have failed. They should think "I want to beat this level," never "I am learning Mathematics." Learning must become invisible. Fun must become obvious.

CORE PHILOSOPHY: Never ask "what question should I ask?" Ask "what game mechanic naturally teaches this concept?" Every lesson becomes gameplay wrapped in story, mission, world, goal, challenge, reward, and progression.

HIDE THE LEARNING — do not present the underlying academic question directly. Wrap it in narrative:
Never: "What is 7 + 5?"
Instead: "The bridge needs 12 magic stones. You already collected 7. Find the remaining stones before sunset."
Never: "Spell Elephant."
Instead: "The Elephant Guardian has forgotten its magical name. Restore the ancient letters before the portal closes."

STORY FIRST — every generation begins with a short adventure premise that frames the whole topic as a quest, mission, or world to explore.

PLAYER EMOTION — the player should feel curiosity, wonder, excitement, achievement, discovery. Never boredom, never fear of failure.

FAILURE IS NARRATIVE — never say "Wrong" or "Incorrect." Instead: "The bridge collapses — try a different path." Always gentle, always inviting another attempt.

REWARDS ARE THEMED — describe rewards in-world: XP, Coins, Knowledge Crystals, Story Progress — not plain "+10 points."

BOSS BATTLES — the final difficulty level of every topic is the story's climax: a named boss who must be defeated by demonstrating full mastery of the topic.

Every single question must still be a real, gradeable academic question underneath — the story is the skin, the curriculum is the skeleton. Never sacrifice academic accuracy for the sake of story.

You must respond with ONLY valid JSON as instructed in each request — no markdown code fences, no explanation text before or after.`

async function callGroq(apiKey: string, prompt: string, maxTokens: number, attempt = 1): Promise<string> {
  const response = await fetch(GROQ_ENDPOINT, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${apiKey}`,
    },
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

  if (response.status === 429 && attempt <= 4) {
    const retryAfter = response.headers.get('retry-after')
    const waitMs = retryAfter ? parseFloat(retryAfter) * 1000 : attempt * 8000
    console.log(`Groq rate limited, waiting ${waitMs}ms (attempt ${attempt})`)
    await new Promise(r => setTimeout(r, waitMs))
    return callGroq(apiKey, prompt, maxTokens, attempt + 1)
  }

  if (!response.ok) {
    const err = await response.text()
    throw new Error(`Groq API error: ${err}`)
  }

  const data = await response.json()
  return data.choices[0].message.content.trim()
}

async function generateLevelQuestions(
  apiKey: string,
  subject: string,
  classLevel: string,
  topic: string,
  content: string,
  level: typeof LEVELS[0],
  worldTheme: string,
): Promise<any[]> {
  const prompt = `Subject: ${subject}
Class Level: ${classLevel}
Topic: ${topic}
Difficulty Stage: ${level.label}
Stage Instructions: ${level.instruction}
World Theme for this adventure: ${worldTheme}

Curriculum Content to teach (keep every question academically accurate to this):
${content.slice(0, 2500)}

Generate exactly ${level.count} questions for the "${level.label}" stage of this "${worldTheme}"-themed adventure.
Use a mix of these underlying question mechanics across the ${level.count} questions (but always wrap them in the story — never show the raw academic phrasing): ${QUESTION_TYPES.join(' | ')}

Rules:
- Every question must be wrapped in the "${worldTheme}" narrative
- Every question must still test ONLY this specific curriculum topic, with a real, correct, gradeable answer
- Vary the underlying mechanic — do not make all of them multiple choice
- "steps" must explain the real academic working needed to solve it
- "narrative_success" is a short, fun in-world line for a correct answer
- "narrative_failure" is a short, gentle, in-world line for a wrong answer (never says "wrong")
- "concept" is one sentence stating the real academic concept (plain academic language, for parent/teacher review)
- If this is the "Boss Battle" stage, questions should feel like a climactic final showdown

Respond ONLY with a valid JSON array, nothing else:
[{"type":"multiple_choice","question":"...","options":["A. ...","B. ...","C. ...","D. ..."],"answer":"A. ...","steps":["Step 1: ...","Step 2: ..."],"narrative_success":"...","narrative_failure":"...","concept":"..."}]`

  const rawText = await callGroq(apiKey, prompt, 7000)

  let questions
  try {
    questions = JSON.parse(rawText)
  } catch {
    const match = rawText.match(/\[[\s\S]*\]/)
    if (match) {
      try { questions = JSON.parse(match[0]) }
      catch { throw new Error(`Could not parse AI response for level ${level.label}`) }
    } else {
      throw new Error(`Could not parse AI response for level ${level.label}`)
    }
  }

  return questions.map((q: any) => ({ ...q, level: level.key, level_label: level.label, world_theme: worldTheme }))
}

async function generateStoryIntro(apiKey: string, subject: string, topic: string, worldTheme: string): Promise<string> {
  const prompt = `Write a short (3-4 sentence) adventure story intro that frames the topic "${topic}" (subject: ${subject}) as a "${worldTheme}"-themed quest. Shown to the student before they start playing — hook them immediately like the opening of a game.

Respond with ONLY the story text, no JSON, no quotes, no extra formatting.`

  try {
    return await callGroq(apiKey, prompt, 300)
  } catch {
    return `Your adventure into ${topic} begins now!`
  }
}

const WORLD_THEMES = [
  'Pizza Shop Adventure', 'Treasure Hunt', 'Space Mission', 'Pirate Voyage', 'Dragon Kingdom',
  'Robot Builder Lab', 'Candy Factory', 'Village Festival', 'Detective Mystery', 'Jungle Expedition',
  'Underwater City', 'Racing Championship', 'Farm Tycoon', 'Wizard Academy', 'City Builder',
]

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response(null, { headers: corsHeaders })

  let curriculum_id: string | undefined

  try {
    const body = await req.json()
    curriculum_id = body.curriculum_id
    const { subject, class_level, topic, content } = body

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    const groqKey = Deno.env.get('GROQ_API_KEY')
    if (!groqKey) throw new Error('GROQ_API_KEY not configured — add it in Supabase Dashboard > Edge Functions > Secrets')

    if (curriculum_id) {
      const { data: curriculum } = await supabase
        .from('institution_curricula')
        .select('institution_id')
        .eq('id', curriculum_id)
        .single()

      if (curriculum?.institution_id) {
        const { data: institution } = await supabase
          .from('institutions')
          .select('ai_calls_used, ai_calls_limit')
          .eq('id', curriculum.institution_id)
          .single()

        if (institution) {
          const used = institution.ai_calls_used ?? 0
          const limit = institution.ai_calls_limit ?? 50
          if (used >= limit) {
            await supabase.from('institution_curricula')
              .update({ status: 'failed' }).eq('id', curriculum_id)
            return new Response(
              JSON.stringify({ error: 'AI generation limit reached. Please upgrade your institution plan.' }),
              { status: 402, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
          }
        }
      }
    }

    const worldTheme = WORLD_THEMES[Math.floor(Math.random() * WORLD_THEMES.length)]
    const storyIntro = await generateStoryIntro(groqKey, subject, topic, worldTheme)

    const allQuestions: any[] = []
    for (const level of LEVELS) {
      console.log(`Generating ${level.count} ${level.label} questions for: ${topic} (theme: ${worldTheme})`)
      const questions = await generateLevelQuestions(groqKey, subject, class_level, topic, content, level, worldTheme)
      allQuestions.push(...questions)
      await new Promise(r => setTimeout(r, 12000))
    }

    await supabase.from('institution_curricula').update({
      generated_questions: allQuestions,
      status: 'ready',
      total_questions: allQuestions.length,
      world_theme: worldTheme,
      story_intro: storyIntro,
    }).eq('id', curriculum_id)

    if (curriculum_id) {
      const { data: curriculum } = await supabase
        .from('institution_curricula').select('institution_id').eq('id', curriculum_id).single()
      if (curriculum?.institution_id) {
        await supabase.rpc('increment_ai_calls', { inst_id: curriculum.institution_id })
      }
    }

    return new Response(
      JSON.stringify({ success: true, total_questions: allQuestions.length, world_theme: worldTheme, levels: LEVELS.map(l => l.label) }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('generate-curriculum-games error:', error)
    if (curriculum_id) {
      try {
        const supabase = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!)
        await supabase.from('institution_curricula').update({ status: 'failed' }).eq('id', curriculum_id)
      } catch (_) {}
    }
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
