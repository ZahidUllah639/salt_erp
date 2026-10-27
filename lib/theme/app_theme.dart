import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centralized Enterprise Design Tokens for Anwar Salt Factory ERP.
/// Follows modern Windows desktop enterprise conventions: clean slate/navy foundation,
/// cobalt primary accents, high contrast typography, and restrained depth.
class AppColors {
  // Brand & Foundation
  static const Color brandPrimary = Color(0xFF2563EB); // Cobalt Blue
  static const Color brandDark = Color(0xFF1D4ED8);
  static const Color brandLight = Color(0xFFEFF6FF);
  static const Color brandMuted = Color(0xFFDBEAFE);

  // Surfaces & Backgrounds
  static const Color background = Color(0xFFF8FAFC); // Slate 50
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF1F5F9); // Slate 100
  static const Color surfaceHover = Color(0xFFF8FAFC);
  static const Color tableHeaderBg = Color(0xFFF1F5F9); // Slate 100

  // Dark Windows Surfaces (Sidebar & Headers)
  static const Color sidebarNavy = Color(0xFF0F172A); // Slate 900
  static const Color sidebarNavyAlt = Color(0xFF1E293B); // Slate 800
  static const Color heroNavy = Color(0xFF0F172A);
  static const Color summaryNavy = Color(0xFF1E293B);

  // Typography & Text
  static const Color textPrimary = Color(0xFF0F172A); // Slate 900
  static const Color textSecondary = Color(0xFF334155); // Slate 700
  static const Color textMuted = Color(0xFF64748B); // Slate 500
  static const Color textSubtle = Color(0xFF94A3B8); // Slate 400
  static const Color textInverse = Color(0xFFF8FAFC);

  // Borders & Dividers
  static const Color border = Color(0xFFE2E8F0); // Slate 200
  static const Color borderLight = Color(0xFFF1F5F9); // Slate 100
  static const Color borderStrong = Color(0xFFCBD5E1); // Slate 300
  static const Color focusRing = Color(0xFF93C5FD); // Blue 300

  // Semantic Status Colors
  // Green (Healthy / Paid / Reconciled / Positive)
  static const Color success = Color(0xFF16A34A); // Green 600
  static const Color successBg = Color(0xFFF0FDF4); // Green 50
  static const Color successBorder = Color(0xFFDCFCE7);
  static const Color successText = Color(0xFF15803D);

  // Red (Danger / Negative stock / Overdue / Outflow)
  static const Color danger = Color(0xFFDC2626); // Red 600
  static const Color dangerBg = Color(0xFFFEF2F2); // Red 50
  static const Color dangerBorder = Color(0xFFFEE2E2);
  static const Color dangerText = Color(0xFFB91C1C);

  // Amber / Orange (Warning / Low stock / Pending / Partial)
  static const Color warning = Color(0xFFD97706); // Amber 600
  static const Color warningBg = Color(0xFFFFFBEB); // Amber 50
  static const Color warningBorder = Color(0xFFFEF3C7);
  static const Color warningText = Color(0xFFB45309);

  // Purple / Violet (Production / Packaging)
  static const Color violet = Color(0xFF7C3AED); // Violet 600
  static const Color violetBg = Color(0xFFF5F3FF); // Violet 50
  static const Color violetBorder = Color(0xFFEDE9FE);

  // Brown / Earth (Raw Salt)
  static const Color rawSalt = Color(0xFF8A6848);
  static const Color rawSaltBg = Color(0xFFFBF8F5);
  static const Color rawSaltBorder = Color(0xFFF3ECE4);

  // Chart accents
  static const Color chartSales = Color(0xFF3B82F6);
  static const Color chartProfit = Color(0xFF10B981);

  // Backwards compatibility aliases
  static const Color primary = brandPrimary;
  static const Color primaryDark = brandDark;
  static const Color primaryLight = brandLight;
  static const Color text = textPrimary;
  static const Color textTable = textSecondary;
  static const Color textHeader = textMuted;
  static const Color green = success;
  static const Color greenBg = successBg;
  static const Color greenAccent = successText;
  static const Color greenPositive = success;
  static const Color greenChart = chartProfit;
  static const Color greenIndicator = Color(0xFF22C55E);
  static const Color red = danger;
  static const Color redLight = Color(0xFFEF4444);
  static const Color redBg = dangerBg;
  static const Color redNoticeBg = dangerBg;
  static const Color redNoticeBorder = dangerBorder;
  static const Color amber = warning;
  static const Color amberBg = warningBg;
  static const Color amberLight = warningBg;
  static const Color greenBorder = successBorder;
  static const Color brown = rawSalt;
  static const Color brownBg = rawSaltBg;
  static const Color blueChart = chartSales;
  static const Color borderInput = borderStrong;
  static const Color surfaceAlt = surfaceMuted;
  static const Color navy = sidebarNavy;
  static const Color primaryBlueBg = brandLight;
  static const Color primaryText = brandDark;

  static const Color tableHover = Color(0xFFF8FAFC);
  static const Color tableSelected = Color(0xFFEFF6FF);
  static const Color sidebarHover = Color(0xFF1E293B);
  static const Color sidebarActive = Color(0xFF2563EB);

  // Elevation Shadows for Windows Desktop
  static const List<BoxShadow> shadowSm = [
    BoxShadow(
      color: Color.fromRGBO(15, 23, 42, 0.04),
      blurRadius: 3,
      offset: Offset(0, 1),
    ),
  ];

  static const List<BoxShadow> shadowMd = [
    BoxShadow(
      color: Color.fromRGBO(15, 23, 42, 0.05),
      blurRadius: 6,
      offset: Offset(0, 2),
    ),
    BoxShadow(
      color: Color.fromRGBO(15, 23, 42, 0.02),
      blurRadius: 2,
      offset: Offset(0, 1),
    ),
  ];

  static const List<BoxShadow> shadowLg = [
    BoxShadow(
      color: Color.fromRGBO(15, 23, 42, 0.10),
      blurRadius: 18,
      offset: Offset(0, 6),
    ),
    BoxShadow(
      color: Color.fromRGBO(15, 23, 42, 0.04),
      blurRadius: 6,
      offset: Offset(0, 2),
    ),
  ];

  static const List<BoxShadow> cardShadow = shadowSm;
  static const List<BoxShadow> dialogShadow = shadowLg;
  static const double radiusXs = 4.0;
  static const double radiusSm = 6.0;
  static const double radius = 8.0;
  static const double radiusMd = 10.0;
  static const double radiusLg = 12.0;
}

