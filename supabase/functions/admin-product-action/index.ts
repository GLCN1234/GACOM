// Server-side admin product actions (update/delete), bypassing RLS
// entirely by design. Built specifically because direct client-side
// updates were being rejected by RLS despite every layer checking out
// correctly (valid token, correct user, confirmed admin role, correct
// matching policy) — an unexplained mismatch between how the REST API
// evaluates the policy and the direct SQL checks agreeing it should
// pass. Rather than keep guessing at policy tweaks, this verifies
// adminship itself (via the service role, which isn't subject to RLS
// either) and then performs the write directly — removing RLS from the
// equation for this specific privileged action entirely.
import { createClient } from 'jsr:@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) throw new Error('Missing Authorization header')

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

    // Verify the caller's identity from their own token first.
    const authClient = createClient(supabaseUrl, serviceRoleKey, {
      global: { headers: { Authorization: authHeader } },
    })
    const { data: userData, error: userError } = await authClient.auth.getUser()
    if (userError || !userData?.user) throw new Error('Invalid or expired session')
    const callerId = userData.user.id

    // Service-role client for everything from here — not subject to RLS.
    const admin = createClient(supabaseUrl, serviceRoleKey)

    const { data: profile, error: profileError } = await admin
      .from('profiles').select('role').eq('id', callerId).single()
    if (profileError || !profile) throw new Error('Could not verify caller profile')
    if (!['admin', 'super_admin'].includes(profile.role)) {
      return new Response(JSON.stringify({ success: false, error: 'Not authorized — admin role required' }),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }

    const { action, productId, updates } = await req.json()
    if (!productId) throw new Error('productId is required')

    if (action === 'delete') {
      const { error } = await admin.from('products').update({ is_active: false }).eq('id', productId)
      if (error) throw error
    } else if (action === 'update') {
      if (!updates || typeof updates !== 'object') throw new Error('updates object is required for action=update')
      const { error } = await admin.from('products').update(updates).eq('id', productId)
      if (error) throw error
    } else {
      throw new Error(`Unknown action: ${action}`)
    }

    return new Response(JSON.stringify({ success: true }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })

  } catch (error) {
    console.error('admin-product-action error:', error)
    return new Response(JSON.stringify({ success: false, error: (error as Error).message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
  }
})
