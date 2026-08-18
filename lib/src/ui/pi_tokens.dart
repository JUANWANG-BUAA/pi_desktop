import 'package:flutter/material.dart';

enum PiDensity { compact, standard }

enum PiReadingFont { sans, serif }

/// Desktop tokens. Dark follows Cursor charcoal; light follows Cowork paper.
/// Accent is Claude terracotta. No purple, glow, or glass.
@immutable
class PiTokens extends ThemeExtension<PiTokens> {
  const PiTokens({
    required this.bg,
    required this.panel,
    required this.panelSoft,
    required this.line,
    required this.lineStrong,
    required this.text,
    required this.textSoft,
    required this.textFaint,
    required this.accent,
    required this.accentStrong,
    required this.signalOk,
    required this.signalWarn,
    required this.signalDanger,
    required this.density,
    required this.readingFont,
    required this.textScale,
  });

  final Color bg;
  final Color panel;
  final Color panelSoft;
  final Color line;
  final Color lineStrong;
  final Color text;
  final Color textSoft;
  final Color textFaint;
  final Color accent;
  final Color accentStrong;
  final Color signalOk;
  final Color signalWarn;
  final Color signalDanger;
  final PiDensity density;
  final PiReadingFont readingFont;
  final double textScale;

  // Font stacks start with the macOS families and fall back through common
  // Windows/Linux families before the generic CSS names, so typography keeps
  // its role on every platform instead of collapsing to the OS default.
  static const sansFallbacks = <String>[
    'SF Pro Text',
    'Segoe UI',
    'PingFang SC',
    'Microsoft YaHei',
    'Hiragino Sans GB',
    'Helvetica Neue',
    'Ubuntu',
    'Noto Sans',
    'Noto Sans SC',
    'sans-serif',
  ];

  static const serifFallbacks = <String>[
    'New York',
    'Iowan Old Style',
    'Palatino',
    'Cambria',
    'Songti SC',
    'Noto Serif SC',
    'STSong',
    'Georgia',
    'Noto Serif',
    'serif',
  ];

  static const monoFallbacks = <String>[
    'SF Mono',
    'Menlo',
    'Cascadia Code',
    'Cascadia Mono',
    'JetBrains Mono',
    'Consolas',
    'DejaVu Sans Mono',
    'Noto Sans Mono',
    'monospace',
  ];

  double get panePadding => density == PiDensity.compact ? 14 : 18;
  double get sectionGap => density == PiDensity.compact ? 14 : 18;
  double get radius => 10;
  double get composerRadius => 16;
  double get chipRadius => 8;
  double get readingSize =>
      (density == PiDensity.compact ? 14.5 : 15.5) * textScale;
  double get controlSize =>
      (density == PiDensity.compact ? 13 : 13.5) * textScale;
  double get microSize => 11;

  double get evidenceSize => density == PiDensity.compact ? 12 : 12.5;

  TextStyle get micro => TextStyle(
    fontFamily: 'SF Pro Text',
    fontFamilyFallback: sansFallbacks,
    fontSize: microSize,
    letterSpacing: 0.2,
    fontWeight: FontWeight.w600,
    color: textFaint,
    height: 1.2,
  );

  TextStyle get control => TextStyle(
    fontFamily: 'SF Pro Text',
    fontFamilyFallback: sansFallbacks,
    fontSize: controlSize,
    fontWeight: FontWeight.w500,
    color: text,
    height: 1.3,
  );

  TextStyle get reading => TextStyle(
    fontFamily: readingFont == PiReadingFont.serif ? 'New York' : 'SF Pro Text',
    fontFamilyFallback: readingFont == PiReadingFont.serif
        ? serifFallbacks
        : sansFallbacks,
    fontSize: readingSize,
    height: 1.65,
    color: text,
  );

  TextStyle get display => TextStyle(
    fontFamily: 'New York',
    fontFamilyFallback: serifFallbacks,
    fontSize: 32,
    height: 1.15,
    fontWeight: FontWeight.w500,
    color: text,
  );

  TextStyle get evidence => TextStyle(
    fontFamily: 'SF Mono',
    fontFamilyFallback: monoFallbacks,
    fontSize: evidenceSize,
    height: 1.45,
    color: text,
  );

