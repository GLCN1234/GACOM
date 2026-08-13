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
    const { pieceName, fromSquare, toSquare, capturedPiece, moveNumber, isHanging, isCheck } = await req.json()

    const apiKey = Deno.env.get('GEMINI_API_KEY')
    if (!apiKey) {
      return new Response(
        JSON.stringify({ error: 'Gemini API key not configured' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const systemPrompt = `You are Ryan, a warm, patient chess tutor teaching a complete beginner who is learning chess for the very first time.

The student just made a move. Explain it in 2-3 short, friendly sentences (never more). Rules for what to include:
- If this is one of the first few moves in the game, briefly explain HOW that piece type is allowed to move in chess, in plain simple words (no jargon like "diagonal" without explaining what it means).
- Say clearly whether the move was good, risky, or a mistake, and WHY, in beginner language — never assume they know chess terms like "fork", "development", "tempo" without briefly explaining what you mean.
- If the move leaves a piece capturable for free, say so directly and explain what could happen next.
- If it was a capture, celebrate it simply.
- Be encouraging always, even when correcting a mistake — this is their first time learning.
- Keep it SHORT. A beginner reading after every move needs brevity, not an essay.`

    const situationDetails = [
      `Move number: ${moveNumber}`,
      `Piece moved: ${pieceName}`,
      `From square ${fromSquare} to square ${toSquare}`,
      capturedPiece ? `This move captured a ${capturedPiece}` : `No capture happened`,
      isHanging ? `Warning: this piece is now undefended and could be captured next turn` : ``,
      isCheck ? `This move puts the opponent in check` : ``,
    ].filter(Boolean).join('. ')

    const geminiRes = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent?key=${apiKey}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          contents: [{ parts: [{ text: `${systemPrompt}\n\nSituation: ${situationDetails}\n\nExplain this move to the student now.` }] }],
          generationConfig: { maxOutputTokens: 200, temperature: 0.7 },
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
