import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { reference } = await req.json()
    if (!reference) {
      return new Response(
        JSON.stringify({ success: false, error: 'reference is required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const secretKey = Deno.env.get('PAYSTACK_SECRET_KEY')
    if (!secretKey) {
      return new Response(
        JSON.stringify({ success: false, error: 'Paystack secret key not configured' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Ask Paystack directly whether this transaction actually succeeded —
    // never trust the client's claim that payment went through.
    const verifyRes = await fetch(
      `https://api.paystack.co/transaction/verify/${encodeURIComponent(reference)}`,
      { headers: { 'Authorization': `Bearer ${secretKey}` } }
    )
    const verifyData = await verifyRes.json()

    if (!verifyData.status || verifyData.data?.status !== 'success') {
      return new Response(
        JSON.stringify({ success: false, error: verifyData.data?.gateway_response ?? 'Payment not successful' }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Paystack's own confirmed amount (kobo) is the only amount we trust.
    const amountNaira = verifyData.data.amount / 100

    // Service role client — bypasses RLS, needed to credit another user's
    // wallet_balance row from a server context.
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    // Edu Gaming subscription payments use a distinct reference prefix and
    // activate a subscription row instead of crediting the wallet.
    if (reference.startsWith('EDU_')) {
      const { data: subRow, error: subFetchError } = await supabase
        .from('edu_subscriptions')
        .select('id, amount')
        .eq('reference', reference)
        .maybeSingle()
      if (subFetchError || !subRow) {
        return new Response(
          JSON.stringify({ success: false, error: 'Subscription record not found for this reference' }),
          { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }
      const expectedNaira = (subRow.amount ?? 0) / 100
      if (Math.abs(amountNaira - expectedNaira) > 0.01) {
        return new Response(
          JSON.stringify({ success: false, error: 'Amount mismatch' }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }
      const expiresAt = new Date()
      expiresAt.setMonth(expiresAt.getMonth() + 1)
      const { error: updateError } = await supabase
        .from('edu_subscriptions')
        .update({ status: 'active', expires_at: expiresAt.toISOString() })
        .eq('reference', reference)
      if (updateError) {
        return new Response(
          JSON.stringify({ success: false, error: updateError.message }),
          { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }
      return new Response(
        JSON.stringify({ success: true, subscription: 'active' }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const { data, error } = await supabase.rpc('credit_wallet_from_reference', {
      p_reference: reference,
      p_amount: amountNaira,
    })

    if (error) {
      return new Response(
        JSON.stringify({ success: false, error: error.message }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    return new Response(
      JSON.stringify(data),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (err) {
    return new Response(
      JSON.stringify({ success: false, error: String(err) }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})