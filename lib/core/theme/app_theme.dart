import 'package:flutter/material.dart';
import '../widgets/motion.dart';

// Stable category accents, also used on illustration canvases.
class AppColors {
  static const ivory = Color(0xFFFFFCF5);
  static const navy = Color(0xFF202321);
  static const sage = Color(0xFF245C4B);
  static const mint = Color(0xFFAAD5BA);
  static const peach = Color(0xFFF8D9CE);
  static const lavender = Color(0xFFCBC4F5);
  static const butter = Color(0xFFFFDF96);
  static const muted = Color(0xFF666B68);
  static const surface = Colors.white;
  static const paleBlue = Color(0xFFDAEAF4);
  static const line = Color(0xFFE8E4DF);
  static const danger = Color(0xFFAD4F43);
}

@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  final Color ivory, navy, sage, mint, peach, lavender, butter, muted, surface, paleBlue, line, danger;
  const AppPalette({required this.ivory, required this.navy, required this.sage, required this.mint,
    required this.peach, required this.lavender, required this.butter, required this.muted,
    required this.surface, required this.paleBlue, required this.line, required this.danger});
  static const light = AppPalette(ivory: AppColors.ivory, navy: AppColors.navy, sage: AppColors.sage,
    mint: AppColors.mint, peach: AppColors.peach, lavender: AppColors.lavender, butter: AppColors.butter,
    muted: AppColors.muted, surface: AppColors.surface, paleBlue: AppColors.paleBlue, line: AppColors.line, danger: AppColors.danger);
  static const dark = AppPalette(ivory: Color(0xFF18191E), navy: Color(0xFFF3F0F7), sage: Color(0xFFA9DFBF),
    mint: Color(0xFF294B3C), peach: Color(0xFF533D40), lavender: Color(0xFF45405F), butter: Color(0xFF665333),
    muted: Color(0xFFBBB7C4), surface: Color(0xFF25262E), paleBlue: Color(0xFF304856), line: Color(0xFF41424E), danger: Color(0xFFFFA695));
  static AppPalette of(BuildContext context) => Theme.of(context).extension<AppPalette>() ?? light;
  @override AppPalette copyWith() => this;
  @override AppPalette lerp(covariant AppPalette? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(ivory: mix(ivory, other.ivory), navy: mix(navy, other.navy), sage: mix(sage, other.sage),
      mint: mix(mint, other.mint), peach: mix(peach, other.peach), lavender: mix(lavender, other.lavender),
      butter: mix(butter, other.butter), muted: mix(muted, other.muted), surface: mix(surface, other.surface),
      paleBlue: mix(paleBlue, other.paleBlue), line: mix(line, other.line), danger: mix(danger, other.danger));
  }
}

class AppTheme {
  static ThemeData light() => _build(false);
  static ThemeData dark() => _build(true);
  static ThemeData _build(bool dark) {
    final p = dark ? AppPalette.dark : AppPalette.light;
    final scheme = ColorScheme.fromSeed(seedColor: p.sage,
      brightness: dark ? Brightness.dark : Brightness.light, surface: p.surface);
    return ThemeData(useMaterial3: true, colorScheme: scheme, extensions: [p],
      scaffoldBackgroundColor: p.ivory, fontFamily: 'sans-serif',
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: GentlePageTransitions(), TargetPlatform.iOS: GentlePageTransitions(),
        TargetPlatform.macOS: GentlePageTransitions(), TargetPlatform.windows: GentlePageTransitions(),
        TargetPlatform.linux: GentlePageTransitions(), TargetPlatform.fuchsia: GentlePageTransitions(),
      }),
      appBarTheme: AppBarTheme(backgroundColor: p.ivory, foregroundColor: p.navy, centerTitle: false, elevation: 0, scrolledUnderElevation: 0),
      textTheme: TextTheme(
        displaySmall: TextStyle(fontSize: 42, fontWeight: FontWeight.w700, height: 1.12, letterSpacing: -1.5, color: p.navy),
        headlineMedium: TextStyle(fontSize: 29, fontWeight: FontWeight.w700, height: 1.22, letterSpacing: -.7, color: p.navy),
        headlineSmall: TextStyle(fontSize: 23, fontWeight: FontWeight.w700, color: p.navy),
        titleLarge: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: p.navy),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: p.navy),
        bodyLarge: TextStyle(fontSize: 15, height: 1.5, color: p.navy),
        bodyMedium: TextStyle(fontSize: 14, height: 1.45, color: p.navy),
        bodySmall: TextStyle(fontSize: 12, color: p.muted)),
      inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: p.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: p.line)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: p.line)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: p.sage, width: 1.6))),
      dividerColor: p.line, iconTheme: IconThemeData(color: p.navy),
      snackBarTheme: SnackBarThemeData(backgroundColor: p.navy, contentTextStyle: TextStyle(color: p.ivory)),
    );
  }
}
