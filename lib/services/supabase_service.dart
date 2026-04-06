import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/constants.dart';

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;
  static User? get currentUser => client.auth.currentUser;
  static String? get currentUserId => currentUser?.id;

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: AppConstants.supabaseUrl,
      anonKey: AppConstants.supabaseAnonKey,
    );
  }

  // Auth
  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String username,
    String? displayName,
  }) async {
    final response = await client.auth.signUp(
      email: email,
      password: password,
      data: {'username': username, 'display_name': displayName ?? username},
    );
    if (response.user != null) {
      await client.from('profiles').insert({
        'id': response.user!.id,
        'email': email,
        'username': username,
        'display_name': displayName ?? username,
        'role': 'user',
        'wallet_balance': 0,
      });
    }
    return response;
  }

  static Future<AuthResponse> signIn({required String email, required String password}) async {
    return await client.auth.signInWithPassword(email: email, password: password);
  }

  static Future<void> signOut() async => await client.auth.signOut();

  // Profiles
  static Future<Map<String, dynamic>?> getProfile(String userId) async {
    final response = await client.from('profiles').select('*').eq('id', userId).maybeSingle();
    return response;
  }

  static Future<void> updateProfile(String userId, Map<String, dynamic> data) async {
    await client.from('profiles').update(data).eq('id', userId);
  }

  // Posts/Feed
  static Future<List<Map<String, dynamic>>> getFeedPosts({int page = 0}) async {
    return await client
        .from('posts')
        .select('*, user:profiles(id, username, avatar_url, is_verified)')
        .order('created_at', ascending: false)
        .range(page * AppConstants.feedPageSize, (page + 1) * AppConstants.feedPageSize - 1);
  }

  static Future<Map<String, dynamic>> createPost(Map<String, dynamic> post) async {
    final response = await client.from('posts').insert(post).select().single();
    return response;
  }

  static Future<void> likePost(String postId, String userId) async {
    await client.from('post_likes').upsert({'post_id': postId, 'user_id': userId});
    await client.rpc('increment_likes', params: {'post_id': postId});
  }

  static Future<void> unlikePost(String postId, String userId) async {
    await client.from('post_likes').delete().eq('post_id', postId).eq('user_id', userId);
    await client.rpc('decrement_likes', params: {'post_id': postId});
  }

  // Competitions
  static Future<List<Map<String, dynamic>>> getCompetitions({String? status}) async {
    var query = client.from('competitions').select('*').order('created_at', ascending: false);
    if (status != null) query = query.eq('status', status);
    return await query;
  }

  static Future<Map<String, dynamic>> getCompetition(String id) async {
    return await client.from('competitions').select('*').eq('id', id).single();
  }

  static Future<void> joinCompetition(String competitionId, String userId) async {
    await client.from('competition_participants').insert({'competition_id': competitionId, 'user_id': userId});
    await client.rpc('increment_participants', params: {'competition_id': competitionId});
  }

  // Communities
  static Future<List<Map<String, dynamic>>> getCommunities({bool topLevel = true}) async {
    var query = client.from('communities').select('*').order('members_count', ascending: false);
    if (topLevel) query = query.isFilter('parent_community_id', null);
    return await query;
  }

  static Future<void> joinCommunity(String communityId, String userId) async {
    await client.from('community_members').insert({'community_id': communityId, 'user_id': userId, 'role': 'member'});
    await client.rpc('increment_members', params: {'community_id': communityId});
  }

  // Chat
  static Future<List<Map<String, dynamic>>> getMessages(String chatRoomId) async {
    return await client
        .from('messages')
        .select('*, sender:profiles(id, username, avatar_url)')
        .eq('chat_room_id', chatRoomId)
        .order('created_at', ascending: true)
        .limit(100);
  }

  static RealtimeChannel subscribeToMessages(String chatRoomId, Function(Map<String, dynamic>) onMessage) {
    return client.channel('messages:$chatRoomId').onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'messages',
      filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'chat_room_id', value: chatRoomId),
      callback: (payload) => onMessage(payload.newRecord),
    ).subscribe();
  }

  static Future<void> sendMessage(Map<String, dynamic> message) async {
    await client.from('messages').insert(message);
  }

  // E-commerce
  static Future<List<Map<String, dynamic>>> getProducts({String? category}) async {
    var query = client.from('products').select('*').eq('is_available', true).order('created_at', ascending: false);
    if (category != null) query = query.eq('category', category);
    return await query;
  }

  static Future<Map<String, dynamic>> createOrder(Map<String, dynamic> order) async {
    return await client.from('orders').insert(order).select().single();
  }

  // Wallet
  static Future<int> getWalletBalance(String userId) async {
    final profile = await client.from('profiles').select('wallet_balance').eq('id', userId).single();
    return profile['wallet_balance'] ?? 0;
  }

  static Future<void> creditWallet(String userId, int amount, String reference) async {
    await client.rpc('credit_wallet', params: {'user_id': userId, 'amount': amount, 'reference': reference});
  }

  static Future<void> debitWallet(String userId, int amount, String reference) async {
    await client.rpc('debit_wallet', params: {'user_id': userId, 'amount': amount, 'reference': reference});
  }

  static Future<List<Map<String, dynamic>>> getTransactions(String userId) async {
    return await client
        .from('wallet_transactions')
        .select('*')
        .eq('user_id', userId)
        .order('created_at', ascending: false);
  }

  // Blog
  static Future<List<Map<String, dynamic>>> getBlogPosts() async {
    return await client
        .from('blog_posts')
        .select('*, author:profiles(id, username, avatar_url, is_verified)')
        .eq('is_published', true)
        .order('published_at', ascending: false);
  }

  // Storage
  static Future<String?> uploadFile(String bucket, String path, List<int> bytes, {String? contentType}) async {
    await client.storage.from(bucket).uploadBinary(path, Uint8List.fromList(bytes), fileOptions: FileOptions(contentType: contentType));
    return client.storage.from(bucket).getPublicUrl(path);
  }

  // Admin
  static Future<Map<String, dynamic>> getDashboardStats() async {
    final users = await client.from('profiles').select('id', const FetchOptions(count: CountOption.exact));
    final competitions = await client.from('competitions').select('id', const FetchOptions(count: CountOption.exact));
    final orders = await client.from('orders').select('total_amount').eq('status', 'completed');
    final totalRevenue = orders.fold<int>(0, (sum, o) => sum + (o['total_amount'] as int? ?? 0));
    return {
      'total_users': users.count,
      'total_competitions': competitions.count,
      'total_revenue': totalRevenue,
    };
  }
}
