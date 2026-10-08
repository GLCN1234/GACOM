import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/supabase_service.dart';

Map<String, dynamic>? _map(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : null;
List<Map<String, dynamic>> _list(dynamic v) =>
    v is List ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : <Map<String, dynamic>>[];

/// Outcome of a mission action. status is 'approved' or 'pending' on success.
class MissionResult {
  final bool success;
  final String? error;
  final String? status;
  const MissionResult({required this.success, this.error, this.status});
  String get message => error ?? 'Something went wrong';
}

/// Thin wrapper over the missions RPCs and the admin tables. Nothing here throws:
/// reads return empty values or an `error` entry, writes return a [MissionResult].
class MissionsService {
  MissionsService._();

  static const String clipBucket = 'mission-clips';
  static const int maxClipBytes = 50 * 1024 * 1024;

  static String friendlyError(Object e) {
    final s = e.toString().toLowerCase();
    if (s.contains('could not find the function') || s.contains('does not exist') || s.contains('pgrst202')) {
      return 'Missions are being updated. Please try again shortly.';
    }
    if (s.contains('admins only')) return 'Admins only.';
    if (s.contains('socketexception') || s.contains('failed host lookup') || s.contains('clientexception') || s.contains('timeout')) {
      return 'No connection. Check your internet and try again.';
    }
    if (s.contains('jwt') || s.contains('not authenticated')) return 'Please sign in again.';
    if (s.contains('mission_seasons_one_active') || (s.contains('duplicate key') && s.contains('is_active'))) {
      return 'Only one season can be active. Deactivate the other season first.';
    }
    if (s.contains('duplicate key')) return 'That entry already exists.';
    if (s.contains('violates row-level security') || s.contains('permission denied')) return 'You do not have permission to do that.';
    return 'Something went wrong. Please try again.';
  }

  static MissionResult _result(dynamic res) {
    if (res is Map) {
      final ok = res['success'] == true;
      return MissionResult(
        success: ok,
        error: ok ? null : (res['error']?.toString() ?? 'Something went wrong'),
        status: res['status']?.toString(),
      );
    }
    return const MissionResult(success: false, error: 'Unexpected response from the server');
  }

  static Future<MissionResult> _rpc(String fn, Map<String, dynamic> params) async {
    try {
      return _result(await SupabaseService.client.rpc(fn, params: params));
    } catch (e) {
      return MissionResult(success: false, error: friendlyError(e));
    }
  }

  // ---------------------------------------------------------------- player

  /// The player's view of the active season. Returns {'season': null} when none is
  /// running and {'error': message} when the call failed.
  static Future<Map<String, dynamic>> myMissions() async {
    try {
      final res = await SupabaseService.client.rpc('my_missions');
      final m = _map(res);
      if (m == null) return <String, dynamic>{'season': null};
      return m;
    } catch (e) {
      return <String, dynamic>{'season': null, 'error': friendlyError(e)};
    }
  }

  static Future<MissionResult> claim(String missionId) => _rpc('claim_mission', {'p_mission_id': missionId});

  /// proof is a link, a code word, or the storage path of an uploaded clip.
  static Future<MissionResult> submit(String missionId, String proof, {String? note}) => _rpc('submit_mission', {
        'p_mission_id': missionId,
        'p_proof': proof.trim(),
        'p_note': (note == null || note.trim().isEmpty) ? null : note.trim(),
      });

  /// Uploads a clip to the private bucket and returns its storage path, or null on failure.
  /// [error] is filled with a readable reason when null is returned.
  static Future<String?> uploadClip(Uint8List bytes, String fileName, void Function(String) error) async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) {
      error('Please sign in again.');
      return null;
    }
    if (bytes.isEmpty) {
      error('That file is empty.');
      return null;
    }
    if (bytes.length > maxClipBytes) {
      error('That clip is too large. The limit is 50 MB.');
      return null;
    }
    final dot = fileName.lastIndexOf('.');
    var ext = dot >= 0 ? fileName.substring(dot + 1).toLowerCase() : 'mp4';
    if (ext.isEmpty || ext.length > 5) ext = 'mp4';
    final type = ext == 'mov' ? 'video/quicktime' : (ext == 'webm' ? 'video/webm' : 'video/mp4');
    final path = '$uid/${DateTime.now().millisecondsSinceEpoch}.$ext';
    try {
      await SupabaseService.client.storage
          .from(clipBucket)
          .uploadBinary(path, bytes, fileOptions: FileOptions(contentType: type, upsert: false));
      return path;
    } catch (e) {
      error('Upload failed. Check your connection and try again.');
      return null;
    }
  }

  // ----------------------------------------------------------------- admin

  static Future<List<Map<String, dynamic>>> adminQueue(String status, {int limit = 60}) async {
    final res = await SupabaseService.client.rpc('admin_mission_queue', params: {'p_status': status, 'p_limit': limit});
    return _list(res);
  }

  static Future<MissionResult> review(String submissionId, bool approve, {String? reason}) => _rpc(
      'review_mission_submission', {'p_id': submissionId, 'p_approve': approve, 'p_reason': (reason == null || reason.trim().isEmpty) ? null : reason.trim()});

  static Future<String?> signedClipUrl(String path) async {
    try {
      return await SupabaseService.client.storage.from(clipBucket).createSignedUrl(path, 3600);
    } catch (_) {
      return null;
    }
  }

  static Future<MissionResult> grantItem(String userId, String itemId, {String? note}) => _rpc('admin_grant_cosmetic', {
        'p_user': userId,
        'p_item': itemId,
        'p_note': (note == null || note.trim().isEmpty) ? null : note.trim(),
      });

  static Future<MissionResult> grantTrophy(String userId, String key) => _rpc('admin_grant_trophy', {'p_user': userId, 'p_key': key});

  static Future<MissionResult> grantHousePoints(String houseId, int points, {String? reason}) =>
      _rpc('admin_grant_house_points', {'p_house': houseId, 'p_points': points, 'p_reason': (reason == null || reason.trim().isEmpty) ? 'admin' : reason.trim()});

  /// Finds a profile by username (exact, case-insensitive) or by user id.
  static Future<Map<String, dynamic>?> findProfile(String input) async {
    final q = input.trim().replaceFirst(RegExp(r'^@'), '');
    if (q.isEmpty) return null;
    try {
      final isUuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(q);
      final rows = isUuid
          ? await SupabaseService.client.from('profiles').select('id, username, display_name').eq('id', q).limit(1)
          : await SupabaseService.client
              .from('profiles')
              .select('id, username, display_name')
              .ilike('username', q.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_'))
              .limit(1);
      final l = _list(rows);
      return l.isEmpty ? null : l.first;
    } catch (_) {
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> seasons() async {
    final res = await SupabaseService.client.from('mission_seasons').select('*').order('starts_on', ascending: false);
    return _list(res);
  }

  static Future<MissionResult> saveSeason(Map<String, dynamic> values, {String? id}) async {
    try {
      if (id == null) {
        await SupabaseService.client.from('mission_seasons').insert(values);
      } else {
        await SupabaseService.client.from('mission_seasons').update(values).eq('id', id);
      }
      return const MissionResult(success: true);
    } catch (e) {
      return MissionResult(success: false, error: friendlyError(e));
    }
  }

  /// Makes one season active, deactivating any other first (only one may be active).
  static Future<MissionResult> activateSeason(String id) async {
    try {
      await SupabaseService.client.from('mission_seasons').update({'is_active': false}).neq('id', id).eq('is_active', true);
      await SupabaseService.client.from('mission_seasons').update({'is_active': true}).eq('id', id);
      return const MissionResult(success: true);
    } catch (e) {
      return MissionResult(success: false, error: friendlyError(e));
    }
  }

  /// Deactivates every active season except [exceptId] (null means all of them).
  static Future<MissionResult> deactivateOtherSeasons({String? exceptId}) async {
    try {
      final q = SupabaseService.client.from('mission_seasons').update({'is_active': false});
      if (exceptId != null) {
        await q.eq('is_active', true).neq('id', exceptId);
      } else {
        await q.eq('is_active', true);
      }
      return const MissionResult(success: true);
    } catch (e) {
      return MissionResult(success: false, error: friendlyError(e));
    }
  }

  static Future<List<Map<String, dynamic>>> missionsForSeason(String seasonId) async {
    final res = await SupabaseService.client
        .from('missions')
        .select('*')
        .eq('season_id', seasonId)
        .order('day_number')
        .order('sort_order');
    return _list(res);
  }

  /// Saves a mission (insert when id is null) and, for code_word missions, its answer.
  static Future<MissionResult> saveMission(Map<String, dynamic> values, {String? id, String? codeAnswer}) async {
    try {
      String missionId;
      if (id == null) {
        final row = await SupabaseService.client.from('missions').insert(values).select('id').single();
        missionId = row['id'].toString();
      } else {
        await SupabaseService.client.from('missions').update(values).eq('id', id);
        missionId = id;
      }
      if (values['type'] == 'code_word') {
        final answer = (codeAnswer ?? '').trim();
        if (answer.isEmpty) {
          return const MissionResult(success: false, error: 'Mission saved, but a code word mission needs an answer.');
        }
        await SupabaseService.client.from('mission_secrets').upsert({'mission_id': missionId, 'answer': answer});
      }
      return const MissionResult(success: true);
    } catch (e) {
      return MissionResult(success: false, error: friendlyError(e));
    }
  }

  static Future<String?> missionSecret(String missionId) async {
    try {
      final row = await SupabaseService.client.from('mission_secrets').select('answer').eq('mission_id', missionId).maybeSingle();
      return row?['answer']?.toString();
    } catch (_) {
      return null;
    }
  }

  static Future<MissionResult> deleteMission(String id) async {
    try {
      await SupabaseService.client.from('missions').delete().eq('id', id);
      return const MissionResult(success: true);
    } catch (e) {
      return MissionResult(success: false, error: friendlyError(e));
    }
  }

  static Future<List<Map<String, dynamic>>> seasonRewards(String seasonId) async {
    final res = await SupabaseService.client.from('mission_season_rewards').select('*').eq('season_id', seasonId).order('threshold');
    return _list(res);
  }

  static Future<MissionResult> saveSeasonReward(Map<String, dynamic> values, {String? id}) async {
    try {
      if (id == null) {
        await SupabaseService.client.from('mission_season_rewards').insert(values);
      } else {
        await SupabaseService.client.from('mission_season_rewards').update(values).eq('id', id);
      }
      return const MissionResult(success: true);
    } catch (e) {
      return MissionResult(success: false, error: friendlyError(e));
    }
  }

  static Future<MissionResult> deleteSeasonReward(String id) async {
    try {
      await SupabaseService.client.from('mission_season_rewards').delete().eq('id', id);
      return const MissionResult(success: true);
    } catch (e) {
      return MissionResult(success: false, error: friendlyError(e));
    }
  }

  static Future<List<Map<String, dynamic>>> cosmeticItems() async {
    final res = await SupabaseService.client.from('cosmetic_items').select('id, name, category, rarity').order('name').limit(1000);
    return _list(res);
  }

  static Future<List<Map<String, dynamic>>> trophyDefs() async {
    final res = await SupabaseService.client.from('trophy_defs').select('key, name').order('sort_order');
    return _list(res);
  }
}
