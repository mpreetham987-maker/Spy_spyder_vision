import 'package:flutter/material.dart';

/// Central place for every fixed value used across the app.
///
/// Keeping these here (instead of scattered magic numbers) means the
/// design language — spacing, radii, timing — stays consistent and is
/// trivial to retune from a single file.
class AppConstants {
  AppConstants._();

  // ---------------------------------------------------------------------
  // Brand
  // ---------------------------------------------------------------------
  static const String appName = 'SPY SPIDER VISION';
  static const String appTagline = 'TACTICAL ROBOTICS CONTROL SYSTEM';

  // ---------------------------------------------------------------------
  // Corner radii (per design spec: 20–28px)
  // ---------------------------------------------------------------------
  static const double radiusSmall = 16.0;
  static const double radiusMedium = 20.0;
  static const double radiusLarge = 24.0;
  static const double radiusXLarge = 28.0;

  // ---------------------------------------------------------------------
  // Spacing
  // ---------------------------------------------------------------------
  static const double spaceXs = 4.0;
  static const double spaceSm = 8.0;
  static const double spaceMd = 16.0;
  static const double spaceLg = 24.0;
  static const double spaceXl = 32.0;
  static const double spaceXxl = 48.0;

  // ---------------------------------------------------------------------
  // Animation durations
  // ---------------------------------------------------------------------
  static const Duration animFast = Duration(milliseconds: 200);
  static const Duration animMedium = Duration(milliseconds: 400);
  static const Duration animSlow = Duration(milliseconds: 700);
  static const Duration splashDuration = Duration(milliseconds: 2600);

  // ---------------------------------------------------------------------
  // Networking defaults
  // ---------------------------------------------------------------------
  static const String defaultCameraUrlHint = 'http://192.168.4.1:81/stream';
  static const Duration httpTimeout = Duration(seconds: 6);
  static const Duration statusPollInterval = Duration(seconds: 2);

  // ---------------------------------------------------------------------
  // Servo configuration
  // ---------------------------------------------------------------------
  static const int servoMin = 0;
  static const int servoMax = 180;

  /// Max rate at which drag-time slider updates are transmitted over
  /// Bluetooth (servo angles, walking speed). The UI itself still
  /// redraws every frame; this only caps outbound serial writes so 8
  /// simultaneous servo sliders can't flood the link. ~20/sec.
  static const Duration sliderSendInterval = Duration(milliseconds: 50);
  static const int servoDefault = 90;

  /// Maps each leg to its two servo channel IDs, matching the
  /// hardware wiring described in the command protocol (S1..S8).
  static const Map<String, List<int>> legServoMap = {
    'Front Left': [1, 2],
    'Front Right': [3, 4],
    'Rear Left': [5, 6],
    'Rear Right': [7, 8],
  };
}

/// Legacy flat palette — kept as static consts so widgets that haven't
/// been migrated to [AppPalette] (below) still compile and still get
/// the new "Royal Midnight" jewel-tone look, since these constants now
/// point at the dark-mode royal colors instead of the old charcoal/cyan
/// scheme. New or touched widgets should prefer `context.palette.*`,
/// which is brightness-aware and drives real Light/Dark switching.
class AppColors {
  AppColors._();

  // Backgrounds
  static const Color charcoal = Color(0xFF0B0A16);
  static const Color charcoalElevated = Color(0xFF13111F);
  static const Color charcoalCard = Color(0xFF1B1830);
  static const Color charcoalCardHigh = Color(0xFF241F3D);

  // Accent — royal gold (primary) + amethyst (secondary)
  static const Color cyan = Color(0xFFD8B75B); // gold, kept name for compat
  static const Color cyanDim = Color(0xFF9C7C2E);
  static const Color amethyst = Color(0xFF9D7BFF);
  static const Color amethystDim = Color(0xFF5B3FA0);

  // Semantic status — used ONLY for their designated meaning
  static const Color statusConnected = Color(0xFF2ED9A5); // emerald
  static const Color statusWarning = Color(0xFFFFB454); // amber
  static const Color statusEmergency = Color(0xFFFF5470); // ruby

  // Text
  static const Color textPrimary = Color(0xFFF6F1FF);
  static const Color textSecondary = Color(0xFFB4A9D6);
  static const Color textTertiary = Color(0xFF7A6FA0);

  // Glass / stroke
  static const Color glassStroke = Color(0x33D8B75B);
  static const Color glassFill = Color(0x14FFFFFF);
  static const Color divider = Color(0x1FD8B75B);
}

