import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response(null, { headers: corsHeaders })

  try {
    const { institution_id, login_email, login_code } = await req.json()

    const authHeader = req.headers.get('Authorization')
    if (!authHeader) throw new Error('No auth header')

    const userClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } }
    )

    const { data: { user } } = await userClient.auth.getUser()
    if (!user) throw new Error('Not authenticated')

    const { data: profile } = await userClient
      .from('profiles').select('role').eq('id', user.id).single()

    if (!profile || !['admin', 'super_admin'].includes(profile.role)) {
      throw new Error('Not authorized')
    }

    const adminClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    const { data: newUser, error: createError } = await adminClient.auth.admin.createUser({
      email: login_email,
      password: login_code,
      email_confirm: true,
      user_metadata: { institution_id, role: 'institution' }
    })

    if (createError) {
      if (createError.message.includes('already registered')) {
        const { data: list } = await adminClient.auth.admin.listUsers({ perPage: 1000 })
        const existing = list?.users.find((u: any) => u.email === login_email)
        if (existing) {
          await adminClient.auth.admin.updateUserById(existing.id, {
            password: login_code, email_confirm: true
          })
          await adminClient.from('profiles').upsert({
            id: existing.id,
            display_name: login_email.split('@')[0].replace(/\./g, ' '),
            role: 'institution',
            username: login_email.split('@')[0],
          })
          return new Response(JSON.stringify({ success: true }),
            { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
        }
      }
      throw createError
    }

    if (newUser?.user) {
      await adminClient.from('profiles').upsert({
        id: newUser.user.id,
        display_name: login_email.split('@')[0].replace(/\./g, ' '),
        role: 'institution',
        username: login_email.split('@')[0],
      })
    }

    return new Response(
      JSON.stringify({ success: true, user_id: newUser?.user?.id }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error: any) {
    console.error('create-institution-user error:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
