enum CompetitionStatus { upcoming, live, ended }

class CompetitionModel {
  final String id;
  final String title;
  final String description;
  final String game;
  final String? bannerUrl;
  final String? thumbnailUrl;
  final int prizePool;
  final int? entryFee;
  final bool isFree;
  final int maxParticipants;
  final int currentParticipants;
  final CompetitionStatus status;
  final DateTime startDate;
  final DateTime endDate;
  final String createdBy;
  final String? communityId;
  final String platform;
  final String rules;
  final List<PrizeBreakdown> prizes;
  final bool isJoined;
  final DateTime createdAt;

  CompetitionModel({
    required this.id,
    required this.title,
    required this.description,
    required this.game,
    this.bannerUrl,
    this.thumbnailUrl,
    required this.prizePool,
    this.entryFee,
    this.isFree = true,
    this.maxParticipants = 100,
    this.currentParticipants = 0,
    required this.status,
    required this.startDate,
    required this.endDate,
    required this.createdBy,
    this.communityId,
    this.platform = 'Cross-platform',
    this.rules = '',
    this.prizes = const [],
    this.isJoined = false,
    required this.createdAt,
  });

  factory CompetitionModel.fromJson(Map<String, dynamic> json) => CompetitionModel(
    id: json['id'],
    title: json['title'],
    description: json['description'],
    game: json['game'],
    bannerUrl: json['banner_url'],
    thumbnailUrl: json['thumbnail_url'],
    prizePool: json['prize_pool'] ?? 0,
    entryFee: json['entry_fee'],
    isFree: json['is_free'] ?? true,
    maxParticipants: json['max_participants'] ?? 100,
    currentParticipants: json['current_participants'] ?? 0,
    status: CompetitionStatus.values.firstWhere(
      (e) => e.name == (json['status'] ?? 'upcoming'),
      orElse: () => CompetitionStatus.upcoming,
    ),
    startDate: DateTime.parse(json['start_date']),
    endDate: DateTime.parse(json['end_date']),
    createdBy: json['created_by'],
    communityId: json['community_id'],
    platform: json['platform'] ?? 'Cross-platform',
    rules: json['rules'] ?? '',
    prizes: (json['prizes'] as List? ?? []).map((p) => PrizeBreakdown.fromJson(p)).toList(),
    isJoined: json['is_joined'] ?? false,
    createdAt: DateTime.parse(json['created_at']),
  );
}

class PrizeBreakdown {
  final int position;
  final int amount;
  final String? description;

  PrizeBreakdown({required this.position, required this.amount, this.description});

  factory PrizeBreakdown.fromJson(Map<String, dynamic> json) => PrizeBreakdown(
    position: json['position'],
    amount: json['amount'],
    description: json['description'],
  );
}
