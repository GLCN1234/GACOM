import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const usernames = [
  ['xXSniperKingXx', 'Sniper King', true], ['NijaGameQueen', 'Nija Game Queen', true],
  ['LagosGamer247', 'Lagos Gamer', false], ['AbujaAceGamer', 'Abuja Ace', false],
  ['ClutchQueenNG', 'Clutch Queen', true], ['HeadshotHarry', 'Headshot Harry', false],
  ['ProGamerPeter', 'Pro Gamer Peter', false], ['ChessM8Naija', 'Chess Mate Naija', true],
  ['FIFAKingLagos', 'FIFA King Lagos', true], ['ValorantVixen', 'Valorant Vixen', false],
  ['MobileLegendMike', 'Mobile Legend Mike', false], ['FreeFireFatima', 'Free Fire Fatima', true],
  ['CODMChampion', 'COD Mobile Champion', true], ['PUBGPrincess', 'PUBG Princess', false],
  ['StreetFighterSam', 'Street Fighter Sam', false], ['EsportsElite9', 'Esports Elite', true],
  ['RankPushRita', 'Rank Push Rita', false], ['TacticalTunde', 'Tactical Tunde', false],
  ['GGWPGamer', 'GGWP Gamer', false], ['NoobSlayerNaija', 'Noob Slayer Naija', false],
  ['ControllerKing', 'Controller King', true], ['MLBB_Maria', 'MLBB Maria', false],
  ['Genshin_Grace', 'Genshin Grace', false], ['ClashClanChief', 'Clash Clan Chief', true],
  ['LudoLegendLola', 'Ludo Legend Lola', false], ['CandyCrushCynthia', 'Candy Crush Cynthia', false],
  ['Asphalt9Andy', 'Asphalt Andy', false], ['EightBallBaba', 'Eight Ball Baba', false],
  ['SubwaySurferSuzy', 'Subway Surfer Suzy', false], ['TournamentTayo', 'Tournament Tayo', true],
  ['GamingGuruGina', 'Gaming Guru Gina', true], ['ProPlayerPaul', 'Pro Player Paul', false],
  ['EliteSquadEmma', 'Elite Squad Emma', false], ['VictoryRoyaleVince', 'Victory Royale Vince', false],
  ['HighScoreHassan', 'High Score Hassan', false], ['TopFraggerTola', 'Top Fragger Tola', true],
  ['ClutchPlayCynthia', 'Clutch Play Cynthia', false], ['RankedWarriorRita', 'Ranked Warrior Rita', false],
  ['MVPMichael', 'MVP Michael', true], ['LegendaryLade', 'Legendary Lade', false],
]

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }
  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )
    const created: { username: string, id: string }[] = []
    const errors: string[] = []

    for (const [username, displayName, verified] of usernames) {
      const email = `${username.toLowerCase()}@gacom-demo-seed.internal`
      const { data: userData, error: userError } = await supabase.auth.admin.createUser({
        email,
        password: crypto.randomUUID(),
        email_confirm: true,
      })
      if (userError || !userData.user) {
        errors.push(`${username}: ${userError?.message ?? 'unknown error'}`)
        continue
      }
      const { error: profileError } = await supabase.from('profiles').upsert({
        id: userData.user.id,
        username,
        display_name: displayName,
        verification_status: verified ? 'verified' : 'unverified',
      }, { onConflict: 'id' })
      if (profileError) {
        errors.push(`${username} (profile): ${profileError.message}`)
        continue
      }
      created.push({ username, id: userData.user.id })
    }

    return new Response(
      JSON.stringify({ created, errors, createdCount: created.length }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (err) {
    return new Response(
      JSON.stringify({ error: String(err) }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
