// One-sentence chess move feedback from Gemini for the signed-in student.
//
// Security notes:
//   - requires a signed-in user (it used to be open to the internet and spend
//     our Gemini quota), rate limited per user
//   - every field is validated; the only free text (lessonFocus) is length
//     capped and passed as untrusted data
//   - the Gemini key goes in a header, not the URL, and upstream error bodies
//     are never returned
import { secureServe, requireUser, requireEnv, rateLimit, fetchWithTimeout, asString, asInt, HttpError, redact, wrapUntrusted, UNTRUSTED_NOTICE } from '../_shared/security.ts'

const systemPrompt = `You are Ryan, a warm, patient chess tutor teaching a complete beginner.

The student just made a move. Explain it in ONE short sentence \u2014 never more than one. This is displayed on screen for a few seconds between moves, so it must be scannable at a glance, not read carefully. Rules:
- Say directly whether the move was good, risky, or a mistake \u2014 lead with that.
- Only explain how a piece moves if this is truly the very first time that piece type has appeared \u2014 otherwise skip straight to judging the move.
- If a piece is left capturable for free, say so plainly in the same single sentence.
- Never use chess jargon (fork, development, tempo) without a two-word plain explanation attached.
- No preamble, no "Great question", just the one sentence of real feedback.`

const SQUARE = /^[a-h][1-8]$/
const PIECE = /^[A-Za-z ]{1,20}$/

secureServe('chess-tutor', async (req, ctx) => {
  const { user } = await requireUser(req)
  rateLimit(`chess-tutor:${user.id}`, 30, 60_000)

  const b = await ctx.readJson()
  const pieceName = asString(b.pieceName, 'pieceName', { max: 20, pattern: PIECE })
  const fromSquare = asString(b.fromSquare, 'fromSquare', { max: 2, pattern: SQUARE })
  const toSquare = asString(b.toSquare, 'toSquare', { max: 2, pattern: SQUARE })
  const capturedPiece = b.capturedPiece ? asString(b.capturedPiece, 'capturedPiece', { max: 20, pattern: PIECE }) : ''
  const moveNumber = asInt(b.moveNumber ?? 1, 'moveNumber', { min: 0, max: 1000 })
  const lessonFocus = b.lessonFocus ? asString(b.lessonFocus, 'lessonFocus', { max: 120, optional: true }) : ''
  const isHanging = b.isHanging === true
  const isCheck = b.isCheck === true

  const apiKey = requireEnv('GEMINI_API_KEY')

  const situationDetails = [
    `Move number: ${moveNumber}`,
    `Piece moved: ${pieceName}`,
    `From square ${fromSquare} to square ${toSquare}`,
    capturedPiece ? `This move captured a ${capturedPiece}` : `No capture happened`,
    isHanging ? `Warning: this piece is now undefended and could be captured next turn` : ``,
    isCheck ? `This move puts the opponent in check` : ``,
    lessonFocus ? `The student is currently learning about: ${wrapUntrusted('lesson', lessonFocus, 120)}. Tie your feedback to this lesson focus when relevant.` : ``,
  ].filter(Boolean).join('. ')

  const res = await fetchWithTimeout(
    'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent',
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'x-goog-api-key': apiKey },
      body: JSON.stringify({
        contents: [{ parts: [{ text: `${systemPrompt}\n\n${UNTRUSTED_NOTICE}\n\nSituation: ${situationDetails}\n\nExplain this move to the student now.` }] }],
        generationConfig: { maxOutputTokens: 80, temperature: 0.7 },
      }),
    },
    15_000,
  )
  if (!res.ok) {
    console.error('[chess-tutor] gemini status', res.status, redact((await res.text()).slice(0, 300)))
    throw new HttpError(502, 'The tutor is unavailable right now')
  }
  const data = await res.json()
  const explanation = String(data?.candidates?.[0]?.content?.parts?.[0]?.text ?? '').trim().slice(0, 400) || 'Good move — keep going!'
  return ctx.json({ explanation })
}, { maxBodyBytes: 2 * 1024 })
