import 'package:wayhunter_mobile/core/network/api_client.dart';

bool isNotificationId(String value) =>
    value != '00000000-0000-0000-0000-000000000000' &&
    RegExp(
      r'^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$',
      caseSensitive: false,
    ).hasMatch(value);

enum NotificationCategory {
  trip(1, 'Trip', 'Trip reminder'),
  safety(2, 'Safety', 'Safety update'),
  social(3, 'Social', 'Social update'),
  hunter(4, 'Hunter', 'Hunter review update'),
  game(5, 'Game', 'Game review update'),
  coins(6, 'Coins', 'Coins update'),
  voucher(7, 'Voucher', 'Voucher update');

  const NotificationCategory(this.code, this.label, this.templateTitle);
  final int code;
  final String label;
  final String templateTitle;

  static NotificationCategory? fromCode(int code) =>
      values.where((category) => category.code == code).firstOrNull;
}

class InboxItem {
  const InboxItem({
    required this.eventId,
    required this.category,
    required this.template,
    required this.templateVersion,
    required this.createdAtUtc,
    required this.readAtUtc,
    required this.target,
  });

  final String eventId;
  final NotificationCategory? category;
  final int template;
  final int templateVersion;
  final DateTime createdAtUtc;
  final DateTime? readAtUtc;
  final ({int category, String id})? target;

  bool get isRead => readAtUtc != null;

  bool get _knownTemplate => templateVersion == 1 && template == category?.code;
  String get title => _knownTemplate ? category!.templateTitle : 'Notification';

  String? get tripPlanId {
    if (_knownTemplate &&
        category == NotificationCategory.trip &&
        target?.category == NotificationCategory.trip.code) {
      return target!.id;
    }
    return null;
  }

  factory InboxItem.fromJson(Object? json) {
    if (json case {
      'eventId': final String id,
      'category': final int category,
      'template': final int template,
      'templateVersion': final int version,
      'createdAtUtc': final String created,
      'readAtUtc': final String? read,
      'target': final Object? rawTarget,
    } when isNotificationId(id) && version > 0) {
      final start = DateTime.tryParse(created);
      final seen = read == null ? null : DateTime.tryParse(read);
      if (start?.isUtc == true && (read == null || seen?.isUtc == true)) {
        final target = switch (rawTarget) {
          {'category': final int targetCategory, 'id': final String targetId}
              when isNotificationId(targetId) =>
            (category: targetCategory, id: targetId),
          _ => null,
        };
        return InboxItem(
          eventId: id,
          category: NotificationCategory.fromCode(category),
          template: template,
          templateVersion: version,
          createdAtUtc: start!,
          readAtUtc: seen,
          target: target,
        );
      }
    }
    throw const ApiException(ApiError.invalidResponse);
  }
}

class InboxPage {
  const InboxPage(this.items, this.unreadCount);
  final List<InboxItem> items;
  final int unreadCount;

  factory InboxPage.fromJson(Object? json) {
    if (json case {
      'items': final List<Object?> items,
      'unreadCount': final int count,
    } when count >= 0) {
      final rows = items.map(InboxItem.fromJson).toList(growable: false);
      if (rows.map((row) => row.eventId.toLowerCase()).toSet().length ==
          rows.length) {
        return InboxPage(List.unmodifiable(rows), count);
      }
    }
    throw const ApiException(ApiError.invalidResponse);
  }
}

class NotificationPreference {
  const NotificationPreference(this.category, this.pushEnabled);
  final NotificationCategory category;
  final bool pushEnabled;

  static NotificationPreference? fromJson(Object? json) {
    if (json case {
      'category': final int code,
      'pushEnabled': final bool enabled,
    }) {
      final category = NotificationCategory.fromCode(code);
      return category == null
          ? null
          : NotificationPreference(category, enabled);
    }
    throw const ApiException(ApiError.invalidResponse);
  }
}
