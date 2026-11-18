import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

enum EventCategory { work, school, personal, exam, travel }

extension EventCategoryStyle on EventCategory {
  Color background(BuildContext context) {
    final p = AppPalette.of(context);
    return switch (this) { EventCategory.work => p.mint, EventCategory.school => p.lavender,
      EventCategory.personal => p.peach, EventCategory.exam => p.butter, EventCategory.travel => p.paleBlue };
  }
  Color foreground(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? AppPalette.of(context).navy : strong;
  String get label => switch (this) {
    EventCategory.work => 'アルバイト',
    EventCategory.school => '学校',
    EventCategory.personal => 'プライベート',
    EventCategory.exam => '試験',
    EventCategory.travel => 'お出かけ',
  };
  Color get tint => switch (this) {
    EventCategory.work => AppColors.mint,
    EventCategory.school => AppColors.lavender,
    EventCategory.personal => AppColors.peach,
    EventCategory.exam => AppColors.butter,
    EventCategory.travel => AppColors.paleBlue,
  };
  Color get strong => switch (this) {
    EventCategory.work => AppColors.sage,
    EventCategory.school => const Color(0xFF554577),
    EventCategory.personal => const Color(0xFF7E4538),
    EventCategory.exam => const Color(0xFF6B501B),
    EventCategory.travel => const Color(0xFF2E596C),
  };
  IconData get icon => switch (this) {
    EventCategory.work => Icons.work_outline_rounded,
    EventCategory.school => Icons.school_outlined,
    EventCategory.personal => Icons.favorite_border_rounded,
    EventCategory.exam => Icons.auto_stories_outlined,
    EventCategory.travel => Icons.explore_outlined,
  };
}

class AppUser {
  final String name;
  final String email;
  const AppUser({required this.name, required this.email});
}

class ScheduleEvent {
  final String id;
  final String title;
  final DateTime start;
  final DateTime end;
  final EventCategory category;
  final String location;
  final String notes;
  final String source;
  final bool confirmed;
  final bool allDay;
  final String reminder;
  final List<String> history;
  const ScheduleEvent({required this.id, required this.title, required this.start, required this.end, required this.category,
    this.location = '', this.notes = '', this.source = '', this.confirmed = true, this.allDay = false,
    this.reminder = 'なし', this.history = const []});
  ScheduleEvent copyWith({String? id, String? title, DateTime? start, DateTime? end, EventCategory? category,
    String? location, String? notes, String? source, bool? confirmed, bool? allDay, String? reminder, List<String>? history}) =>
    ScheduleEvent(id: id ?? this.id, title: title ?? this.title, start: start ?? this.start, end: end ?? this.end,
      category: category ?? this.category, location: location ?? this.location, notes: notes ?? this.notes,
      source: source ?? this.source, confirmed: confirmed ?? this.confirmed, allDay: allDay ?? this.allDay,
      reminder: reminder ?? this.reminder, history: history ?? this.history);
}

class ImportRecord {
  final String title;
  final DateTime createdAt;
  final int count;
  const ImportRecord(this.title, this.createdAt, this.count);
}

class ExtractedEventCandidate {
  final String id;
  ScheduleEvent event;
  bool selected;
  String? uncertainty;
  ExtractedEventCandidate({required this.id, required this.event, this.selected = true, this.uncertainty});
}

enum ChangeKind { modified, duplicate, overlap, cancellation, missingDate, uncertain }

class ScheduleChange {
  final String id;
  final String eventId;
  final ChangeKind kind;
  final DateTime? newStart;
  final DateTime? newEnd;
  final String message;
  bool resolved;
  ScheduleChange({required this.id, required this.eventId, required this.kind, this.newStart, this.newEnd,
    required this.message, this.resolved = false});
}

class NotificationItem {
  final String id;
  final String title;
  final String message;
  final DateTime createdAt;
  final IconData icon;
  final String target;
  bool read;
  NotificationItem({required this.id, required this.title, required this.message, required this.createdAt,
    required this.icon, required this.target, this.read = false});
}
