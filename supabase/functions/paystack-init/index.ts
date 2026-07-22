import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { email, amount, reference, callback_url } = await req.json()

    if (!email || !amount || !reference) {
      return new Response(
        JSON.stringify({ error: 'email, amount and reference are required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Identify the calling user from their auth token — never trust a
    // client-supplied user_id, derive it from the verified session instead.
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: 'Missing authorization' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }
    const anonClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } }
    )
    const { data: userData, error: userError } = await anonClient.auth.getUser()
    if (userError || !userData?.user) {
      return new Response(
        JSON.stringify({ error: 'Could not identify user from session' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }
    const userId = userData.user.id

    // Secret key is stored as a Supabase secret — never exposed to frontend
    const secretKey = Deno.env.get('PAYSTACK_SECRET_KEY')
    if (!secretKey) {
      return new Response(
        JSON.stringify({ error: 'Paystack secret key not configured' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Call Paystack Initialize Transaction API
    const paystackRes = await fetch('https://api.paystack.co/transaction/initialize', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${secretKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        email,
        amount: Math.round(amount), // amount in kobo, must be integer
        reference,
        callback_url: callback_url ?? 'https://gamicom.net/#/store',
        channels: ['card', 'bank', 'ussd', 'qr', 'mobile_money', 'bank_transfer'],
      }),
    })

    const data = await paystackRes.json()

    if (!data.status) {
      return new Response(
        JSON.stringify({ error: data.message ?? 'Paystack initialization failed' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Record the pending transaction HERE, server-side, before returning
    // the checkout link. This guarantees the record exists no matter what
    // the browser does next (new tab, popup, full navigation) — it no
    // longer depends on any client-side code running after this point.
    const serviceClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    // wallet_transactions requires balance_before/balance_after on every
    // row. For a still-pending deposit nothing has moved yet, so both
    // equal the current balance — credit_wallet_from_reference updates
    // balance_after to the real post-credit figure once payment clears.
    const { data: profileData, error: profileError } = await serviceClient
      .from('profiles')
      .select('wallet_balance')
      .eq('id', userId)
      .single()
    if (profileError || profileData == null) {
      return new Response(
        JSON.stringify({ error: `Could not read wallet balance: ${profileError?.message ?? 'profile not found'}` }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }
    const currentBalance = profileData.wallet_balance ?? 0

    const { error: insertError } = await serviceClient.from('wallet_transactions').insert({
      user_id: userId,
      type: 'deposit',
      amount: amount / 100, // amount arrived in kobo; store naira to match the rest of the app
      balance_before: currentBalance,
      balance_after: currentBalance,
      reference,
      status: 'pending',
      description: 'Wallet funding via Paystack',
    })
    if (insertError) {
      // Don't send the user to pay for a transaction we can't track —
      // fail loudly here rather than silently losing the record.
      return new Response(
        JSON.stringify({ error: `Could not record pending transaction: ${insertError.message}` }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Return the authorization_url to the Flutter app
    return new Response(
      JSON.stringify({
        authorization_url: data.data.authorization_url,
        access_code: data.data.access_code,
        reference: data.data.reference,
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (err) {
    return new Response(
      JSON.stringify({ error: String(err) }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})