import '../../shared/widgets/landscape_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/edu_prefs.dart' as edu_prefs;
import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/onboarding_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/screens/reset_password_screen.dart';
import '../../features/auth/screens/auth_confirm_screen.dart';
import '../../features/home/screens/main_shell.dart';
import '../../features/feed/screens/feed_screen.dart';
import '../../features/feed/screens/create_post_screen.dart';
import '../../features/feed/screens/reels_screen.dart';
import '../../features/competitions/screens/competitions_screen.dart';
import '../../features/competitions/screens/competition_detail_screen.dart';
import '../../features/competitions/screens/tournament_manager_screen.dart';
import '../../features/community/screens/community_screen.dart';
import '../../features/community/screens/community_detail_screen.dart';
import '../../features/community/screens/gaming_teams_screen.dart';
import '../../features/chat/screens/chat_list_screen.dart';
import '../../features/chat/screens/chat_detail_screen.dart';
import '../../features/store/screens/store_screen.dart';
import '../../features/store/screens/product_detail_screen.dart';
import '../../features/store/screens/cart_screen.dart'; // ✅ NEW
import '../../features/wallet/screens/wallet_screen.dart';
import '../../features/blog/screens/blog_screen.dart';
import '../../features/blog/screens/blog_detail_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/profile/screens/settings_screen.dart';
import '../../features/profile/screens/customization_screen.dart';
import '../../features/profile/screens/locker_screen.dart';
import '../../features/missions/missions_screen.dart';
import '../../features/journey/journey_worlds_screen.dart';
import '../../features/journey/journey_map_screen.dart';
import '../../features/admin/screens/mission_admin_screen.dart';
import '../../features/houses/houses_screen.dart';
import '../../features/houses/house_chat_screen.dart';
import '../../features/houses/house_detail_screen.dart';
import '../../features/houses/house_manage_screen.dart';
import '../../features/admin/screens/admin_dashboard_screen.dart';
import '../../features/admin/screens/error_logs_screen.dart';
import '../../features/admin/screens/store_admin_screen.dart';
import '../../features/home/screens/notifications_screen.dart';
import '../../features/home/screens/search_screen.dart';
import '../../features/ads/screens/ads_screen.dart';
import '../../features/admin/screens/security_center_screen.dart';
import '../../features/support/desk/support_admin_screen.dart';
import '../../features/support/desk/support_desk_screen.dart';
import '../../features/support/desk/support_desk_ticket_screen.dart';
import '../../features/support/screens/my_tickets_screen.dart';
import '../../features/support/support_service.dart';
import '../../features/support/screens/support_chat_screen.dart';
import '../../features/support/screens/agent_chat_screen.dart';
import '../../features/exco/screens/exco_dashboard_screen.dart';
import '../../features/arena/screens/arena_screen.dart';
import '../../features/arena/screens/match_screen.dart';
import '../../features/arena/screens/duel_lobby_screen.dart';
import '../../features/arena/screens/duel_screen.dart';
import '../../features/edu/quests/quest_hub_screen.dart';
import '../../features/edu/odyssey/odyssey_hub_screen.dart';
import '../../features/edu/edu_more_games_screen.dart';
import '../../shared/tutorial/how_to_gate.dart';
import '../../shared/widgets/pc_controls_gate.dart';
import '../../features/darkom/arena/darkom_arena_args.dart';
import '../../features/darkom/arena/darkom_arena_screen.dart';
import '../../features/character3d/character_studio_screen.dart';
import '../../features/darkom/darkom_screen.dart';
import '../../features/darkom/hub/darkom_hub_screen.dart';
import '../../features/edu/realms/realm_hub_screen.dart';
import '../../features/edu/realms/realm_kit.dart';
import '../../features/edu/realms/realm_registry.dart';
import '../../features/arena/screens/games/vault_break_screen.dart';
import '../../features/edu/odyssey/odyssey_screen.dart';
import '../../features/arena/duels/duel_entry.dart';
import '../../features/edu/quests/quest_play_screen.dart';
import '../../features/arena/screens/games/tictactoe_practice_screen.dart';
import '../../features/arena/screens/games/chess_game.dart';
import '../../features/arena/screens/games/extra_games.dart';
import '../../features/arena/screens/games/whot_game.dart';
import '../../features/arena/screens/games/rps_solo.dart';
import '../../features/arena/screens/games/trivia_solo.dart';
import '../../features/arena/screens/games/colony_siege_game.dart';
import '../../features/arena/screens/games/endless_runner_screen.dart';
import '../../features/arena/screens/games/drone_breach_screen.dart';
import '../../features/arena/screens/games/signal_match_screen.dart';
import '../../features/arena/screens/games/arena_gauntlet_game.dart';
import '../../features/arena/screens/games/astra_colony_screen.dart';
import '../../features/arena/screens/games/spatial_quiz_screen.dart';
import '../../features/arena/screens/games/reaction_solo.dart';
import '../../features/arena/screens/games/algebra_game.dart';
import '../../features/arena/screens/games/physics_game.dart';
import '../../features/edu/edu_home_screen.dart';
import '../../features/edu/edu_subject_screen.dart';
import '../../features/edu/edu_subjects_screen.dart';
import '../../features/edu/edu_profile_screen.dart';
import '../../features/edu/edu_parent_screen.dart';
import '../../features/edu/edu_chat_screen.dart';
import '../../features/edu/edu_paywall_screen.dart';
import '../../features/edu/edu_compete_screen.dart';
import '../../features/edu/edu_compete_lobby_screen.dart';
import '../../features/edu/institution/institution_picker_screen.dart';
import '../../features/edu/institution/institution_portal_screen.dart';
import '../../features/edu/institution/curriculum_game_picker_screen.dart';
import '../../features/arena/screens/game_store_screen.dart';
import '../../features/arena/screens/leaderboard_screen.dart';
import '../../features/arena/screens/game_detail_screen.dart';
import '../../features/arena/screens/game_developer_application_screen.dart';
import '../../features/arena/games/shooter/survival_shooter_screen.dart';
import '../../features/arena/screens/games/ludo_screen.dart';
import '../../features/arena/screens/games/ayo_screen.dart';
import '../../features/arena/screens/games/checkers_screen.dart';
import '../../features/arena/screens/games/battleship_screen.dart';
import '../../features/arena/screens/games/rummy_screen.dart';
import '../../features/arena/screens/games/solitaire_screen.dart';
import '../../features/arena/screens/games/puzzle_rush_screen.dart';
import '../../features/arena/screens/games/sudoku_screen.dart';
import '../../features/arena/screens/games/block_drop_screen.dart';
import '../../features/arena/screens/games/color_clash_screen.dart';
import '../../features/arena/screens/games/bubble_shooter_screen.dart';
import '../../features/arena/screens/games/stack_tower_screen.dart';
import '../../features/arena/screens/games/sky_hopper_screen.dart';
import '../../features/arena/screens/games/dash_runner_screen.dart';
import '../../features/arena/screens/games/star_blaster_screen.dart';
import '../../features/arena/screens/games/target_gallery_screen.dart';
import '../../features/arena/screens/games/fruit_slice_screen.dart';
import '../../features/arena/screens/games/basketball_screen.dart';
import '../../features/arena/screens/games/darts_screen.dart';
import '../../features/arena/screens/games/air_hockey_screen.dart';
import '../../features/arena/screens/games/pool_screen.dart';
import '../../features/arena/screens/games/pinball_screen.dart';
import '../../features/arena/screens/games/tower_defense_screen.dart';
import '../../features/arena/screens/games/mini_crossword_screen.dart';
import '../../features/arena/screens/games/jigsaw_screen.dart';
import '../../features/arena/games/void_protocols/void_protocols_screen.dart';
import '../../features/arena/games/chrono_spire/chrono_spire_screen.dart';

