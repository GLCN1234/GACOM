import '../../core/services/supabase_service.dart';

/// Records the results of one completed game session (institution curriculum
/// topic OR a built-in practice game) into edu_progress, so that XP, level,
/// accuracy, and streak on the Academic Profile reflect real activity from
/// every source of gameplay, not just one.
class EduProgressRecorder {
  /// Maps a full subject label (as stored in institution_curricula.subject,
  /// e.g. 'Mathematics', 'English Language') to the short canonical subject
  /// id used everywhere else in the edu section (e.g. 'math', 'english'),
  /// so institution gameplay and built-in games contribute to the SAME
  /// subject's progress rather than being tracked as unrelated subjects.
  static const _labelToId = {
    'Mathematics': 'math',
    'Algebra': 'algebra',
    'Geometry': 'geometry',
    'Statistics': 'statistics',
    'Simultaneous Eqns': 'simultaneous',
    'Physics': 'physics',
    'Chemistry': 'chemistry',
    'Biology': 'biology',
    'English Language': 'english',
    'Literature': 'literature',
    'Geography': 'geography',
    'History': 'history',
    'Economics': 'economics',
    'Civic Education': 'civics',
    'Computer Science': 'coding',
    'Basic Science and Technology': 'bst',
  };

  static String subjectIdFromLabel(String label) => _labelToId[label] ?? label.toLowerCase().replaceAll(' ', '_');

  /// [subject] should match a key from the app's canonical subject id list
  /// (e.g. 'math', 'physics', 'english') so it aligns with everywhere else
  /// subject ids are used across the edu section.
  static Future<void> recordSession({
    required String subject,
    required int xpEarned,
    required int questionsAnswered,
    required int correctAnswers,
  }) async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) return;
    try {
      await SupabaseService.client.rpc('record_edu_session', params: {
        'p_user_id': uid,
        'p_subject': subject,
        'p_xp_earned': xpEarned,
        'p_questions': questionsAnswered,
        'p_correct': correctAnswers,
      });
    } catch (_) {
      // Silently fail — a progress-recording error should never block
      // the student from seeing their game results.
    }
  }
}
