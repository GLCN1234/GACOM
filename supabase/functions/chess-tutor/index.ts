import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }
  try {
    const { pieceName, fromSquare, toSquare, capturedPiece, moveNumber, isHanging, isCheck, lessonFocus } = await req.json()

    const apiKey = Deno.env.get('GEMINI_API_KEY')
    if (!apiKey) {
      return new Response(
        JSON.stringify({ error: 'Gemini API key not configured' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const systemPrompt = `You are Ryan, a warm, patient chess tutor teaching a complete beginner.

The student just made a move. Explain it in ONE short sentence \u2014 never more than one. This is displayed on screen for a few seconds between moves, so it must be scannable at a glance, not read carefully. Rules:
- Say directly whether the move was good, risky, or a mistake \u2014 lead with that.
- Only explain how a piece moves if this is truly the very first time that piece type has appeared \u2014 otherwise skip straight to judging the move.
- If a piece is left capturable for free, say so plainly in the same single sentence.
- Never use chess jargon (fork, development, tempo) without a two-word plain explanation attached.
- No preamble, no "Great question", just the one sentence of real feedback.`

    const situationDetails = [
      `Move number: ${moveNumber}`,
      `Piece moved: ${pieceName}`,
      `From square ${fromSquare} to square ${toSquare}`,
      capturedPiece ? `This move captured a ${capturedPiece}` : `No capture happened`,
      isHanging ? `Warning: this piece is now undefended and could be captured next turn` : ``,
      isCheck ? `This move puts the opponent in check` : ``,
      lessonFocus ? `The student is currently learning about: ${lessonFocus}. Prioritize tying your feedback to this specific lesson focus when relevant.` : ``,
    ].filter(Boolean).join('. ')

    const geminiRes = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent?key=${apiKey}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          contents: [{ parts: [{ text: `${systemPrompt}\n\nSituation: ${situationDetails}\n\nExplain this move to the student now.` }] }],
          generationConfig: { maxOutputTokens: 80, temperature: 0.7 },
        }),
      }
    )

    if (!geminiRes.ok) {
      const errText = await geminiRes.text()
      return new Response(
        JSON.stringify({ error: `Gemini API error: ${errText}` }),
        { status: 502, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const data = await geminiRes.json()
    const explanation = data?.candidates?.[0]?.content?.parts?.[0]?.text?.trim() ?? 'Good move — keep going!'

    return new Response(
      JSON.stringify({ explanation }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (err) {
    return new Response(
      JSON.stringify({ error: String(err) }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
