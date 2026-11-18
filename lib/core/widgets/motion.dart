import 'package:flutter/material.dart';

class GentlePageTransitions extends PageTransitionsBuilder {
  const GentlePageTransitions();
  @override Widget buildTransitions<T>(PageRoute<T> route, BuildContext context,
      Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    if (MediaQuery.of(context).disableAnimations) return child;
    final ease = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
    return FadeTransition(opacity: ease, child: SlideTransition(
      position: Tween<Offset>(begin: const Offset(.055, .025), end: Offset.zero).animate(ease), child: child));
  }
}

/// Pointer animation only; the child retains keyboard, focus and semantics.
class PressScale extends StatefulWidget {
  final Widget child;
  const PressScale({super.key, required this.child});
  @override State<PressScale> createState() => _PressScaleState();
}
class _PressScaleState extends State<PressScale> {
  bool down = false;
  @override Widget build(BuildContext context) => Listener(
    onPointerDown: (_) => setState(() => down = true),
    onPointerUp: (_) => setState(() => down = false),
    onPointerCancel: (_) => setState(() => down = false),
    child: AnimatedScale(scale: down && !MediaQuery.of(context).disableAnimations ? .9 : 1,
      duration: const Duration(milliseconds: 130), curve: Curves.easeOut, child: widget.child));
}
