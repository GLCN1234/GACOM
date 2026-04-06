class UserModel {
  final String id;
  final String username;
  final String email;
  final String? displayName;
  final String? avatarUrl;
  final String? bio;
  final String? bannerUrl;
  final bool isVerified;
  final bool isAdmin;
  final String role; // user, admin, super_admin
  final int followersCount;
  final int followingCount;
  final int walletBalance;
  final String? gameTag;
  final List<String> favoriteGames;
  final DateTime createdAt;
  final bool isOnline;

  UserModel({
    required this.id,
    required this.username,
    required this.email,
    this.displayName,
    this.avatarUrl,
    this.bio,
    this.bannerUrl,
    this.isVerified = false,
    this.isAdmin = false,
    this.role = 'user',
    this.followersCount = 0,
    this.followingCount = 0,
    this.walletBalance = 0,
    this.gameTag,
    this.favoriteGames = const [],
    required this.createdAt,
    this.isOnline = false,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      username: json['username'],
      email: json['email'],
      displayName: json['display_name'],
      avatarUrl: json['avatar_url'],
      bio: json['bio'],
      bannerUrl: json['banner_url'],
      isVerified: json['is_verified'] ?? false,
      isAdmin: json['is_admin'] ?? false,
      role: json['role'] ?? 'user',
      followersCount: json['followers_count'] ?? 0,
      followingCount: json['following_count'] ?? 0,
      walletBalance: json['wallet_balance'] ?? 0,
      gameTag: json['game_tag'],
      favoriteGames: List<String>.from(json['favorite_games'] ?? []),
      createdAt: DateTime.parse(json['created_at']),
      isOnline: json['is_online'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'email': email,
    'display_name': displayName,
    'avatar_url': avatarUrl,
    'bio': bio,
    'banner_url': bannerUrl,
    'is_verified': isVerified,
    'is_admin': isAdmin,
    'role': role,
    'followers_count': followersCount,
    'following_count': followingCount,
    'wallet_balance': walletBalance,
    'game_tag': gameTag,
    'favorite_games': favoriteGames,
    'created_at': createdAt.toIso8601String(),
    'is_online': isOnline,
  };
}
