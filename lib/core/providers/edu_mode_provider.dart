import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Global edu mode state — when true the entire app shell switches to
/// the Edu Gaming experience (different nav, home, chat, games).
final eduModeProvider = StateProvider<bool>((ref) => false);
