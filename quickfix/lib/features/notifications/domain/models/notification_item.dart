class NotificationItem {
  final String id;
  final String title;
  final String body;
  final String time;
  final String createdAt;
  final bool isRead;
  final String icon;
  final String iconColor;
  final String type;
  final String bookingId;
  final String deepLink;

  const NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    this.time = 'Just now',
    this.createdAt = '',
    this.isRead = false,
    this.icon = 'notifications_active',
    this.iconColor = 'primary',
    this.type = 'general',
    this.bookingId = '',
    this.deepLink = '',
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'] ?? json['_id'] ?? '';
    return NotificationItem(
      id: rawId.toString(),
      title: (json['title'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
      time: (json['time'] ?? json['createdAt'] ?? 'Just now').toString(),
      createdAt: (json['createdAt'] ?? json['time'] ?? '').toString(),
      isRead: json['isRead'] == true || json['isRead'] == 1,
      icon: (json['icon'] ?? 'notifications_active').toString(),
      iconColor: (json['iconColor'] ?? 'primary').toString(),
      type: (json['type'] ?? 'general').toString(),
      bookingId: (json['bookingId'] ?? '').toString(),
      deepLink: (json['deepLink'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'time': time,
      'createdAt': createdAt,
      'isRead': isRead,
      'icon': icon,
      'iconColor': iconColor,
      'type': type,
      'bookingId': bookingId,
      'deepLink': deepLink,
    };
  }

  NotificationItem copyWith({
    String? id,
    String? title,
    String? body,
    String? time,
    String? createdAt,
    bool? isRead,
    String? icon,
    String? iconColor,
    String? type,
    String? bookingId,
    String? deepLink,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      time: time ?? this.time,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      icon: icon ?? this.icon,
      iconColor: iconColor ?? this.iconColor,
      type: type ?? this.type,
      bookingId: bookingId ?? this.bookingId,
      deepLink: deepLink ?? this.deepLink,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          isRead == other.isRead;

  @override
  int get hashCode => id.hashCode ^ isRead.hashCode;
}
