class BlogPost {
  final String id;
  final String title;
  final String content;
  final String? excerpt;
  final String? coverImage;
  final String authorId;
  final UserBasic author;
  final List<String> tags;
  final int readTime;
  final int viewsCount;
  final int likesCount;
  final bool isPublished;
  final DateTime createdAt;
  final DateTime? publishedAt;

  BlogPost({
    required this.id,
    required this.title,
    required this.content,
    this.excerpt,
    this.coverImage,
    required this.authorId,
    required this.author,
    this.tags = const [],
    this.readTime = 5,
    this.viewsCount = 0,
    this.likesCount = 0,
    this.isPublished = false,
    required this.createdAt,
    this.publishedAt,
  });

  factory BlogPost.fromJson(Map<String, dynamic> json) => BlogPost(
    id: json['id'],
    title: json['title'],
    content: json['content'],
    excerpt: json['excerpt'],
    coverImage: json['cover_image'],
    authorId: json['author_id'],
    author: UserBasic.fromJson(json['author'] ?? {}),
    tags: List<String>.from(json['tags'] ?? []),
    readTime: json['read_time'] ?? 5,
    viewsCount: json['views_count'] ?? 0,
    likesCount: json['likes_count'] ?? 0,
    isPublished: json['is_published'] ?? false,
    createdAt: DateTime.parse(json['created_at']),
    publishedAt: json['published_at'] != null ? DateTime.parse(json['published_at']) : null,
  );
}

class UserBasic {
  final String id;
  final String username;
  final String? avatarUrl;
  final bool isVerified;

  UserBasic({required this.id, required this.username, this.avatarUrl, this.isVerified = false});

  factory UserBasic.fromJson(Map<String, dynamic> json) => UserBasic(
    id: json['id'] ?? '',
    username: json['username'] ?? 'Unknown',
    avatarUrl: json['avatar_url'],
    isVerified: json['is_verified'] ?? false,
  );
}