/// Layout spacing and sizing scale for consistent desktop alignment.
class AppSpacing {
  static const double xxs = 2.0;
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
}

/// Standardized typography hierarchy for enterprise desktop.
class AppTypography {
  static const TextStyle display = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
    color: AppColors.textPrimary,
    height: 1.25,
  );

  static const TextStyle h1 = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.25,
    color: AppColors.textPrimary,
  );

  static const TextStyle h2 = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.15,
    color: AppColors.textPrimary,
  );

  static const TextStyle body = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: AppColors.textMuted,
  );

  static const TextStyle micro = TextStyle(
    fontSize: 9.5,
    fontWeight: FontWeight.w500,
    color: AppColors.textMuted,
  );

  static const TextStyle tableHeader = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.6,
    color: AppColors.textMuted,
  );

  static const TextStyle tableCell = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  static const TextStyle tabularNumber = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    fontFeatures: [FontFeature.tabularFigures()],
    color: AppColors.textPrimary,
  );

  static const TextStyle kpiValue = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.25,
    fontFeatures: [FontFeature.tabularFigures()],
    color: AppColors.textPrimary,
  );
}

/// Centralized enterprise motion tokens for Anwar Salt Factory ERP.
/// Restrained, responsive durations and easing curves tailored for desktop ERP workflows.
class AppMotion {
  // Durations
  static const Duration micro = Duration(milliseconds: 90); // Instant tactile/press feedback
  static const Duration fast = Duration(milliseconds: 140); // Hover states, dropdown menus, icons
  static const Duration normal = Duration(milliseconds: 200); // Modals, drawers, card selections
  static const Duration page = Duration(milliseconds: 180); // Smooth page cross-fade
  static const Duration medium = Duration(milliseconds: 280); // Layout transitions, accordion expansions
  static const Duration pulse = Duration(milliseconds: 1100); // Skeleton shimmer / breathing cycle

  // Curves
  static const Curve easeOut = Curves.easeOutCubic;
  static const Curve easeIn = Curves.easeInCubic;
  static const Curve easeInOut = Curves.easeInOutCubic;
  static const Curve springSubtle = Cubic(0.2, 0.9, 0.3, 1.05);

  /// Checks if the operating system or user has requested reduced motion.
  static bool isReducedMotion(BuildContext context) {
    return MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  }

  /// Returns [standard] duration, or [Duration.zero] if reduced motion is requested.
  static Duration duration(BuildContext context, Duration standard) {
    return isReducedMotion(context) ? Duration.zero : standard;
  }
}

class AppTheme {
  static ThemeData get lightTheme {
    final baseFont = GoogleFonts.inter();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.light(
        primary: AppColors.brandPrimary,
        onPrimary: Colors.white,
        secondary: AppColors.brandDark,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        error: AppColors.danger,
      ),
      dividerColor: AppColors.border,
      fontFamily: baseFont.fontFamily,
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radius),
          side: const BorderSide(color: AppColors.border),
        ),
        margin: EdgeInsets.zero,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        elevation: 8,
        shadowColor: const Color.fromRGBO(15, 23, 42, 0.16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusLg),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusSm),
        ),
        elevation: 4,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusSm),
          borderSide: const BorderSide(color: AppColors.borderStrong),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusSm),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusSm),
          borderSide: const BorderSide(color: AppColors.brandPrimary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.sidebarNavy,
          borderRadius: BorderRadius.circular(5),
          boxShadow: AppColors.shadowSm,
        ),
        textStyle: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
        waitDuration: const Duration(milliseconds: 300),
      ),
    );
  }
}