  static PiTokens light(
    PiDensity density, {
    PiReadingFont readingFont = PiReadingFont.sans,
    double textScale = 1,
  }) {
    return PiTokens(
      bg: const Color(0xFFF7F7F5),
      panel: const Color(0xFFEEEEEC),
      panelSoft: const Color(0xFFE4E4E1),
      line: const Color(0xFFD6D6D2),
      lineStrong: const Color(0xFFC3C3BE),
      text: const Color(0xFF1A1A18),
      textSoft: const Color(0xFF5C5C57),
      textFaint: const Color(0xFF8A8A84),
      accent: const Color(0xFFC96442),
      accentStrong: const Color(0xFFD97757),
      signalOk: const Color(0xFF3F6F4A),
      signalWarn: const Color(0xFF9A7428),
      signalDanger: const Color(0xFFB42318),
      density: density,
      readingFont: readingFont,
      textScale: textScale,
    );
  }

  static PiTokens dark(
    PiDensity density, {
    PiReadingFont readingFont = PiReadingFont.sans,
    double textScale = 1,
  }) {
    return PiTokens(
      // Layering follows the Claude desktop dark surfaces: a charcoal
      // workspace, one raised navigation plane, then restrained controls.
      bg: const Color(0xFF1C1C1B),
      panel: const Color(0xFF232322),
      panelSoft: const Color(0xFF2A2A29),
      line: const Color(0xFF363634),
      lineStrong: const Color(0xFF474744),
      text: const Color(0xFFF4F3F0),
      textSoft: const Color(0xFFB1B0AC),
      textFaint: const Color(0xFF83827D),
      accent: const Color(0xFFD97757),
      accentStrong: const Color(0xFFE38A6B),
      signalOk: const Color(0xFF3FA66B),
      signalWarn: const Color(0xFFD4A017),
      signalDanger: const Color(0xFFE5484D),
      density: density,
      readingFont: readingFont,
      textScale: textScale,
    );
  }

  static PiTokens of(BuildContext context) {
    return Theme.of(context).extension<PiTokens>() ??
        PiTokens.dark(PiDensity.standard);
  }

  @override
  PiTokens copyWith({
    PiDensity? density,
    PiReadingFont? readingFont,
    double? textScale,
  }) {
    return PiTokens(
      bg: bg,
      panel: panel,
      panelSoft: panelSoft,
      line: line,
      lineStrong: lineStrong,
      text: text,
      textSoft: textSoft,
      textFaint: textFaint,
      accent: accent,
      accentStrong: accentStrong,
      signalOk: signalOk,
      signalWarn: signalWarn,
      signalDanger: signalDanger,
      density: density ?? this.density,
      readingFont: readingFont ?? this.readingFont,
      textScale: textScale ?? this.textScale,
    );
  }

  @override
  PiTokens lerp(ThemeExtension<PiTokens>? other, double t) {
    if (other is! PiTokens) {
      return this;
    }
    return t < 0.5 ? this : other;
  }
}