/// Brightness-aware "Royal" palette, exposed via a [ThemeExtension] so
/// the Light/Dark Mode toggle in Settings actually reskins the app
/// instead of just flipping a couple of surface colors.
///
/// Jewel-tone identity: deep indigo/obsidian base, royal gold as the
/// primary accent, amethyst as the secondary accent, emerald reserved
/// for the "connected" status — replacing the old blue/red-only scheme.
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.backgroundGradient,
    required this.surface,
    required this.surfaceHigh,
    required this.glassFill,
    required this.glassStroke,
    required this.divider,
    required this.gold,
    required this.goldDim,
    required this.amethyst,
    required this.amethystDim,
    required this.emerald,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.statusConnected,
    required this.statusWarning,
    required this.statusEmergency,
    required this.shadow,
  });

  final List<Color> backgroundGradient;
  final Color surface;
  final Color surfaceHigh;
  final Color glassFill;
  final Color glassStroke;
  final Color divider;
  final Color gold;
  final Color goldDim;
  final Color amethyst;
  final Color amethystDim;
  final Color emerald;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color statusConnected;
  final Color statusWarning;
  final Color statusEmergency;
  final Color shadow;

  /// "Royal Midnight" — obsidian-indigo base, gold + amethyst jewel accents.
  static const dark = AppPalette(
    backgroundGradient: [Color(0xFF0B0A16), Color(0xFF15122A), Color(0xFF0B0A16)],
    surface: Color(0xFF1B1830),
    surfaceHigh: Color(0xFF241F3D),
    glassFill: Color(0x14FFFFFF),
    glassStroke: Color(0x33D8B75B),
    divider: Color(0x1FD8B75B),
    gold: Color(0xFFD8B75B),
    goldDim: Color(0xFF9C7C2E),
    amethyst: Color(0xFF9D7BFF),
    amethystDim: Color(0xFF5B3FA0),
    emerald: Color(0xFF2ED9A5),
    textPrimary: Color(0xFFF6F1FF),
    textSecondary: Color(0xFFB4A9D6),
    textTertiary: Color(0xFF7A6FA0),
    statusConnected: Color(0xFF2ED9A5),
    statusWarning: Color(0xFFFFB454),
    statusEmergency: Color(0xFFFF5470),
    shadow: Color(0x66000000),
  );

  /// "Royal Ivory" — warm pearl/parchment base, deep plum text, same
  /// gold + amethyst jewel accents so the brand reads consistently in
  /// both modes.
  static const light = AppPalette(
    backgroundGradient: [Color(0xFFFBF7EF), Color(0xFFF1E9D8), Color(0xFFFBF7EF)],
    surface: Color(0xFFFFFFFF),
    surfaceHigh: Color(0xFFF6EFDF),
    glassFill: Color(0xB3FFFFFF),
    glassStroke: Color(0x40B4923E),
    divider: Color(0x33B4923E),
    gold: Color(0xFFAD7E1E),
    goldDim: Color(0xFF8A651A),
    amethyst: Color(0xFF6E48C9),
    amethystDim: Color(0xFF4E3392),
    emerald: Color(0xFF1E9E76),
    textPrimary: Color(0xFF241C3D),
    textSecondary: Color(0xFF544A72),
    textTertiary: Color(0xFF7C7196),
    statusConnected: Color(0xFF1E9E76),
    statusWarning: Color(0xFFB4700F),
    statusEmergency: Color(0xFFD62E4E),
    shadow: Color(0x1F241C3D),
  );

  @override
  AppPalette copyWith({
    List<Color>? backgroundGradient,
    Color? surface,
    Color? surfaceHigh,
    Color? glassFill,
    Color? glassStroke,
    Color? divider,
    Color? gold,
    Color? goldDim,
    Color? amethyst,
    Color? amethystDim,
    Color? emerald,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? statusConnected,
    Color? statusWarning,
    Color? statusEmergency,
    Color? shadow,
  }) {
    return AppPalette(
      backgroundGradient: backgroundGradient ?? this.backgroundGradient,
      surface: surface ?? this.surface,
      surfaceHigh: surfaceHigh ?? this.surfaceHigh,
      glassFill: glassFill ?? this.glassFill,
      glassStroke: glassStroke ?? this.glassStroke,
      divider: divider ?? this.divider,
      gold: gold ?? this.gold,
      goldDim: goldDim ?? this.goldDim,
      amethyst: amethyst ?? this.amethyst,
      amethystDim: amethystDim ?? this.amethystDim,
      emerald: emerald ?? this.emerald,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      statusConnected: statusConnected ?? this.statusConnected,
      statusWarning: statusWarning ?? this.statusWarning,
      statusEmergency: statusEmergency ?? this.statusEmergency,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      backgroundGradient: [
        for (var i = 0; i < backgroundGradient.length; i++)
          c(backgroundGradient[i], other.backgroundGradient[i]),
      ],
      surface: c(surface, other.surface),
      surfaceHigh: c(surfaceHigh, other.surfaceHigh),
      glassFill: c(glassFill, other.glassFill),
      glassStroke: c(glassStroke, other.glassStroke),
      divider: c(divider, other.divider),
      gold: c(gold, other.gold),
      goldDim: c(goldDim, other.goldDim),
      amethyst: c(amethyst, other.amethyst),
      amethystDim: c(amethystDim, other.amethystDim),
      emerald: c(emerald, other.emerald),
      textPrimary: c(textPrimary, other.textPrimary),
      textSecondary: c(textSecondary, other.textSecondary),
      textTertiary: c(textTertiary, other.textTertiary),
      statusConnected: c(statusConnected, other.statusConnected),
      statusWarning: c(statusWarning, other.statusWarning),
      statusEmergency: c(statusEmergency, other.statusEmergency),
      shadow: c(shadow, other.shadow),
    );
  }
}

/// `context.palette.gold` instead of `Theme.of(context).extension<AppPalette>()!.gold`.
extension AppPaletteX on BuildContext {
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.dark;
}