/// Server-checked role for route guards. The role is read from the `profiles`
/// table (never from client-editable auth user_metadata) and cached per user id.
/// This only hides admin screens from non-admins; the real enforcement is RLS
/// and the role checks inside the edge functions.
class _RoleGuard {
  static String? _uid;
  static String? _role;

  static Future<String> role() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return '';
    if (_uid == user.id && _role != null) return _role!;
    try {
      final row = await Supabase.instance.client
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();
      _uid = user.id;
      _role = (row?['role'] as String?) ?? 'user';
      return _role!;
    } catch (_) {
      return ''; // fail closed; the next navigation retries
    }
  }

  static void clear() {
    _uid = null;
    _role = null;
  }

  static bool isAdminLocation(String loc) => loc == '/admin' || loc.startsWith('/admin/');
}

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: AppConstants.splashRoute,
    redirect: (context, state) async {
      final session = Supabase.instance.client.auth.currentSession;
      final isLoggedIn = session != null;
      final loc = state.matchedLocation;
      // Admin area: needs an admin/super_admin role loaded from the server.
      // (/admin/support is the staff desk, which also admits support staff;
      // the server still decides what data they can see.)
      if (isLoggedIn && _RoleGuard.isAdminLocation(loc)) {
        final role = await _RoleGuard.role();
        final isStaffDesk = loc == '/admin/support' || loc.startsWith('/admin/support/');
        final adminOnly = loc == '/admin/security' || loc.startsWith('/admin/security/') || isStaffDesk;
        final allowed = role == 'admin' ||
            role == 'super_admin' ||
            (!adminOnly && role == 'moderator') ||
            (isStaffDesk && (role == 'support' || role == 'support_agent' || role == 'moderator' || role == 'exco'));
        if (!allowed) return AppConstants.homeRoute;
      }
      if (isLoggedIn && loc == '/exco-dashboard') {
        final role = await _RoleGuard.role();
        if (role != 'admin' && role != 'super_admin' && role != 'moderator' && role != 'exco') return AppConstants.homeRoute;
      }
      if (loc == '/reset-password' || loc == '/auth/confirm') return null;
      final isAuthRoute = loc == AppConstants.loginRoute ||
          loc == AppConstants.registerRoute ||
          loc == AppConstants.onboardingRoute ||
          loc == AppConstants.splashRoute;
      if (!isLoggedIn && !isAuthRoute) return AppConstants.loginRoute;
      // Restore edu mode — if user had edu mode on when they last closed
      // the browser, redirect them back to edu home after login.
      if (isLoggedIn && loc == AppConstants.homeRoute) {
        if (edu_prefs.getEduMode()) return '/edu/home';
        // Institution users always land on their portal
        try {
          final profile = Supabase.instance.client.auth.currentUser?.userMetadata;
          if (profile?['role'] == 'institution') return '/edu/portal';
        } catch (_) {}
      }
      return null;
    },
    routes: [
      GoRoute(path: AppConstants.splashRoute, builder: (_, __) => const SplashScreen()),
      GoRoute(path: AppConstants.onboardingRoute, builder: (_, __) => const OnboardingScreen()),
      GoRoute(path: AppConstants.loginRoute, builder: (_, __) => const LoginScreen()),
      GoRoute(path: AppConstants.registerRoute, builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/reset-password', builder: (_, __) => const ResetPasswordScreen()),
      GoRoute(path: '/auth/confirm', builder: (_, s) => AuthConfirmScreen(tokenHash: s.uri.queryParameters['token_hash'], type: s.uri.queryParameters['type'])),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: AppConstants.homeRoute, builder: (_, __) => const FeedScreen()),
          GoRoute(path: AppConstants.feedRoute, builder: (_, __) => const FeedScreen()),
          GoRoute(
            path: AppConstants.competitionsRoute,
            builder: (_, __) => const CompetitionsScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, s) => CompetitionDetailScreen(
                    competitionId: s.pathParameters['id']!),
                routes: [
                  GoRoute(
                    path: 'manage',
                    builder: (_, s) => TournamentManagerScreen(
                      competitionId: s.pathParameters['id']!,
                      isAdmin: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: AppConstants.communityRoute,
            builder: (_, __) => const CommunityScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, s) =>
                    CommunityDetailScreen(communityId: s.pathParameters['id']!),
                routes: [
                  GoRoute(
                    path: 'teams',
                    builder: (_, s) => GamingTeamsScreen(
                      communityId: s.pathParameters['id']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: AppConstants.chatRoute,
            builder: (_, __) => const ChatListScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, s) =>
                    ChatDetailScreen(chatId: s.pathParameters['id']!),
              ),
            ],
          ),
          GoRoute(
            path: AppConstants.storeRoute,
            builder: (_, __) => const StoreScreen(),
            routes: [
              // ✅ Cart page — registered BEFORE product/:id so it matches first
              GoRoute(
                path: 'cart',
                builder: (_, __) => const CartScreen(),
              ),
              GoRoute(
                path: 'product/:id',
                builder: (_, s) =>
                    ProductDetailScreen(productId: s.pathParameters['id']!),
              ),
            ],
          ),
          GoRoute(path: AppConstants.walletRoute, builder: (_, __) => const WalletScreen()),
          GoRoute(
            path: AppConstants.blogRoute,
            builder: (_, __) => const BlogScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, s) =>
                    BlogDetailScreen(blogId: s.pathParameters['id']!),
              ),
            ],
          ),
          GoRoute(
            path: '/profile/:id',
            builder: (_, s) => ProfileScreen(userId: s.pathParameters['id']!),
          ),
          GoRoute(path: AppConstants.settingsRoute, builder: (_, __) => const SettingsScreen()),
          GoRoute(path: AppConstants.notificationsRoute, builder: (_, __) => const NotificationsScreen()),
          GoRoute(path: AppConstants.searchRoute, builder: (_, __) => const SearchScreen()),
          GoRoute(path: AppConstants.createPostRoute, builder: (_, __) => const CreatePostScreen()),
          GoRoute(path: AppConstants.adsRoute, builder: (_, __) => const AdsScreen()),
          GoRoute(path: AppConstants.supportRoute, builder: (_, __) => const SupportChatScreen()),
          GoRoute(path: AppConstants.agentChatRoute, builder: (_, __) => const AgentChatScreen()),
          GoRoute(path: '/support/tickets', builder: (_, __) => const MyTicketsScreen()),
          GoRoute(path: '/support/ticket/:id', builder: (_, s) => TicketScreen(ticketId: s.pathParameters['id']!)),
          GoRoute(path: '/support/desk', builder: (_, __) => const SupportDeskScreen()),
          GoRoute(path: '/support/desk/ticket/:id', builder: (_, s) => SupportDeskTicketScreen(ticketId: s.pathParameters['id']!, initial: s.extra is SupportTicket ? s.extra as SupportTicket : null)),
          GoRoute(path: '/reels', builder: (_, __) => const ReelsScreen()),
          GoRoute(path: '/exco-dashboard', builder: (_, __) => const ExcoDashboardScreen()),
          // ── Edu Gaming routes ──────────────────────────────────────────
          GoRoute(path: '/edu/home',     builder: (_, __) => const EduHomeScreen()),
          GoRoute(path: '/edu/setup',    builder: (_, __) => const InstitutionPickerScreen()),
          GoRoute(path: '/edu/portal',   builder: (_, __) => const InstitutionPortalScreen()),
          GoRoute(path: '/edu/subjects', builder: (_, __) => const EduSubjectsScreen()),
          GoRoute(path: '/edu/profile',  builder: (_, __) => const EduProfileScreen()),
          GoRoute(path: '/edu/parent',   builder: (_, __) => const EduParentScreen()),
          GoRoute(path: '/edu/chat',     builder: (_, __) => const EduChatScreen()),
          GoRoute(path: '/edu/compete',  builder: (_, __) => const EduCompeteLobbyScreen()),
          GoRoute(path: '/edu/quests',   builder: (_, __) => const QuestHubScreen()),
          GoRoute(path: '/edu/quest',    builder: (_, __) => const QuestHubScreen()),
          GoRoute(path: '/edu/realms', builder: (_, s) => RealmHubScreen(initialSubject: s.uri.queryParameters['subject'])),
          GoRoute(path: '/edu/realm/:id', builder: (_, s) {
            final RealmGameInfo? info = RealmRegistry.byId(s.pathParameters['id']!);
            if (info == null) return const RealmHubScreen();
            final RealmConfig cfg = s.extra is RealmConfig ? s.extra as RealmConfig : const RealmConfig();
            return DuelEntry(gameKey: info.id, child: LandscapeScope(child: info.build(cfg)));
          }),
          GoRoute(path: '/character', builder: (_, __) => const CharacterStudioScreen()),
          GoRoute(path: '/darkom/hub', builder: (_, __) => HowToGate(gameKey: 'darkomhub', child: const LandscapeScope(child: DarkomHubScreen()))),
          GoRoute(path: '/darkom/arena', builder: (_, s) => s.extra is DarkomArenaArgs ? LandscapeScope(child: DarkomArenaScreen(args: s.extra as DarkomArenaArgs)) : const LandscapeScope(child: DarkomHubScreen())),
          GoRoute(path: '/darkom', builder: (_, __) => HowToGate(gameKey: 'darkom', child: PcControlsGate(gameKey: 'darkom', child: const LandscapeScope(child: DarkomScreen())))),
          GoRoute(path: '/edu/more-games', builder: (_, __) => const EduMoreGamesScreen()),
          GoRoute(path: '/edu/odyssey',  builder: (_, __) => const OdysseyHubScreen()),
          GoRoute(path: '/edu/odyssey/play', builder: (_, s) => HowToGate(gameKey: 'odyssey', child: PcControlsGate(gameKey: 'odyssey', child: LandscapeScope(child: OdysseyScreen(config: s.extra is OdysseyConfig ? s.extra as OdysseyConfig : const OdysseyConfig()))))),
          GoRoute(path: '/edu/quest/:id', builder: (_, s) => QuestPlayScreen(questId: s.pathParameters['id']!)),
          GoRoute(path: '/edu/paywall',  builder: (_, s) => EduPaywallScreen(lockedSubject: s.extra as String?)),
          GoRoute(path: '/edu/subject/:id', builder: (_, s) => EduSubjectScreen(subjectId: s.pathParameters['id']!)),
          GoRoute(path: '/edu/curriculum/:id', builder: (_, s) => CurriculumGamePickerScreen(curriculumId: s.pathParameters['id']!)),
          GoRoute(
            path: AppConstants.arenaRoute,
            builder: (_, __) => const ArenaScreen(),
            routes: [
              GoRoute(
                path: 'match/:id',
                builder: (_, s) => MatchScreen(matchId: s.pathParameters['id']!),
              ),
              GoRoute(path: 'duels', builder: (_, __) => const DuelLobbyScreen()),
              GoRoute(path: 'duel/:id', builder: (_, s) => DuelScreen(duelId: s.pathParameters['id']!)),
              GoRoute(path: 'practice/tictactoe', builder: (_, __) => const TicTacToePracticeScreen()),
              GoRoute(path: 'practice/chess', builder: (_, __) => DuelEntry(gameKey: 'chess', child: const ChessPracticeScreen())),
              GoRoute(path: 'practice/rps', builder: (_, __) => DuelEntry(gameKey: 'rps', child: const RpsSoloScreen())),
              GoRoute(path: 'practice/trivia', builder: (_, __) => DuelEntry(gameKey: 'trivia', child: const TriviaSoloScreen())),
              GoRoute(path: 'practice/colonybuilder', builder: (_, __) => DuelEntry(gameKey: 'colonybuilder', child: const ColonySiegeScreen())),
              GoRoute(path: 'practice/endlessrunner', builder: (_, __) => DuelEntry(gameKey: 'endlessrunner', child: const EndlessRunnerScreen())),
              GoRoute(path: 'practice/dronebreach', builder: (_, __) => DuelEntry(gameKey: 'dronebreach', child: const DroneBreachScreen())),
              GoRoute(path: 'practice/signalmatch', builder: (_, __) => DuelEntry(gameKey: 'signalmatch', child: const SignalMatchScreen())),
              GoRoute(path: 'practice/weaponduel', builder: (_, __) => DuelEntry(gameKey: 'weaponduel', child: const ArenaGauntletScreen())),
              GoRoute(path: 'practice/astracolony', builder: (_, __) => DuelEntry(gameKey: 'astracolony', child: const AstraColonyScreen())),
              GoRoute(path: 'practice/reaction', builder: (_, __) => DuelEntry(gameKey: 'reaction', child: const ReactionSoloScreen())),
              // Edu curriculum game routes — Algebra, Physics, and
              // Spatial Quiz are curriculum drills, not fun Arena
              // games, so they live under /edu/, not /arena/practice/.
              GoRoute(path: 'edu/game/algebra_eq', builder: (_, __) => const AlgebraGame()),
              GoRoute(path: 'edu/game/simultaneous', builder: (_, __) => const AlgebraGame()),
              GoRoute(path: 'edu/game/geometry', builder: (_, __) => const AlgebraGame()),
              GoRoute(path: 'edu/game/physics_quiz', builder: (_, __) => const PhysicsGame()),
              GoRoute(path: 'edu/game/chem_quiz', builder: (_, __) => const PhysicsGame()),
              GoRoute(path: 'edu/game/bio_quiz', builder: (_, __) => const TriviaSoloScreen()),
              GoRoute(path: 'edu/game/spatial_quiz', builder: (_, __) => const SpatialQuizScreen()),
              GoRoute(path: 'practice/connect4', builder: (_, __) => DuelEntry(gameKey: 'connect4', child: const ConnectFourGame())),
              GoRoute(path: 'practice/reversi', builder: (_, __) => DuelEntry(gameKey: 'reversi', child: const ReversiGame())),
              GoRoute(path: 'practice/memory', builder: (_, __) => DuelEntry(gameKey: 'memory', child: const MemoryMatchGame())),
              GoRoute(path: 'practice/wordscramble', builder: (_, __) => DuelEntry(gameKey: 'wordscramble', child: const WordScrambleGame())),
              GoRoute(path: 'practice/2048', builder: (_, __) => DuelEntry(gameKey: '2048', child: const Game2048())),
              GoRoute(path: 'practice/hangman', builder: (_, __) => DuelEntry(gameKey: 'hangman', child: const HangmanGame())),
              GoRoute(path: 'practice/speedmath', builder: (_, __) => DuelEntry(gameKey: 'speedmath', child: const SpeedMathGame())),
              GoRoute(path: 'practice/simon', builder: (_, __) => DuelEntry(gameKey: 'simon', child: const SimonSaysGame())),
              GoRoute(path: 'practice/minesweeper', builder: (_, __) => DuelEntry(gameKey: 'minesweeper', child: const MinesweeperGame())),
              GoRoute(path: 'practice/blackjack', builder: (_, __) => DuelEntry(gameKey: 'blackjack', child: const BlackjackGame())),
              GoRoute(path: 'practice/dotsboxes', builder: (_, __) => DuelEntry(gameKey: 'dotsboxes', child: const DotsAndBoxesGame())),
              GoRoute(path: 'practice/numberduel', builder: (_, __) => DuelEntry(gameKey: 'numberduel', child: const NumberQuizGame())),
              GoRoute(path: 'practice/snake', builder: (_, __) => DuelEntry(gameKey: 'snake', child: const SnakeGame())),
              GoRoute(path: 'practice/whot', builder: (_, __) => DuelEntry(gameKey: 'whot', child: const WhotGame())),
              GoRoute(path: 'practice/ludo', builder: (_, __) => DuelEntry(gameKey: 'ludo', child: const LudoScreen())),
              GoRoute(path: 'practice/ayo', builder: (_, __) => DuelEntry(gameKey: 'ayo', child: const AyoScreen())),
              GoRoute(path: 'practice/checkers', builder: (_, __) => DuelEntry(gameKey: 'checkers', child: const CheckersScreen())),
              GoRoute(path: 'practice/battleship', builder: (_, __) => DuelEntry(gameKey: 'battleship', child: const BattleshipScreen())),
              GoRoute(path: 'practice/rummy', builder: (_, __) => DuelEntry(gameKey: 'rummy', child: const RummyScreen())),
              GoRoute(path: 'practice/solitaire', builder: (_, __) => DuelEntry(gameKey: 'solitaire', child: const SolitaireScreen())),
              GoRoute(path: 'practice/puzzlerush', builder: (_, __) => DuelEntry(gameKey: 'puzzlerush', child: const PuzzleRushScreen())),
              GoRoute(path: 'practice/sudoku', builder: (_, __) => DuelEntry(gameKey: 'sudoku', child: const SudokuScreen())),
              GoRoute(path: 'practice/blockdrop', builder: (_, __) => DuelEntry(gameKey: 'blockdrop', child: const BlockDropScreen())),
              GoRoute(path: 'practice/colorclash', builder: (_, __) => DuelEntry(gameKey: 'colorclash', child: const ColorClashScreen())),
              GoRoute(path: 'practice/bubbleshooter', builder: (_, __) => DuelEntry(gameKey: 'bubbleshooter', child: const BubbleShooterScreen())),
              GoRoute(path: 'practice/stacktower', builder: (_, __) => DuelEntry(gameKey: 'stacktower', child: const StackTowerScreen())),
              GoRoute(path: 'practice/skyhopper', builder: (_, __) => DuelEntry(gameKey: 'skyhopper', child: const SkyHopperScreen())),
              GoRoute(path: 'practice/dashrunner', builder: (_, __) => DuelEntry(gameKey: 'dashrunner', child: const DashRunnerScreen())),
              GoRoute(path: 'practice/starblaster', builder: (_, __) => DuelEntry(gameKey: 'starblaster', child: const StarBlasterScreen())),
              GoRoute(path: 'practice/targetgallery', builder: (_, __) => DuelEntry(gameKey: 'targetgallery', child: const TargetGalleryScreen())),
              GoRoute(path: 'practice/fruitslice', builder: (_, __) => DuelEntry(gameKey: 'fruitslice', child: const FruitSliceScreen())),
              GoRoute(path: 'practice/basketball', builder: (_, __) => DuelEntry(gameKey: 'basketball', child: const BasketballScreen())),
              GoRoute(path: 'practice/darts', builder: (_, __) => DuelEntry(gameKey: 'darts', child: const DartsScreen())),
              GoRoute(path: 'practice/airhockey', builder: (_, __) => DuelEntry(gameKey: 'airhockey', child: const AirHockeyScreen())),
              GoRoute(path: 'practice/pool', builder: (_, __) => DuelEntry(gameKey: 'pool', child: const PoolScreen())),
              GoRoute(path: 'practice/pinball', builder: (_, __) => DuelEntry(gameKey: 'pinball', child: const PinballScreen())),
              GoRoute(path: 'practice/towerdefense', builder: (_, __) => DuelEntry(gameKey: 'towerdefense', child: const TowerDefenseScreen())),
              GoRoute(path: 'practice/minicrossword', builder: (_, __) => DuelEntry(gameKey: 'minicrossword', child: const MiniCrosswordScreen())),
              GoRoute(path: 'practice/vaultbreak', builder: (_, __) => const VaultBreakScreen()),
              GoRoute(path: 'practice/jigsaw', builder: (_, __) => DuelEntry(gameKey: 'jigsaw', child: const JigsawScreen())),
              GoRoute(
                path: 'store',
                builder: (_, __) => const GameStoreScreen(),
                routes: [
                  GoRoute(
                    path: 'submit',
                    builder: (_, __) => const GameDeveloperApplicationScreen(),
                  ),
                  GoRoute(
                    path: 'game/:id',
                    builder: (_, s) => GameDetailScreen(gameId: s.pathParameters['id']!),
                  ),
                  GoRoute(
                    path: 'survival',
                    builder: (_, __) => DuelEntry(gameKey: 'survival', child: const SurvivalShooterScreen()),
                  ),
                  GoRoute(
                    path: 'void-protocols',
                    builder: (_, __) => DuelEntry(gameKey: 'voidprotocols', child: const VoidProtocolsScreen()),
                  ),
                  GoRoute(
                    path: 'chrono-spire',
                    builder: (_, __) => DuelEntry(gameKey: 'chronospire', child: const ChronoSpireScreen()),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(path: AppConstants.adminRoute, builder: (_, __) => const AdminDashboardScreen()),
      GoRoute(path: '/admin/errors', builder: (_, __) => const ErrorLogsScreen()),
      GoRoute(path: '/admin/security', builder: (_, __) => const SecurityCenterScreen()),
      GoRoute(path: '/admin/support', builder: (_, __) => const SupportAdminScreen()),
      GoRoute(path: '/leaderboard', builder: (_, __) => const LeaderboardScreen()),
      GoRoute(path: '/customization', builder: (_, __) => const CustomizationScreen()),
      GoRoute(path: '/locker', builder: (_, __) => const LockerScreen()),
      GoRoute(path: '/missions', builder: (_, __) => const MissionsScreen()),
      GoRoute(path: '/journey', builder: (_, __) => const JourneyWorldsScreen()),
      GoRoute(path: '/journey/:realm', builder: (_, s) => JourneyMapScreen(realmId: s.pathParameters['realm'] ?? 'odyssey')),
      GoRoute(path: '/houses', builder: (_, __) => const HousesScreen()),
      GoRoute(path: '/houses/chat', builder: (_, s) {
        final extra = s.extra as Map<String, dynamic>? ?? {};
        return HouseChatScreen(houseId: extra['houseId'] as String? ?? '', houseName: extra['houseName'] as String? ?? 'House');
      }),
      GoRoute(path: '/houses/:id', builder: (_, s) => HouseDetailScreen(houseId: s.pathParameters['id'] ?? '')),
      GoRoute(path: '/houses/:id/manage', builder: (_, s) => HouseManageScreen(houseId: s.pathParameters['id'] ?? '')),
      GoRoute(path: '/admin/store', builder: (_, __) => const StoreAdminScreen()),
      GoRoute(path: '/admin/missions', builder: (_, __) => const MissionAdminScreen()),
    ],
  );

  Supabase.instance.client.auth.onAuthStateChange.listen((data) {
    _RoleGuard.clear();
    if (data.event == AuthChangeEvent.passwordRecovery) {
      router.go('/reset-password');
    }
  });

  return router;
});
