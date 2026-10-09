// DEV/DEMO ONLY. Creates ~40 fake auth users. Refused unless
// ALLOW_SEED_FUNCTIONS=true AND the caller is an admin or presents the
// x-seed-secret header (SEED_SECRET). Leave ALLOW_SEED_FUNCTIONS unset in
// production.
import { secureServe, requireSeedAccess, serviceClient, redact } from '../_shared/security.ts'

const usernames: [string, string, boolean][] = [
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

secureServe('seed-demo-authors', async (req, ctx) => {
  await requireSeedAccess(req)
  const supabase = serviceClient()
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
      errors.push(`${username}: ${redact(String(userError?.message ?? 'unknown error')).slice(0, 120)}`)
      continue
    }
    const { error: profileError } = await supabase.from('profiles').upsert({
      id: userData.user.id,
      username,
      display_name: displayName,
      verification_status: verified ? 'verified' : 'unverified',
    }, { onConflict: 'id' })
    if (profileError) {
      errors.push(`${username} (profile): ${redact(String(profileError.message)).slice(0, 120)}`)
      continue
    }
    created.push({ username, id: userData.user.id })
  }
  return ctx.json({ created, errors, createdCount: created.length })
}, { maxBodyBytes: 1024, ipRateLimit: { limit: 5, windowMs: 60_000 } })
