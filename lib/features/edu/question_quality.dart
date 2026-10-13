/// One place that decides whether a curriculum question can be answered on its
/// own. A game draws questions one at a time, in any order, with the options
/// shuffled, so a question must never lean on anything the player cannot see:
/// a passage, a poem, a diagram, a "given below" table, or another option such
/// as "All of the above". Questions that do are left out of play.
class QuestionQuality {
  static const String _apos = r"(?!['’]s)";
  static const String _pre = r'(?:according to|based on|from|in|using|refer to|read|reading|within|throughout)';
  static const String _vn = r'(?:diagram|figure|picture|image|graph|chart|illustration|table)';

  /// Words that point at something outside the question.
  static final RegExp _unseen = RegExp(
    r'\b(?:the|this)\s+(?:passage|extract|excerpt|article)\b'
    r"|\b(?:why|how) does the (?:author|writer|poet|narrator)\b"
    r"|\bthe\s+(?:author|writer|poet|narrator)(?:['’]s)?\s+(?:choice|decision|use of|description of|mention of|inclusion|reason|says|states|tells|describes|mentions|implies|suggests|uses|intends|means)\b"
    r'|\bin this context\b'
    '|\\b$_pre\\s+(?:the|this)\\s+(?:poem|paragraph|text|dialogue|comprehension)\\b$_apos'
    r'|\b(?:poem|paragraph|text|passage|extract|excerpt|dialogue)\s+(?:above|below)\b'
    r'|\b(?:above|below|following)\s+(?:passage|poem|text|extract|excerpt|dialogue|paragraph)\b'
    '|\\b$_vn\\b[^.?!]{0,25}\\b(?:above|below)\\b'
    '|\\b(?:above|below|following|given)\\s+$_vn\\b'
    r'|\bin the (?:diagram|figure|picture|image|graph|chart|illustration)\b'
    r'|\bthe (?:diagram|figure|picture|image|graph|chart|illustration) (?:shows|above|below)\b'
    r'|\b(?:shown|given|drawn)\s+(?:above|below)\b',
    caseSensitive: false,
  );

  /// Text quoted inside the question itself, so the question carries its own material.
  static final RegExp _quoted = RegExp(
    '[“"][^”"]{25,}[”"]'
    r"|(?:^|[\s:(])'(?:[^']|(?<=\w)'(?=\w)){25,}'(?:[\s.,;:?!)]|$)",
  );

  static final RegExp _longQuoted = RegExp('[“"][^”"]{150,}[”"]');

  /// Options that only make sense in one fixed order, which shuffling breaks.
  static final RegExp _positional = RegExp(
    r'\b(?:all|none|both|neither)\s+of\s+the\s+above\b'
    r'|\bboth\s+[a-d]\s+and\s+[a-d]\b'
    r'|\b[a-d]\s+and\s+[a-d]\s+only\b'
    r'|^\s*[a-d]\s+and\s+[a-d]\s*$'
    r'|\babove\s+options?\b',
    caseSensitive: false,
  );

  static final RegExp _letter = RegExp(r'^\s*[A-Da-d][.)]\s+');

  static bool _allLettered(List<String> o) => o.length >= 2 && o.every((String e) => _letter.hasMatch(e));

  /// Options without a leading "A. " style letter. The game shuffles them, so a
  /// printed letter would end up out of order.
  static List<String> stripLetters(List<String> options) =>
      _allLettered(options) ? options.map((String e) => e.replaceFirst(_letter, '')).toList() : options;

  static String stripLetter(String answer, List<String> originalOptions) =>
      _allLettered(originalOptions) ? answer.replaceFirst(_letter, '') : answer;

  /// True when the question points at material it does not contain.
  static bool leansOnUnseen(String text) => _unseen.hasMatch(text) && !_quoted.hasMatch(text);

  /// Why a multiple-choice question cannot be played, or null when it can.
  /// [maxLen] caps the question length for fast games; 0 means no cap.
  static String? problem(String text, List<String> options, String answer, {int maxLen = 0}) {
    if (text.trim().isEmpty) return 'empty';
    if (options.length < 2) return 'options';
    if (!options.contains(answer)) return 'answer';
    final List<String> shown = stripLetters(options);
    if (shown.map((String e) => e.trim()).toSet().length < shown.length) return 'duplicate options';
    if (shown.any(_positional.hasMatch)) return 'positional option';
    if (leansOnUnseen(text)) return 'needs unseen material';
    if (maxLen > 0 && text.length > maxLen) return 'too long';
    return null;
  }

  /// A looser check for games that also play typed or true or false questions:
  /// only the "needs something I cannot see" rules apply.
  static bool selfContained(Map<String, dynamic> q) {
    final dynamic t = q['question'] ?? q['q'];
    if (t is! String || t.trim().isEmpty) return false;
    final dynamic o = q['options'] ?? q['opts'];
    if (o is List && o.map((dynamic e) => e.toString()).any(_positional.hasMatch)) return false;
    return !leansOnUnseen(t);
  }

  /// One topic's questions. When a topic carries a full passage inside one
  /// question, the rest of its questions are about that passage and cannot
  /// stand alone, so only questions with their own quoted text stay.
  static List<Map<String, dynamic>> filterTopic(List<Map<String, dynamic>> qs) {
    bool anchored = false;
    for (final Map<String, dynamic> q in qs) {
      final dynamic t = q['question'] ?? q['q'];
      if (t is String && _longQuoted.hasMatch(t)) {
        anchored = true;
        break;
      }
    }
    return qs.where((Map<String, dynamic> q) {
      if (!selfContained(q)) return false;
      if (!anchored) return true;
      final dynamic t = q['question'] ?? q['q'];
      return t is String && _quoted.hasMatch(t);
    }).toList();
  }
}
