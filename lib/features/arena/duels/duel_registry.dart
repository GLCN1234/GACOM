import 'package:flutter/widgets.dart';
import '../screens/games/air_hockey_screen.dart';
import '../screens/games/ayo_screen.dart';
import '../screens/games/basketball_screen.dart';
import '../screens/games/battleship_screen.dart';
import '../screens/games/block_drop_screen.dart';
import '../screens/games/bubble_shooter_screen.dart';
import '../screens/games/checkers_screen.dart';
import '../screens/games/color_clash_screen.dart';
import '../screens/games/darts_screen.dart';
import '../screens/games/dash_runner_screen.dart';
import '../screens/games/drone_breach_screen.dart';
import '../screens/games/endless_runner_screen.dart';
import '../screens/games/extra_games.dart';
import '../screens/games/fruit_slice_screen.dart';
import '../screens/games/jigsaw_screen.dart';
import '../screens/games/ludo_screen.dart';
import '../screens/games/mini_crossword_screen.dart';
import '../screens/games/pinball_screen.dart';
import '../screens/games/pool_screen.dart';
import '../screens/games/puzzle_rush_screen.dart';
import '../screens/games/rummy_screen.dart';
import '../screens/games/signal_match_screen.dart';
import '../screens/games/sky_hopper_screen.dart';
import '../screens/games/solitaire_screen.dart';
import '../screens/games/stack_tower_screen.dart';
import '../screens/games/star_blaster_screen.dart';
import '../screens/games/sudoku_screen.dart';
import '../screens/games/target_gallery_screen.dart';
import '../screens/games/tower_defense_screen.dart';
import '../screens/games/whot_game.dart';
import '../games/shooter/survival_shooter_screen.dart';
import '../games/void_protocols/void_protocols_screen.dart';
import '../games/chrono_spire/chrono_spire_screen.dart';
import '../../edu/odyssey/odyssey_screen.dart';

/// How a duel turns a game's reported scores into one number.
enum DuelScoring {
  /// The first result the game reports is the final one.
  firstResult,

  /// Play for a fixed time; the best single result reported counts.
  bestInTime,

  /// Play for a fixed time; every result reported is added up.
  totalInTime,
}

class DuelGame {
  final String key;
  final String name;
  final String blurb;
  final DuelScoring scoring;
  final int seconds;
  final Widget Function() build;
  const DuelGame({
    required this.key,
    required this.name,
    required this.blurb,
    required this.build,
    this.scoring = DuelScoring.firstResult,
    this.seconds = 0,
  });
}

