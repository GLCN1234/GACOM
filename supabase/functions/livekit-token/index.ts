// Generates a signed LiveKit access token so a player can join the voice room
// for their match. HS256 JWT signed with the API secret, carrying identity,
// room name and publish/subscribe grants.
//
// Security notes:
//   - identity is the verified JWT user, never the body
//   - match rooms: the caller must be a player in that match (previously any
//     signed-in user could join any match room and eavesdrop)
//   - Darkom rooms: house / squad membership checked with the service role
//   - generic errors; secrets only from env
import { create, getNumericDate } from 'jsr:@zaubrik/djwt'
import { secureServe, requireUser, requireEnv, serviceClient, rateLimit, isUuid, HttpError } from '../_shared/security.ts'

secureServe('livekit-token', async (req, ctx) => {
  const { user } = await requireUser(req)
  rateLimit(`livekit:${user.id}`, 30, 60_000)
  const identity = user.id

  const apiKey = requireEnv('LIVEKIT_API_KEY')
  const apiSecret = requireEnv('LIVEKIT_API_SECRET')

  const body = await ctx.readJson()
  const roomName = body.roomName
  if (typeof roomName !== 'string' || !/^[A-Za-z0-9_-]{1,120}$/.test(roomName)) throw new HttpError(400, 'Invalid roomName')

  const admin = serviceClient() // caller authenticated above
  const isDarkom = roomName.startsWith('darkom-')
  if (isDarkom) {
    if (roomName.startsWith('darkom-house-')) {
      const houseId = roomName.slice('darkom-house-'.length)
      if (!isUuid(houseId)) throw new HttpError(400, 'Invalid room')
      const { data } = await admin.from('house_members').select('user_id').eq('house_id', houseId).eq('user_id', identity).maybeSingle()
      if (!data) throw new HttpError(403, 'Only members of this house can join its voice room')
    } else if (roomName.startsWith('darkom-squad-')) {
      const squadId = roomName.slice('darkom-squad-'.length)
      if (!isUuid(squadId)) throw new HttpError(400, 'Invalid room')
      const { data } = await admin.from('darkom_squad_members').select('user_id').eq('squad_id', squadId).eq('user_id', identity).maybeSingle()
      if (!data) throw new HttpError(403, 'Only squad members can join this voice room')
    } else if (roomName.startsWith('darkom-hub-')) {
      if (!/^[0-9]{1,6}$/.test(roomName.slice('darkom-hub-'.length))) throw new HttpError(400, 'Invalid room')
      // any signed-in user may join a hub room
    } else {
      throw new HttpError(400, 'Unknown room')
    }
  } else {
    // Match room: the room name is the arena match id.
    // (the client joins `voice_channel` when set, otherwise the match id)
    const { data: rows } = await admin.from('arena_matches').select('creator_id, opponent_id')
      .or(`id.eq.${roomName},voice_channel.eq.${roomName}`).limit(1)
    const match = rows?.[0]
    if (!match || (match.creator_id !== identity && match.opponent_id !== identity)) {
      throw new HttpError(403, 'Only players in this match can join its voice room')
    }
  }

  const key = await crypto.subtle.importKey(
    'raw', new TextEncoder().encode(apiSecret),
    { name: 'HMAC', hash: 'SHA-256' }, false, ['sign', 'verify'],
  )
  const jwt = await create(
    { alg: 'HS256', typ: 'JWT' },
    {
      iss: apiKey,
      sub: identity,
      nbf: getNumericDate(0),
      exp: getNumericDate(isDarkom ? 2 * 60 * 60 : 60 * 60),
      video: { room: roomName, roomJoin: true, canPublish: true, canSubscribe: true },
    },
    key,
  )
  return ctx.json({ success: true, token: jwt })
}, { maxBodyBytes: 2 * 1024 })
