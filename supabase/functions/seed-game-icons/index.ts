// One-time (safely re-runnable) seeder: finds a real, appropriately-
// licensed image for every game_listings row that has no icon_url yet,
// using the same Unsplash integration already set up for blog images
// (free, CC0, hotlinking is what they want used for it — not a
// workaround). Skips rows that already have an icon, so running this
// again after adding new games only fills in the new ones.
import { createClient } from 'jsr:@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}
const UNSPLASH_SEARCH_ENDPOINT = 'https://api.unsplash.com/search/photos'

async function fetchUnsplashImage(accessKey: string, query: string): Promise<string | null> {
  try {
    const url = `${UNSPLASH_SEARCH_ENDPOINT}?query=${encodeURIComponent(query)}&per_page=1&orientation=squarish`
    const res = await fetch(url, { headers: { 'Authorization': `Client-ID ${accessKey}` } })
    if (!res.ok) return null
    const data = await res.json()
    const photo = data?.results?.[0]
    if (!photo) return null
    if (photo.links?.download_location) {
      fetch(photo.links.download_location, { headers: { 'Authorization': `Client-ID ${accessKey}` } }).catch(() => {})
    }
    return photo.urls?.small ?? photo.urls?.regular ?? null
  } catch {
    return null
  }
}

// Game-specific search terms — more accurate than just using the raw
// game name, since e.g. "2048" alone returns unrelated stock photos.
const ICON_QUERIES: Record<string, string> = {
  'Chess': 'chess board pieces',
  'Tic-Tac-Toe': 'tic tac toe grid',
  'RPS Battle': 'rock paper scissors',
  'Trivia': 'quiz question marks',
  'Reaction': 'lightning speed reflex',
  'Connect Four': 'connect four game',
  'Reversi': 'othello board game',
  'Memory Match': 'matching cards game',
  'Word Scramble': 'scrabble letter tiles',
  '2048': 'number puzzle tiles',
  'Hangman': 'word guessing game',
  'Speed Math': 'math numbers calculator',
  'Simon Says': 'colorful game buttons',
  'Minesweeper': 'grid puzzle squares',
  'Blackjack': 'playing cards casino',
  'Dots & Boxes': 'dots grid puzzle',
  'Number Duel': 'numbers competition',
  'Snake': 'retro arcade game',
  'Survival Shooter': 'space shooter arcade',
  'Whot': 'playing cards deck colorful',
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  )

  try {
    const unsplashKey = Deno.env.get('UNSPLASH_ACCESS_KEY')
    if (!unsplashKey) throw new Error('UNSPLASH_ACCESS_KEY not configured')

    const { data: rows, error } = await supabase.from('game_listings')
      .select('id, name, category')
      .or('icon_url.is.null,icon_url.eq.')
    if (error) throw error

    let updated = 0
    const results: { name: string; found: boolean }[] = []
    for (const row of rows ?? []) {
      const query = ICON_QUERIES[row.name] ?? `${row.name} ${row.category} game`
      const iconUrl = await fetchUnsplashImage(unsplashKey, query)
      if (iconUrl) {
        await supabase.from('game_listings').update({ icon_url: iconUrl }).eq('id', row.id)
        updated++
      }
      results.push({ name: row.name, found: !!iconUrl })
      // Unsplash free tier: 50 requests/hour — small pause keeps this
      // well within that even for a larger future list.
      await new Promise((r) => setTimeout(r, 300))
    }

    return new Response(JSON.stringify({ success: true, updated, total: (rows ?? []).length, results }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })

  } catch (error) {
    console.error('seed-game-icons error:', error)
    return new Response(JSON.stringify({ success: false, error: (error as Error).message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
  }
})