/// Every Arena game that can be played as a score-race duel. Games that
/// already have live head-to-head matches (Chess, Tic-Tac-Toe, RPS, Trivia,
/// Reaction) stay in the main Arena lobby.
class DuelRegistry {
  static final List<DuelGame> games = <DuelGame>[
    DuelGame(key: 'airhockey', name: 'Air Hockey', blurb: 'Best result against the same AI', build: () => const AirHockeyScreen()),
    DuelGame(key: 'pool', name: '8-Ball Pool', blurb: 'Best result against the same AI', build: () => const PoolScreen()),
    DuelGame(key: 'pinball', name: 'Pinball', blurb: 'Highest score on the same table', build: () => const PinballScreen()),
    DuelGame(key: 'towerdefense', name: 'Tower Defense', blurb: 'Hold the line the longest', build: () => const TowerDefenseScreen()),
    DuelGame(key: 'minicrossword', name: 'Mini Crossword', blurb: 'Same puzzle, fastest clean solve', build: () => const MiniCrosswordScreen()),
    DuelGame(key: 'jigsaw', name: 'Jigsaw Puzzle', blurb: 'Same picture, fastest build', build: () => const JigsawScreen()),
    DuelGame(key: 'ludo', name: 'Ludo', blurb: 'Best result against the same AI', build: () => const LudoScreen()),
    DuelGame(key: 'ayo', name: 'Ayo', blurb: 'Most seeds captured', build: () => const AyoScreen()),
    DuelGame(key: 'checkers', name: 'Checkers', blurb: 'Most captures, win bonus', build: () => const CheckersScreen()),
    DuelGame(key: 'battleship', name: 'Battleship', blurb: 'Best result against the same AI', build: () => const BattleshipScreen()),
    DuelGame(key: 'rummy', name: 'Rummy', blurb: 'Best result against the same AI', build: () => const RummyScreen()),
    DuelGame(key: 'solitaire', name: 'Solitaire', blurb: 'Same deal, highest score', build: () => const SolitaireScreen()),
    DuelGame(key: 'puzzlerush', name: 'Chess Puzzle Rush', blurb: 'Most puzzles solved', build: () => const PuzzleRushScreen()),
    DuelGame(key: 'sudoku', name: 'Sudoku', blurb: 'Same grid, best solve', build: () => const SudokuScreen()),
    DuelGame(key: 'blockdrop', name: 'Block Drop', blurb: 'Same piece order, highest score', build: () => const BlockDropScreen()),
    DuelGame(key: 'colorclash', name: 'Color Clash', blurb: 'Same board, highest score', build: () => const ColorClashScreen()),
    DuelGame(key: 'bubbleshooter', name: 'Bubble Shooter', blurb: 'Same bubbles, highest score', build: () => const BubbleShooterScreen()),
    DuelGame(key: 'stacktower', name: 'Stack Tower', blurb: 'Build the tallest tower', build: () => const StackTowerScreen()),
    DuelGame(key: 'skyhopper', name: 'Sky Hopper', blurb: 'Same gaps, farthest flight', build: () => const SkyHopperScreen()),
    DuelGame(key: 'dashrunner', name: 'Dash Runner', blurb: 'Same track, farthest run', build: () => const DashRunnerScreen()),
    DuelGame(key: 'starblaster', name: 'Star Blaster', blurb: 'Same waves, highest score', build: () => const StarBlasterScreen()),
    DuelGame(key: 'targetgallery', name: 'Target Gallery', blurb: 'Same targets, highest score', build: () => const TargetGalleryScreen()),
    DuelGame(key: 'fruitslice', name: 'Fruit Slice', blurb: 'Same fruit, highest score', build: () => const FruitSliceScreen()),
    DuelGame(key: 'basketball', name: 'Basketball Shootout', blurb: '60 seconds, most baskets', build: () => const BasketballScreen()),
    DuelGame(key: 'darts', name: 'Darts', blurb: 'Highest total over 5 rounds', build: () => const DartsScreen()),
    DuelGame(key: 'connect4', name: 'Connect Four', blurb: 'Win faster than your rival', build: () => const ConnectFourGame()),
    DuelGame(key: 'reversi', name: 'Reversi', blurb: 'Most discs at the end', build: () => const ReversiGame()),
    DuelGame(key: 'memory', name: 'Memory Match', blurb: 'Same cards, fewest moves', build: () => const MemoryMatchGame()),
    DuelGame(key: 'wordscramble', name: 'Word Scramble', blurb: 'Same words, highest score', build: () => const WordScrambleGame()),
    DuelGame(key: '2048', name: '2048', blurb: 'Same tiles, highest score', build: () => const Game2048()),
    DuelGame(key: 'hangman', name: 'Hangman', blurb: 'Same words, 2 minutes, best score', scoring: DuelScoring.bestInTime, seconds: 120, build: () => const HangmanGame()),
    DuelGame(key: 'speedmath', name: 'Speed Math', blurb: 'Same sums, highest score', build: () => const SpeedMathGame()),
    DuelGame(key: 'simon', name: 'Simon Says', blurb: 'Same pattern, longest streak', build: () => const SimonSaysGame()),
    DuelGame(key: 'minesweeper', name: 'Minesweeper', blurb: 'Same minefield, fastest clear', build: () => const MinesweeperGame()),
    DuelGame(key: 'blackjack', name: 'Blackjack', blurb: 'Same shoe, 2 minutes, total winnings', scoring: DuelScoring.totalInTime, seconds: 120, build: () => const BlackjackGame()),
    DuelGame(key: 'dotsboxes', name: 'Dots and Boxes', blurb: 'Most boxes against the same AI', build: () => const DotsAndBoxesGame()),
    DuelGame(key: 'numberduel', name: 'Number Duel', blurb: 'Same sums, 2 minutes, best score', scoring: DuelScoring.bestInTime, seconds: 120, build: () => const NumberQuizGame()),
    DuelGame(key: 'snake', name: 'Snake', blurb: 'Same food, longest snake', build: () => const SnakeGame()),
    DuelGame(key: 'whot', name: 'Whot', blurb: 'Win faster than your rival', build: () => const WhotGame()),
    DuelGame(key: 'signalrun', name: 'Signal Run', blurb: 'Farthest run', build: () => const EndlessRunnerScreen()),
    DuelGame(key: 'signalmatch', name: 'Signal Match', blurb: 'Highest score', build: () => const SignalMatchScreen()),
    DuelGame(key: 'dronebreach', name: 'Drone Breach', blurb: 'Highest score', build: () => const DroneBreachScreen()),
    DuelGame(key: 'survival', name: 'Survival Shooter', blurb: 'Outlast the waves', build: () => const SurvivalShooterScreen()),
    DuelGame(key: 'voidprotocols', name: 'Void Protocols', blurb: 'Highest score', build: () => const VoidProtocolsScreen()),
    DuelGame(key: 'odyssey', name: 'Odyssey', blurb: 'Most knowledge points in 150 seconds', build: () => const OdysseyScreen()),
    DuelGame(key: 'chronospire', name: 'Chrono-Spire', blurb: 'Climb the highest', build: () => const ChronoSpireScreen()),
  ];

  static DuelGame? byKey(String key) {
    for (final DuelGame g in games) {
      if (g.key == key) return g;
    }
    return null;
  }
}