ThemeData buildPiTheme({
  required Brightness brightness,
  required PiDensity density,
  PiReadingFont readingFont = PiReadingFont.sans,
  double textScale = 1,
}) {
  final tokens = brightness == Brightness.dark
      ? PiTokens.dark(density, readingFont: readingFont, textScale: textScale)
      : PiTokens.light(density, readingFont: readingFont, textScale: textScale);
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    visualDensity: density == PiDensity.compact
        ? VisualDensity.compact
        : VisualDensity.standard,
  );

  final scheme = ColorScheme(
    brightness: brightness,
    primary: tokens.accent,
    onPrimary: brightness == Brightness.dark
        ? const Color(0xFF1A1410)
        : const Color(0xFFFAF8F4),
    secondary: tokens.textSoft,
    onSecondary: tokens.bg,
    error: tokens.signalDanger,
    onError: tokens.panel,
    surface: tokens.panel,
    onSurface: tokens.text,
    onSurfaceVariant: tokens.textSoft,
    outline: tokens.line,
    outlineVariant: tokens.lineStrong,
    surfaceContainer: tokens.panelSoft,
    surfaceContainerHighest: tokens.panelSoft,
  );

  return base.copyWith(
    scaffoldBackgroundColor: tokens.bg,
    colorScheme: scheme,
    dividerColor: tokens.line,
    extensions: <ThemeExtension<dynamic>>[tokens],
    splashFactory: NoSplash.splashFactory,
    highlightColor: tokens.accent.withValues(alpha: 0.08),
    hoverColor: tokens.accent.withValues(alpha: 0.06),
    focusColor: tokens.accent.withValues(alpha: 0.16),
    textTheme: base.textTheme.apply(
      fontFamily: 'SF Pro Text',
      bodyColor: tokens.text,
      displayColor: tokens.text,
    ),
    iconTheme: IconThemeData(color: tokens.textSoft, size: 16),
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 400),
      decoration: BoxDecoration(
        color: tokens.panelSoft,
        border: Border.all(color: tokens.line),
        borderRadius: BorderRadius.circular(tokens.chipRadius),
      ),
      textStyle: tokens.control.copyWith(fontSize: 12, color: tokens.text),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: tokens.panelSoft,
      contentTextStyle: tokens.control,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: tokens.line),
        borderRadius: BorderRadius.circular(tokens.radius),
      ),
      behavior: SnackBarBehavior.floating,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: tokens.panel,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: tokens.line),
        borderRadius: BorderRadius.circular(tokens.composerRadius),
      ),
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      menuStyle: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(tokens.panel),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        side: WidgetStatePropertyAll(BorderSide(color: tokens.line)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.radius),
          ),
        ),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: tokens.panel,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: tokens.line),
        borderRadius: BorderRadius.circular(tokens.radius),
      ),
      textStyle: tokens.control,
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(tokens.panel),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shadowColor: WidgetStatePropertyAll(
          Colors.black.withValues(alpha: 0.28),
        ),
        side: WidgetStatePropertyAll(BorderSide(color: tokens.line)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.radius),
          ),
        ),
      ),
    ),
    tabBarTheme: TabBarThemeData(
      dividerColor: tokens.line,
      indicatorColor: tokens.accent,
      labelColor: tokens.text,
      unselectedLabelColor: tokens.textFaint,
      labelStyle: tokens.control.copyWith(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: tokens.control.copyWith(fontSize: 12.5),
      overlayColor: WidgetStatePropertyAll(
        tokens.accent.withValues(alpha: 0.08),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: tokens.panelSoft,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tokens.radius),
        borderSide: BorderSide(color: tokens.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tokens.radius),
        borderSide: BorderSide(color: tokens.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tokens.radius),
        borderSide: BorderSide(color: tokens.accent, width: 1),
      ),
      contentPadding: EdgeInsets.symmetric(
        horizontal: density == PiDensity.compact ? 12 : 14,
        vertical: density == PiDensity.compact ? 10 : 12,
      ),
      hintStyle: tokens.control.copyWith(color: tokens.textFaint),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStatePropertyAll(tokens.text),
        side: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.focused)) {
            return BorderSide(color: tokens.accent);
          }
          return BorderSide(color: tokens.lineStrong);
        }),
        padding: WidgetStatePropertyAll(
          EdgeInsets.symmetric(
            horizontal: density == PiDensity.compact ? 10 : 12,
            vertical: density == PiDensity.compact ? 8 : 10,
          ),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.chipRadius),
          ),
        ),
        textStyle: WidgetStatePropertyAll(tokens.control),
        overlayColor: WidgetStatePropertyAll(
          tokens.accent.withValues(alpha: 0.08),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStatePropertyAll(tokens.accent),
        textStyle: WidgetStatePropertyAll(tokens.control),
        overlayColor: WidgetStatePropertyAll(
          tokens.accent.withValues(alpha: 0.08),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.chipRadius),
          ),
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return tokens.panelSoft;
          }
          return tokens.accent;
        }),
        foregroundColor: WidgetStatePropertyAll(scheme.onPrimary),
        textStyle: WidgetStatePropertyAll(tokens.control),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.chipRadius),
          ),
        ),
        elevation: const WidgetStatePropertyAll(0),
        overlayColor: WidgetStatePropertyAll(
          tokens.accentStrong.withValues(alpha: 0.16),
        ),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: tokens.textSoft,
        hoverColor: tokens.panelSoft,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.chipRadius),
        ),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return tokens.accent;
        }
        return tokens.textFaint;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return tokens.accent.withValues(alpha: 0.35);
        }
        return tokens.panelSoft;
      }),
      trackOutlineColor: WidgetStatePropertyAll(tokens.line),
    ),
    expansionTileTheme: ExpansionTileThemeData(
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.zero,
      iconColor: tokens.textSoft,
      collapsedIconColor: tokens.textFaint,
      shape: const Border(),
      collapsedShape: const Border(),
    ),
    dividerTheme: DividerThemeData(color: tokens.line, space: 1, thickness: 1),
    scrollbarTheme: ScrollbarThemeData(
      thickness: const WidgetStatePropertyAll(7),
      radius: const Radius.circular(8),
      thumbColor: WidgetStatePropertyAll(tokens.lineStrong),
    ),
  );
}
