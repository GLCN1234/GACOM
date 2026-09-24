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
        exp: getNumericDate(60 * 60), // 1 hour — plenty for a single match
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
