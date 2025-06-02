enum FeedbackType { feedback, bug }

extension FeedbackTypeExtension on FeedbackType {
  String get value {
    switch (this) {
      case FeedbackType.feedback:
        return 'feedback';
      case FeedbackType.bug:
        return 'bug';
    }
  }

  static FeedbackType fromValue(String value) {
    return value == 'bug' ? FeedbackType.bug : FeedbackType.feedback;
  }
}

class Feedback {
  final String? id; // Optional, assigned by Supabase
  final String userId;
  final FeedbackType type; // Added type
  final int? rating; // Made nullable
  final String? comment; // Will be used for feedback comment or bug description
  final String? screenshotUrl; // Added screenshot URL
  final DateTime createdAt;
  final String deviceInfo; // e.g., OS, app version

  Feedback({
    this.id,
    required this.userId,
    required this.type, // Added
    this.rating, // Updated
    this.comment,
    this.screenshotUrl, // Added
    required this.createdAt,
    required this.deviceInfo,
  });

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'type': type.value, // Added
      'rating': rating, // Updated (nullable)
      'comment': comment,
      'screenshot_url': screenshotUrl, // Added
      'created_at': createdAt.toIso8601String(),
      'device_info': deviceInfo,
    };
  }

  factory Feedback.fromJson(Map<String, dynamic> json) {
    return Feedback(
      id: json['id'] as String?,
      userId: json['user_id'] as String,
      type: FeedbackTypeExtension.fromValue(json['type'] as String? ?? 'feedback'), // Added
      rating: json['rating'] as int?, // Updated (nullable)
      comment: json['comment'] as String?,
      screenshotUrl: json['screenshot_url'] as String?, // Added
      createdAt: DateTime.parse(json['created_at'] as String),
      deviceInfo: json['device_info'] as String,
    );
  }
}
