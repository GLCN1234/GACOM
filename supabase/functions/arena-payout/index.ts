import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors })

  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    const { match_id, winner_id } = await req.json()
    if (!match_id || !winner_id) {
      return new Response(JSON.stringify({ error: 'match_id and winner_id required' }), { status: 400, headers: { ...cors, 'Content-Type': 'application/json' } })
    }

    // 1. Fetch match — verify it's active and winner is a player
    const { data: match, error: mErr } = await supabase
      .from('arena_matches')
      .select('*')
      .eq('id', match_id)
      .single()

    if (mErr || !match) return new Response(JSON.stringify({ error: 'Match not found' }), { status: 404, headers: { ...cors, 'Content-Type': 'application/json' } })
    if (match.status !== 'active') return new Response(JSON.stringify({ error: 'Match not active' }), { status: 400, headers: { ...cors, 'Content-Type': 'application/json' } })
    if (winner_id !== match.creator_id && winner_id !== match.opponent_id) {
      return new Response(JSON.stringify({ error: 'Winner must be a match player' }), { status: 403, headers: { ...cors, 'Content-Type': 'application/json' } })
    }

    // 2. Get arena settings for fee %
    const { data: settings } = await supabase
      .from('arena_settings')
      .select('platform_fee_percent')
      .single()
    const feePercent = settings?.platform_fee_percent ?? 15
    const pot = match.stake_amount * 2
    const fee = Math.round(pot * feePercent / 100)
    const payout = pot - fee

    // 3. Credit winner wallet
    const { data: wallet, error: wErr } = await supabase
      .from('wallets')
      .select('balance')
      .eq('user_id', winner_id)
      .single()

    if (wErr || !wallet) return new Response(JSON.stringify({ error: 'Winner wallet not found' }), { status: 404, headers: { ...cors, 'Content-Type': 'application/json' } })

    await supabase.from('wallets').update({ balance: wallet.balance + payout }).eq('user_id', winner_id)

    // 4. Record transaction
    await supabase.from('wallet_transactions').insert({
      user_id: winner_id,
      type: 'arena_win',
      amount: payout,
      reference: `ARENA_WIN_${match_id}`,
      status: 'completed',
      description: `Arena win — ${match.game_type} match`,
    })

    // 5. Mark match completed
    await supabase.from('arena_matches').update({
      status: 'completed',
      winner_id,
      winner_payout: payout,
      platform_fee: fee,
      ended_at: new Date().toISOString(),
    }).eq('id', match_id)

    return new Response(JSON.stringify({ success: true, payout, fee }), { status: 200, headers: { ...cors, 'Content-Type': 'application/json' } })
  } catch (err) {
    return new Response(JSON.stringify({ error: String(err) }), { status: 500, headers: { ...cors, 'Content-Type': 'application/json' } })
  }
})
