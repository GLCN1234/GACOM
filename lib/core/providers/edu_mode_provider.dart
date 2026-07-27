import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Global edu mode state — persists across the session in memory only.
/// On first load, EduModeInit (called from main.dart) reads localStorage
/// via the router so the user doesn't have to re-enable on every visit.
final eduModeProvider = StateProvider<bool>((ref) => false);
