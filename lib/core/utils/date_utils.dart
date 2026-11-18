import 'package:flutter/material.dart';

class Dates {
  static const weekdays = ['月', '火', '水', '木', '金', '土', '日'];
  static String time(DateTime date) => '${_two(date.hour)}:${_two(date.minute)}';
  static String date(DateTime date) => '${date.year}年${date.month}月${date.day}日（${weekdays[date.weekday - 1]}）';
  static String short(DateTime date) => '${date.month}/${date.day}（${weekdays[date.weekday - 1]}）';
  static String _two(int x) => x.toString().padLeft(2, '0');
  static DateTime only(DateTime day) => DateTime(day.year, day.month, day.day);
  static bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
  static String range(DateTime start, DateTime end) => '${time(start)} – ${time(end)}${sameDay(start,end) ? '' : '（翌日）'}';
  static String relative(DateTime date) {
    final delta = Dates.only(date).difference(Dates.only(DateTime.now())).inDays;
    if (delta == 0) return '今日';
    if (delta == 1) return '明日';
    if (delta == -1) return '昨日';
    return short(date);
  }
  static DateTime combine(DateTime day, TimeOfDay time) => DateTime(day.year, day.month, day.day, time.hour, time.minute);
}
