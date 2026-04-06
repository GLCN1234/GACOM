import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import 'supabase_service.dart';

final authStateProvider = StreamProvider<User?>((ref) {
  return SupabaseService.client.auth.onAuthStateChange.map((event) => event.session?.user);
});

final currentUserProvider = FutureProvider<UserModel?>((ref) async {
  final user = SupabaseService.currentUser;
  if (user == null) return null;
  final profile = await SupabaseService.getProfile(user.id);
  if (profile == null) return null;
  return UserModel.fromJson(profile);
});

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) => AuthNotifier());

class AuthState {
  final bool isLoading;
  final String? error;
  final UserModel? user;

  AuthState({this.isLoading = false, this.error, this.user});
  AuthState copyWith({bool? isLoading, String? error, UserModel? user}) =>
      AuthState(isLoading: isLoading ?? this.isLoading, error: error, user: user ?? this.user);
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(AuthState());

  Future<bool> signIn(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await SupabaseService.signIn(email: email, password: password);
      if (response.user != null) {
        final profile = await SupabaseService.getProfile(response.user!.id);
        if (profile != null) {
          state = state.copyWith(isLoading: false, user: UserModel.fromJson(profile));
          return true;
        }
      }
      state = state.copyWith(isLoading: false, error: 'Login failed');
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> signUp(String email, String password, String username) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await SupabaseService.signUp(email: email, password: password, username: username);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<void> signOut() async {
    await SupabaseService.signOut();
    state = AuthState();
  }
}
