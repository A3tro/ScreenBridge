import 'package:flutter/material.dart';
import 'app_icon.dart';
import 'category_illustration.dart';
import '../theme/app_theme.dart';
import '../utils/date_utils.dart';
import '../../models/models.dart';

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool secondary;
  PrimaryButton({super.key, required this.label, required this.onPressed, this.icon, this.secondary = false});
  @override Widget build(BuildContext context) => SizedBox(width: double.infinity, height: 56,
    child: FilledButton.icon(
      onPressed: onPressed,
      icon: icon == null ? SizedBox.shrink() : AppIcon(icon, size: 20),
      label: Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      style: FilledButton.styleFrom(
        backgroundColor: secondary ? AppPalette.of(context).surface : AppPalette.of(context).butter,
        foregroundColor: AppPalette.of(context).navy,
        elevation: 0,
        side: BorderSide(color: AppPalette.of(context).navy, width: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ));
}

class ScreenHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  ScreenHeader({super.key, required this.title, this.subtitle, this.trailing});
  @override Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(24, 18, 24, 20),
    child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        if (subtitle != null) ...[SizedBox(height: 5), Text(subtitle!, style: TextStyle(color: AppPalette.of(context).muted, fontSize: 13))],
      ])),
      if (trailing != null) trailing!,
    ]));
}

class SectionLabel extends StatelessWidget {
  final String title;
  final Widget? trailing;
  SectionLabel({super.key, required this.title, this.trailing});
  @override Widget build(BuildContext context) => Row(children: [
    Expanded(child: Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppPalette.of(context).navy))),
    if (trailing != null) trailing!,
  ]);
}

class SurfaceCard extends StatelessWidget {
  final Widget child;
  final Color? color;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  SurfaceCard({super.key, required this.child, this.color,
    this.padding = const EdgeInsets.all(18), this.onTap});
  @override Widget build(BuildContext context) => Material(
    color: color ?? AppPalette.of(context).surface, borderRadius: BorderRadius.circular(20), clipBehavior: Clip.antiAlias,
    child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
  );
}

class CategoryBadge extends StatelessWidget {
  final EventCategory category;
  CategoryBadge(this.category, {super.key});
  @override Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(color: category.background(context), borderRadius: BorderRadius.circular(9)),
    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    child: Text(category.label, style: TextStyle(fontSize: 11, color: category.foreground(context), fontWeight: FontWeight.w700)),
  );
}

class EventRow extends StatelessWidget {
  final ScheduleEvent event;
  final VoidCallback onTap;
  EventRow({super.key, required this.event, required this.onTap});
  @override Widget build(BuildContext context) => Material(color: Colors.transparent,
    child: InkWell(borderRadius: BorderRadius.circular(15), onTap: onTap, child: Padding(
      padding: EdgeInsets.symmetric(vertical: 12), child: Row(children: [
      Container(width: 47, height: 47, decoration: BoxDecoration(color: event.category.background(context), borderRadius: BorderRadius.circular(15)),
        child: CategoryArt(category: event.category, size: 42)),
      SizedBox(width: 13),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(event.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        SizedBox(height: 4),
        Text('${Dates.short(event.start)}  ${Dates.range(event.start,event.end)}',
          maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppPalette.of(context).muted, fontSize: 12)),
        if (event.location.isNotEmpty) Text(event.location, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(color: AppPalette.of(context).muted, fontSize: 11)),
      ])),
      if (!event.confirmed) AppIcon(Icons.error_outline_rounded, color: AppPalette.of(context).danger, size: 19),
      SizedBox(width: 4),
      AppIcon(Icons.chevron_right_rounded, color: AppPalette.of(context).muted, size: 21),
    ]))));
}

class DemoPill extends StatelessWidget {
  final String text;
  DemoPill({super.key, this.text = 'デモモード'});
  @override Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: AppPalette.of(context).butter, borderRadius: BorderRadius.circular(30)),
    child: Text(text, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 10, color: AppPalette.of(context).navy)));
}

class CategoryArt extends StatelessWidget {
  final EventCategory category;
  final double size;
  CategoryArt({super.key, required this.category, this.size = 44});
  @override Widget build(BuildContext context) => CategoryIllustration(category: category,
    width: size, height: size, animated: size > 80);
}

class Illustration extends StatelessWidget {
  final String name;
  final double height;
  Illustration(this.name, {super.key, this.height = 220});
  @override Widget build(BuildContext context) => Image.asset('assets/illustrations/$name.png', height: height,
    width: double.infinity, fit: BoxFit.contain,
    errorBuilder: (context, error, stackTrace) => SizedBox(height: height,
      child: Center(child: AppIcon(Icons.calendar_month_outlined, size: 76, color: AppPalette.of(context).sage))));
}

class PageFrame extends StatelessWidget {
  final Widget child;
  PageFrame({super.key, required this.child});
  @override Widget build(BuildContext context) => SafeArea(child: child);
}

void showDemoMessage(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text),
    backgroundColor: AppPalette.of(context).navy, behavior: SnackBarBehavior.floating, duration: Duration(seconds: 2)));
}
