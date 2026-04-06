class CommunityModel {
  final String id;
  final String name;
  final String description;
  final String game;
  final String? bannerUrl;
  final String? iconUrl;
  final int membersCount;
  final bool isJoined;
  final String createdBy;
  final String? parentCommunityId;
  final bool isPrivate;
  final List<String> tags;
  final DateTime createdAt;

  CommunityModel({
    required this.id,
    required this.name,
    required this.description,
    required this.game,
    this.bannerUrl,
    this.iconUrl,
    this.membersCount = 0,
    this.isJoined = false,
    required this.createdBy,
    this.parentCommunityId,
    this.isPrivate = false,
    this.tags = const [],
    required this.createdAt,
  });

  factory CommunityModel.fromJson(Map<String, dynamic> json) => CommunityModel(
    id: json['id'],
    name: json['name'],
    description: json['description'],
    game: json['game'],
    bannerUrl: json['banner_url'],
    iconUrl: json['icon_url'],
    membersCount: json['members_count'] ?? 0,
    isJoined: json['is_joined'] ?? false,
    createdBy: json['created_by'],
    parentCommunityId: json['parent_community_id'],
    isPrivate: json['is_private'] ?? false,
    tags: List<String>.from(json['tags'] ?? []),
    createdAt: DateTime.parse(json['created_at']),
  );
}
