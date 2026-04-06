enum PostType { image, video, text, poll }

class PostModel {
  final String id;
  final String userId;
  final UserBasic user;
  final String? content;
  final List<String> mediaUrls;
  final PostType type;
  final int likesCount;
  final int commentsCount;
  final int sharesCount;
  final int viewsCount;
  final bool isLiked;
  final String? communityId;
  final List<String> tags;
  final DateTime createdAt;

  PostModel({
    required this.id,
    required this.userId,
    required this.user,
    this.content,
    this.mediaUrls = const [],
    this.type = PostType.text,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.sharesCount = 0,
    this.viewsCount = 0,
    this.isLiked = false,
    this.communityId,
    this.tags = const [],
    required this.createdAt,
  });

  factory PostModel.fromJson(Map<String, dynamic> json) {
    return PostModel(
      id: json['id'],
      userId: json['user_id'],
      user: UserBasic.fromJson(json['user'] ?? {}),
      content: json['content'],
      mediaUrls: List<String>.from(json['media_urls'] ?? []),
      type: PostType.values.firstWhere(
        (e) => e.name == (json['type'] ?? 'text'),
        orElse: () => PostType.text,
      ),
      likesCount: json['likes_count'] ?? 0,
      commentsCount: json['comments_count'] ?? 0,
      sharesCount: json['shares_count'] ?? 0,
      viewsCount: json['views_count'] ?? 0,
      isLiked: json['is_liked'] ?? false,
      communityId: json['community_id'],
      tags: List<String>.from(json['tags'] ?? []),
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

class UserBasic {
  final String id;
  final String username;
  final String? avatarUrl;
  final bool isVerified;

  UserBasic({required this.id, required this.username, this.avatarUrl, this.isVerified = false});

  factory UserBasic.fromJson(Map<String, dynamic> json) => UserBasic(
    id: json['id'] ?? '',
    username: json['username'] ?? '',
    avatarUrl: json['avatar_url'],
    isVerified: json['is_verified'] ?? false,
  );
}
