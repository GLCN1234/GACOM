// Generates a real, signed LiveKit access token so a player can join
// the voice room for their match. Verified against LiveKit's own
// documented token structure — a JWT (HS256, signed with the API
// secret) carrying identity, room name, and publish/subscribe grants.
// Room name is always the match ID, so both players in a match land in
// the same room automatically.
import { createClient } from 'jsr:@supabase/supabase-js@2'
import { create, getNumericDate } from 'jsr:@zaubrik/djwt'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) throw new Error('Missing Authorization header')

    const apiKey = Deno.env.get('LIVEKIT_API_KEY')
    const apiSecret = Deno.env.get('LIVEKIT_API_SECRET')
    if (!apiKey || !apiSecret) throw new Error('LIVEKIT_API_KEY / LIVEKIT_API_SECRET not configured')

    // Verify the caller's real identity from their own session — the
    // token issued is always for THEM, never a spoofed identity.
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
      { global: { headers: { Authorization: authHeader } } },
    )
    const { data: userData, error: userError } = await supabase.auth.getUser()
    if (userError || !userData?.user) throw new Error('Invalid or expired session')
    const identity = userData.user.id

    const { roomName } = await req.json()
    if (!roomName) throw new Error('roomName is required')

    if (typeof roomName !== 'string' || roomName.length > 120) throw new Error('Invalid roomName')

    // Darkom City rooms: check who may join. The checks use a separate
    // service-role client (no user header), so they are not limited by RLS.
    const isDarkom = roomName.startsWith('darkom-')
    if (isDarkom) {
      const admin = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!)
      const uuidRe = /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/
      if (roomName.startsWith('darkom-house-')) {
        const houseId = roomName.slice('darkom-house-'.length)
        if (!uuidRe.test(houseId)) throw new Error('Invalid room')
        const { data, error } = await admin.from('house_members').select('user_id')
          .eq('house_id', houseId).eq('user_id', identity).maybeSingle()
        if (error || !data) throw new Error('Only members of this house can join its voice room')
      } else if (roomName.startsWith('darkom-squad-')) {
        const squadId = roomName.slice('darkom-squad-'.length)
        if (!uuidRe.test(squadId)) throw new Error('Invalid room')
        const { data, error } = await admin.from('darkom_squad_members').select('user_id')
          .eq('squad_id', squadId).eq('user_id', identity).maybeSingle()
        if (error || !data) throw new Error('Only squad members can join this voice room')
      } else if (roomName.startsWith('darkom-hub-')) {
        if (!/^[0-9]{1,6}$/.test(roomName.slice('darkom-hub-'.length))) throw new Error('Invalid room')
        // any signed-in user may join a hub room
      } else {
        throw new Error('Unknown room')
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
        exp: getNumericDate(isDarkom ? 2 * 60 * 60 : 60 * 60), // 1 hour for a match, 2 hours for Darkom rooms
        video: {
          room: roomName,
          roomJoin: true,
          canPublish: true,
          canSubscribe: true,
        },
      },
      key,
    )

    return new Response(JSON.stringify({ success: true, token: jwt }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })

  } catch (error) {
    console.error('livekit-token error:', error)
    return new Response(JSON.stringify({ success: false, error: (error as Error).message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
  }
})
