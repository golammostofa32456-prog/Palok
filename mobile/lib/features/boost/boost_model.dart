class BoostModel {
  final String id;
  final String userId;
  final String videoId;

  final String status;

  final int budget;
  final int durationDays;

  final int impressions;
  final int clicks;

  final DateTime? createdAt;
  final DateTime? startAt;
  final DateTime? endAt;

  BoostModel({
    required this.id,
    required this.userId,
    required this.videoId,
    required this.status,
    required this.budget,
    required this.durationDays,
    required this.impressions,
    required this.clicks,
    this.createdAt,
    this.startAt,
    this.endAt,
  });

  factory BoostModel.fromMap(
    String id,
    Map<String, dynamic> map,
  ) {
    return BoostModel(
      id: id,
      userId: (map['userId'] ?? '').toString(),
      videoId: (map['videoId'] ?? '').toString(),
      status: (map['status'] ?? 'pending').toString(),
      budget: (map['budget'] ?? 0) as int,
      durationDays: (map['durationDays'] ?? 1) as int,
      impressions: (map['impressions'] ?? 0) as int,
      clicks: (map['clicks'] ?? 0) as int,
      createdAt: _dateFromValue(map['createdAt']),
      startAt: _dateFromValue(map['startAt']),
      endAt: _dateFromValue(map['endAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'videoId': videoId,
      'status': status,
      'budget': budget,
      'durationDays': durationDays,
      'impressions': impressions,
      'clicks': clicks,
      'createdAt': createdAt,
      'startAt': startAt,
      'endAt': endAt,
    };
  }

  BoostModel copyWith({
    String? id,
    String? userId,
    String? videoId,
    String? status,
    int? budget,
    int? durationDays,
    int? impressions,
    int? clicks,
    DateTime? createdAt,
    DateTime? startAt,
    DateTime? endAt,
  }) {
    return BoostModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      videoId: videoId ?? this.videoId,
      status: status ?? this.status,
      budget: budget ?? this.budget,
      durationDays: durationDays ?? this.durationDays,
      impressions: impressions ?? this.impressions,
      clicks: clicks ?? this.clicks,
      createdAt: createdAt ?? this.createdAt,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
    );
  }

  static DateTime? _dateFromValue(dynamic value) {
    if (value == null) return null;

    if (value is DateTime) {
      return value;
    }

    try {
      return value.toDate() as DateTime;
    } catch (_) {}

    try {
      return DateTime.parse(value.toString());
    } catch (_) {
      return null;
    }
  }
}
