// Settles a finished Arena match: pays the winner (pot minus platform fee).
//
// Security model (this function moves real money):
//   - the caller must be signed in and be a PLAYER in the match (or an admin,
//     who may also settle a disputed match). Previously it had no
//     authentication at all, so anyone on the internet could pay anyone.
//   - the amounts are recomputed here from the match row and arena_settings;
//     the request body only names the match and the claimed winner
//   - double payout is prevented twice: a compare-and-swap on the match row
//     (status active -> completed happens BEFORE any money moves, and only one
//     concurrent request can win it) and an idempotency reference
//     ARENA_WIN_<match_id> on the wallet credit
//   - money moves through the same refund_arena_stake() RPC the duel settler
//     uses, with the service role, never by read-modify-write on a balance
//
// KNOWN LIMIT (see docs/APPSEC_AUDIT.md): the winner is still reported by a
// player's client. The real fix is a server-computed result or requiring both
// players to report the same winner. Until then a player can claim a win.
import { secureServe, requireUser, rateLimit, serviceClient, asString, asUuid, HttpError, ADMIN_ROLES, redact } from '../_shared/security.ts'

const MAX_FEE_PERCENT = 50

secureServe('arena-payout', async (req, ctx) => {
  const { user } = await requireUser(req)
  rateLimit(`payout:${user.id}`, 20, 60_000)

  const body = await ctx.readJson()
  const matchId = asString(body.match_id, 'match_id', { max: 64, pattern: /^[A-Za-z0-9_-]+$/ })
  const winnerId = asUuid(body.winner_id, 'winner_id')

  const svc = serviceClient() // authenticated above; every decision below is server side

  const { data: match, error: mErr } = await svc.from('arena_matches').select('*').eq('id', matchId).maybeSingle()
  if (mErr) throw mErr
  if (!match) throw new HttpError(404, 'Match not found')

  const isPlayer = user.id === match.creator_id || user.id === match.opponent_id
  let isAdmin = false
  if (!isPlayer) {
    const { data: prof } = await svc.from('profiles').select('role').eq('id', user.id).maybeSingle()
    isAdmin = ADMIN_ROLES.includes(String(prof?.role ?? ''))
    if (!isAdmin) throw new HttpError(403, 'Not authorised')
  }

  // Idempotency: already paid? Report the same result instead of paying again.
  const reference = `ARENA_WIN_${matchId}`
  if (match.status === 'completed') {
    if (match.winner_id === winnerId) {
      return ctx.json({ success: true, payout: match.winner_payout ?? 0, fee: match.platform_fee ?? 0, already: true })
    }
    throw new HttpError(409, 'Match already settled')
  }
  const settleable = match.status === 'active' || (isAdmin && match.status === 'disputed')
  if (!settleable) throw new HttpError(400, 'Match not active')

  if (!match.opponent_id) throw new HttpError(400, 'Match has no opponent')
  if (winnerId !== match.creator_id && winnerId !== match.opponent_id) {
    throw new HttpError(403, 'Winner must be a match player')
  }

  // Amounts are recomputed server side from the stored stake.
  const stake = Number(match.stake_amount ?? 0)
  if (!Number.isInteger(stake) || stake < 0) throw new HttpError(400, 'Invalid stake')
  const { data: settings } = await svc.from('arena_settings').select('platform_fee_percent').limit(1).maybeSingle()
  let feePercent = Number(settings?.platform_fee_percent ?? 15)
  if (!Number.isFinite(feePercent) || feePercent < 0 || feePercent > MAX_FEE_PERCENT) feePercent = 15
  const pot = stake * 2
  const fee = Math.round((pot * feePercent) / 100)
  const payout = pot - fee

  // 1. Claim the match. Only one concurrent caller can flip it out of its
  //    current status; everyone else gets zero rows and stops here.
  const { data: claimed, error: claimErr } = await svc.from('arena_matches')
    .update({
      status: 'completed',
      winner_id: winnerId,
      winner_payout: payout,
      platform_fee: fee,
      ended_at: new Date().toISOString(),
    })
    .eq('id', matchId)
    .eq('status', match.status)
    .select('id')
  if (claimErr) throw claimErr
  if (!claimed || claimed.length === 0) throw new HttpError(409, 'Match already settled')

  // 2. Pay. If this fails, put the match back so it can be retried, and never
  //    leave a "completed" match that was not paid.
  if (payout > 0) {
    const { data: res, error: payErr } = await svc.rpc('refund_arena_stake', {
      p_user_id: winnerId,
      p_amount: payout,
      p_reference: reference,
    })
    if (payErr || res?.success !== true) {
      console.error('[arena-payout] credit failed for match', matchId, redact(String(payErr?.message ?? res?.error ?? 'unknown')))
      await svc.from('arena_matches')
        .update({ status: match.status, winner_id: null, winner_payout: null, platform_fee: null, ended_at: null })
        .eq('id', matchId).eq('status', 'completed')
      throw new HttpError(502, 'Could not credit the winner. Nothing was charged; please retry.')
    }
  }

  return ctx.json({ success: true, payout, fee })
})
