import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'app_icons.dart';

enum ButtonVariant { primary, secondary, ghost, danger, outline }

/// Polished Enterprise Button for Windows Desktop.
/// Supports keyboard focus, hover animations, tactile press-down micro-scale, loading state, and accessible tooltips.
class AppButton extends StatefulWidget {
  final String label;
  final String? icon;
  final ButtonVariant variant;
  final VoidCallback? onClick;
  final double height;
  final EdgeInsetsGeometry padding;
  final bool isLoading;
  final String? tooltip;

  const AppButton({
    super.key,
    required this.label,
    this.icon,
    this.variant = ButtonVariant.primary,
    this.onClick,
    this.height = 36,
    this.padding = const EdgeInsets.symmetric(horizontal: 14),
    this.isLoading = false,
    this.tooltip,
  });

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _isHovered = false;
  bool _isFocused = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onClick != null && !widget.isLoading;

    Color bg;
    Color fg;
    Color border;
    List<BoxShadow>? shadow;

    switch (widget.variant) {
      case ButtonVariant.primary:
        if (!isEnabled) {
          bg = AppColors.brandPrimary.withAlpha(120);
          fg = Colors.white.withAlpha(200);
          border = Colors.transparent;
          shadow = null;
        } else if (_isPressed) {
          bg = AppColors.brandDark;
          fg = Colors.white;
          border = Colors.transparent;
          shadow = null;
        } else if (_isHovered) {
          bg = AppColors.brandDark;
          fg = Colors.white;
          border = Colors.transparent;
          shadow = AppColors.shadowSm;
        } else {
          bg = AppColors.brandPrimary;
          fg = Colors.white;
          border = Colors.transparent;
          shadow = [
            BoxShadow(
              color: AppColors.brandPrimary.withAlpha(50),
              blurRadius: 3,
              offset: const Offset(0, 1.5),
            ),
          ];
        }
        break;

      case ButtonVariant.secondary:
        if (!isEnabled) {
          bg = AppColors.surfaceMuted;
          fg = AppColors.textSubtle;
          border = AppColors.border;
          shadow = null;
        } else if (_isPressed) {
          bg = AppColors.surfaceMuted;
          fg = AppColors.textPrimary;
          border = AppColors.borderStrong;
          shadow = null;
        } else if (_isHovered) {
          bg = AppColors.surfaceHover;
          fg = AppColors.textPrimary;
          border = AppColors.borderStrong;
          shadow = AppColors.shadowSm;
        } else {
          bg = AppColors.surface;
          fg = AppColors.textSecondary;
          border = AppColors.border;
          shadow = null;
        }
        break;

      case ButtonVariant.ghost:
        if (!isEnabled) {
          bg = Colors.transparent;
          fg = AppColors.textSubtle;
          border = Colors.transparent;
          shadow = null;
        } else if (_isHovered || _isPressed) {
          bg = const Color.fromRGBO(15, 23, 42, 0.05);
          fg = AppColors.textPrimary;
          border = Colors.transparent;
          shadow = null;
        } else {
          bg = Colors.transparent;
          fg = AppColors.textMuted;
          border = Colors.transparent;
          shadow = null;
        }
        break;

      case ButtonVariant.danger:
        if (!isEnabled) {
          bg = AppColors.dangerBg;
          fg = AppColors.danger.withAlpha(120);
          border = AppColors.dangerBorder;
          shadow = null;
        } else if (_isHovered || _isPressed) {
          bg = AppColors.danger;
          fg = Colors.white;
          border = Colors.transparent;
          shadow = AppColors.shadowSm;
        } else {
          bg = AppColors.dangerBg;
          fg = AppColors.danger;
          border = AppColors.dangerBorder;
          shadow = null;
        }
        break;

      case ButtonVariant.outline:
        if (!isEnabled) {
          bg = Colors.transparent;
          fg = AppColors.textSubtle;
          border = AppColors.border;
          shadow = null;
        } else if (_isHovered || _isPressed) {
          bg = AppColors.brandLight;
          fg = AppColors.brandPrimary;
          border = AppColors.brandPrimary;
          shadow = null;
        } else {
          bg = Colors.transparent;
          fg = AppColors.brandPrimary;
          border = AppColors.brandPrimary.withAlpha(120);
          shadow = null;
        }
        break;
    }

    Widget content = FocusableActionDetector(
      onShowFocusHighlight: (f) => setState(() => _isFocused = f),
      child: MouseRegion(
        cursor: isEnabled ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
        onEnter: (_) {
          if (isEnabled) setState(() => _isHovered = true);
        },
        onExit: (_) {
          if (isEnabled) setState(() => _isHovered = false);
        },
        child: GestureDetector(
          onTapDown: (_) {
            if (isEnabled) setState(() => _isPressed = true);
          },
          onTapUp: (_) {
            if (isEnabled) setState(() => _isPressed = false);
          },
          onTapCancel: () {
            if (isEnabled) setState(() => _isPressed = false);
          },
          onTap: isEnabled ? widget.onClick : null,
          child: AnimatedScale(
            scale: _isPressed && isEnabled ? 0.985 : 1.0,
            duration: AppMotion.duration(context, AppMotion.micro),
            curve: AppMotion.easeOut,
            child: AnimatedContainer(
              duration: AppMotion.duration(context, AppMotion.fast),
              curve: AppMotion.easeOut,
              height: widget.height,
              padding: widget.padding,
              decoration: BoxDecoration(
                color: bg,
                border: Border.all(
                  color: _isFocused ? AppColors.focusRing : border,
                  width: _isFocused ? 1.5 : 1.0,
                ),
                borderRadius: BorderRadius.circular(AppColors.radiusSm),
                boxShadow: shadow,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.isLoading) ...[
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(fg),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ] else if (widget.icon != null) ...[
                    AppIcons.icon(
                      widget.icon!,
                      size: 15,
                      color: fg,
                    ),
                    const SizedBox(width: 7),
                  ],
                  Flexible(
                    child: Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: fg,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (widget.tooltip != null) {
      return Tooltip(message: widget.tooltip!, child: content);
    }
    return content;
  }
}

enum BadgeTone { green, red, amber, blue, violet, neutral }

/// Clean status pill badge with indicator dot.
class AppBadge extends StatelessWidget {
  final String label;
  final BadgeTone tone;

  const AppBadge({
    super.key,
    required this.label,
    this.tone = BadgeTone.neutral,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    Color dot;

    switch (tone) {
      case BadgeTone.green:
        bg = AppColors.successBg;
        fg = AppColors.successText;
        dot = AppColors.success;
        break;
      case BadgeTone.red:
        bg = AppColors.dangerBg;
        fg = AppColors.dangerText;
        dot = AppColors.danger;
        break;
      case BadgeTone.amber:
        bg = AppColors.warningBg;
        fg = AppColors.warningText;
        dot = AppColors.warning;
        break;
      case BadgeTone.blue:
        bg = AppColors.brandLight;
        fg = AppColors.brandDark;
        dot = AppColors.brandPrimary;
        break;
      case BadgeTone.violet:
        bg = AppColors.violetBg;
        fg = AppColors.violet;
        dot = AppColors.violet;
        break;
      case BadgeTone.neutral:
        bg = AppColors.surfaceMuted;
        fg = AppColors.textSecondary;
        dot = AppColors.textSubtle;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: dot.withAlpha(40), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5.5,
            height: 5.5,
            decoration: BoxDecoration(
              color: dot,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5.5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: fg,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Standardized KPI Metric Card with clean iconography, hover elevation micro-interaction,
/// and smooth slide-fade value transitions when refreshed data changes.
class MetricCard extends StatefulWidget {
  final String label;
  final String value;
  final String hint;
  final String icon;
  final String tone;

  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.hint,
    required this.icon,
    this.tone = 'blue',
  });

  @override
  State<MetricCard> createState() => _MetricCardState();
}

class _MetricCardState extends State<MetricCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    Color iconBg;
    Color iconColor;

    switch (widget.tone) {
      case 'violet':
        iconBg = AppColors.violetBg;
        iconColor = AppColors.violet;
        break;
      case 'green':
        iconBg = AppColors.greenBg;
        iconColor = AppColors.green;
        break;
      case 'amber':
        iconBg = AppColors.amberBg;
        iconColor = AppColors.amber;
        break;
      case 'red':
        iconBg = AppColors.redBg;
        iconColor = AppColors.red;
        break;
      case 'blue':
      default:
        iconBg = AppColors.primaryLight;
        iconColor = AppColors.primary;
        break;
    }

    final isDown = widget.hint.startsWith('-');
    final isUp = widget.hint.startsWith('+');

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: AppMotion.duration(context, AppMotion.fast),
        curve: AppMotion.easeOut,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(
            color: _isHovered ? AppColors.borderStrong : AppColors.border,
          ),
          borderRadius: BorderRadius.circular(AppColors.radius),
          boxShadow: _isHovered ? AppColors.shadowMd : AppColors.cardShadow,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(AppColors.radiusSm),
              ),
              alignment: Alignment.center,
              child: AppIcons.icon(widget.icon, size: 17, color: iconColor),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 3),
                  AnimatedSwitcher(
                    duration: AppMotion.duration(context, AppMotion.fast),
                    switchInCurve: AppMotion.easeOut,
                    switchOutCurve: AppMotion.easeIn,
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.0, 0.12),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: Text(
                      widget.value,
                      key: ValueKey<String>(widget.value),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.kpiValue,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isUp)
                        const Padding(
                          padding: EdgeInsets.only(right: 3),
                          child: Icon(
                            Icons.arrow_upward_rounded,
                            size: 11,
                            color: AppColors.success,
                          ),
                        )
                      else if (isDown)
                        const Padding(
                          padding: EdgeInsets.only(right: 3),
                          child: Icon(
                            Icons.arrow_downward_rounded,
                            size: 11,
                            color: AppColors.danger,
                          ),
                        ),
                      Flexible(
                        child: Text(
                          widget.hint,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isDown
                                ? AppColors.danger
                                : isUp
                                    ? AppColors.success
                                    : AppColors.textMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact Metric Widget used on module summary strips with hover elevation and animated value transitions.
class MiniMetric extends StatefulWidget {
  final String label;
  final String value;
  final String hint;
  final bool alert;

  const MiniMetric({
    super.key,
    required this.label,
    required this.value,
    required this.hint,
    this.alert = false,
  });

  @override
  State<MiniMetric> createState() => _MiniMetricState();
}

class _MiniMetricState extends State<MiniMetric> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: AppMotion.duration(context, AppMotion.fast),
        curve: AppMotion.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(
            color: widget.alert
                ? AppColors.warningBorder
                : (_isHovered ? AppColors.borderStrong : AppColors.border),
          ),
          borderRadius: BorderRadius.circular(AppColors.radius),
          boxShadow: _isHovered ? AppColors.shadowMd : AppColors.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.label,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedSwitcher(
              duration: AppMotion.duration(context, AppMotion.fast),
              switchInCurve: AppMotion.easeOut,
              switchOutCurve: AppMotion.easeIn,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.0, 0.12),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: Text(
                widget.value,
                key: ValueKey<String>(widget.value),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              widget.hint,
              style: TextStyle(
                color: widget.alert ? AppColors.warningText : AppColors.successText,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Desktop Table Toolbar with search, keyboard shortcut hint, filter chip, and date selector.
class AppToolbar extends StatefulWidget {
  final String placeholder;
  final ValueChanged<String>? onSearch;
  final VoidCallback? onFilter;
  final VoidCallback? onDateFilter;
  final String activeDateLabel;
  final int filterCount;

  const AppToolbar({
    super.key,
    this.placeholder = 'Search by name, SKU or transaction...',
    this.onSearch,
    this.onFilter,
    this.onDateFilter,
    this.activeDateLabel = 'This month',
    this.filterCount = 2,
  });

  @override
  State<AppToolbar> createState() => _AppToolbarState();
}

class _AppToolbarState extends State<AppToolbar> {
  final TextEditingController _controller = TextEditingController();
  bool _hasText = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.borderLight),
        ),
      ),
      child: Row(
        children: [
          // Search Box with clear button and shortcut pill
          Container(
            width: 290,
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(AppColors.radiusSm),
            ),
            child: Row(
              children: [
                AppIcons.icon('search', size: 15, color: AppColors.textSubtle),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    onChanged: (val) {
                      setState(() => _hasText = val.isNotEmpty);
                      widget.onSearch?.call(val);
                    },
                    decoration: InputDecoration(
                      hintText: widget.placeholder,
                      hintStyle: const TextStyle(
                        color: AppColors.textSubtle,
                        fontSize: 11.5,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (_hasText)
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () {
                        _controller.clear();
                        setState(() => _hasText = false);
                        widget.onSearch?.call('');
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          Icons.close,
                          size: 14,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: AppColors.borderStrong),
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: AppColors.shadowSm,
                    ),
                    child: const Text(
                      'Ctrl K',
                      style: TextStyle(
                        fontSize: 9,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Filters Button
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: widget.onFilter ??
                  () {
                    AppToast.showInfo(context, 'All records currently displayed match active table criteria.');
                  },
              child: Container(
                height: 34,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(AppColors.radiusSm),
                ),
                child: Row(
                  children: [
                    AppIcons.icon('filter', size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    const Text(
                      'Filters',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (widget.filterCount > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        width: 17,
                        height: 17,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.brandLight,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Text(
                          '${widget.filterCount}',
                          style: const TextStyle(
                            fontSize: 9,
                            color: AppColors.brandPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Date Filter Button
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: widget.onDateFilter ??
                  () {
                    AppToast.showInfo(context, 'Displaying transactions for accounting period: ${widget.activeDateLabel}');
                  },
              child: Container(
                height: 34,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(AppColors.radiusSm),
                ),
                child: Row(
                  children: [
                    AppIcons.icon('calendar', size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      widget.activeDateLabel,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.keyboard_arrow_down,
                      size: 14,
                      color: AppColors.textMuted,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Standardized enterprise empty state widget for tables, lists, and search results.
/// Features a gentle entrance animation with micro-rise that respects reduced motion.
class AppEmptyState extends StatelessWidget {
  final String icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const AppEmptyState({
    super.key,
    this.icon = 'search',
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final isReduced = AppMotion.isReducedMotion(context);

    Widget content = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            alignment: Alignment.center,
            child: AppIcons.icon(icon, size: 22, color: AppColors.textMuted),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11.5,
                color: AppColors.textMuted,
                height: 1.4,
              ),
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            AppButton(
              label: actionLabel!,
              variant: ButtonVariant.secondary,
              onClick: onAction,
              height: 32,
            ),
          ],
        ],
      ),
    );

    if (isReduced) return content;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: AppMotion.normal,
      curve: AppMotion.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 8 * (1 - value)),
            child: child,
          ),
        );
      },
      child: content,
    );
  }
}

/// Interactive desktop table row with subtle hover state and selection feedback.
class AppInteractiveRow extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool isSelected;
  final Color? defaultColor;

  const AppInteractiveRow({
    super.key,
    required this.child,
    this.onTap,
    this.isSelected = false,
    this.defaultColor,
  });

  @override
  State<AppInteractiveRow> createState() => _AppInteractiveRowState();
}

class _AppInteractiveRowState extends State<AppInteractiveRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    Color bg = widget.defaultColor ?? Colors.transparent;
    if (widget.isSelected) {
      bg = AppColors.brandLight;
    } else if (_isHovered) {
      bg = AppColors.surfaceHover;
    }

    Widget content = AnimatedContainer(
      duration: AppMotion.duration(context, AppMotion.micro),
      curve: AppMotion.easeOut,
      color: bg,
      child: widget.child,
    );

    if (widget.onTap != null) {
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: content,
        ),
      );
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: content,
    );
  }
}

/// Clean, restrained skeleton loading placeholder.
/// Uses a subtle breathing pulse (opacity 0.55 to 0.95), automatically static if reduced motion is requested.
class AppSkeleton extends StatefulWidget {
  final double? width;
  final double height;
  final double borderRadius;
  final EdgeInsetsGeometry margin;

  const AppSkeleton({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = AppColors.radiusSm,
    this.margin = EdgeInsets.zero,
  });

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.pulse,
    );
    _animation = Tween<double>(begin: 0.55, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: AppMotion.easeInOut),
    );
    if (!WidgetsBinding.instance.runtimeType.toString().contains('TestWidgetsFlutterBinding')) {
      _controller.repeat(reverse: true);
    } else {
      _controller.value = 0.75;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (AppMotion.isReducedMotion(context)) {
      return Container(
        width: widget.width,
        height: widget.height,
        margin: widget.margin,
        decoration: BoxDecoration(
          color: const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(widget.borderRadius),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          margin: widget.margin,
          decoration: BoxDecoration(
            color: Color.fromRGBO(226, 232, 240, _animation.value),
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        );
      },
    );
  }
}

/// Standardized loading skeleton for ERP tabular data.
class AppTableSkeleton extends StatelessWidget {
  final int rowCount;
  final int columnCount;

  const AppTableSkeleton({
    super.key,
    this.rowCount = 5,
    this.columnCount = 6,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          color: AppColors.tableHeaderBg,
          child: Row(
            children: List.generate(columnCount, (i) {
              return Expanded(
                flex: i == 0 ? 2 : (i == 1 ? 3 : 2),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: AppSkeleton(
                    height: 10,
                    width: (i == 0 ? 60 : (i == 1 ? 90 : 50)),
                  ),
                ),
              );
            }),
          ),
        ),
        // Rows
        for (int r = 0; r < rowCount; r++)
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.borderLight)),
            ),
            child: Row(
              children: List.generate(columnCount, (i) {
                final width = 40.0 + ((r * 17 + i * 23) % 45);
                return Expanded(
                  flex: i == 0 ? 2 : (i == 1 ? 3 : 2),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: AppSkeleton(height: 11, width: width),
                    ),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }
}

/// Non-blocking floating desktop notification feedback.
/// Appears smoothly at the top right of the application window,
/// auto-dismisses after 3.2 seconds, and does not block interaction with underlying screens.
class AppToast {
  static void showSuccess(BuildContext context, String message, {String? actionLabel, VoidCallback? onAction}) {
    _show(context, message, BadgeTone.green, 'check', actionLabel, onAction);
  }

  static void showError(BuildContext context, String message, {String? actionLabel, VoidCallback? onAction}) {
    _show(context, message, BadgeTone.red, 'close', actionLabel, onAction);
  }

  static void showWarning(BuildContext context, String message, {String? actionLabel, VoidCallback? onAction}) {
    _show(context, message, BadgeTone.amber, 'warning', actionLabel, onAction);
  }

  static void showInfo(BuildContext context, String message, {String? actionLabel, VoidCallback? onAction}) {
    _show(context, message, BadgeTone.blue, 'info', actionLabel, onAction);
  }

  static void _show(
    BuildContext context,
    String message,
    BadgeTone tone,
    String iconName,
    String? actionLabel,
    VoidCallback? onAction,
  ) {
    Color bg;
    Color border;
    Color fg;
    Color iconColor;

    switch (tone) {
      case BadgeTone.green:
        bg = const Color(0xFFF0FDF4);
        border = const Color(0xFFBBF7D0);
        fg = const Color(0xFF166534);
        iconColor = AppColors.success;
        break;
      case BadgeTone.red:
        bg = const Color(0xFFFEF2F2);
        border = const Color(0xFFFECACA);
        fg = const Color(0xFF991B1B);
        iconColor = AppColors.danger;
        break;
      case BadgeTone.amber:
        bg = const Color(0xFFFFFBEB);
        border = const Color(0xFFFDE68A);
        fg = const Color(0xFF92400E);
        iconColor = AppColors.warning;
        break;
      case BadgeTone.blue:
      default:
        bg = const Color(0xFFEFF6FF);
        border = const Color(0xFFBFDBFE);
        fg = const Color(0xFF1E40AF);
        iconColor = AppColors.brandPrimary;
        break;
    }

    final overlay = Overlay.maybeOf(context);
    if (overlay == null) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: iconColor,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _ToastWidget(
        message: message,
        bg: bg,
        border: border,
        fg: fg,
        iconColor: iconColor,
        iconName: iconName,
        actionLabel: actionLabel,
        onAction: onAction,
        onDismiss: () {
          if (entry.mounted) entry.remove();
        },
      ),
    );

    overlay.insert(entry);
  }
}

class _ToastWidget extends StatefulWidget {
  final String message;
  final Color bg;
  final Color border;
  final Color fg;
  final Color iconColor;
  final String iconName;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback onDismiss;

  const _ToastWidget({
    required this.message,
    required this.bg,
    required this.border,
    required this.fg,
    required this.iconColor,
    required this.iconName,
    this.actionLabel,
    this.onAction,
    required this.onDismiss,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget> with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<double> _fade;
  late Animation<Offset> _slide;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: AppMotion.normal,
    );
    _fade = CurvedAnimation(parent: _anim, curve: AppMotion.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0.0, -0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _anim, curve: AppMotion.easeOut));

    _anim.forward();

    // Auto-dismiss after 3.2s
    _dismissTimer = Timer(const Duration(milliseconds: 3200), () {
      if (mounted) {
        _anim.reverse().then((_) {
          if (mounted) widget.onDismiss();
        });
      }
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _anim.dispose();
    super.dispose();
  }

  void _dismissNow() {
    _dismissTimer?.cancel();
    _anim.reverse().then((_) {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 18,
      right: 28,
      child: Material(
        color: Colors.transparent,
        child: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 380, minWidth: 260),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: widget.bg,
                border: Border.all(color: widget.border),
                borderRadius: BorderRadius.circular(AppColors.radiusSm),
                boxShadow: AppColors.shadowLg,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: widget.iconColor.withAlpha(30),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: AppIcons.icon(widget.iconName, size: 13, color: widget.iconColor),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: widget.fg,
                      ),
                    ),
                  ),
                  if (widget.actionLabel != null && widget.onAction != null) ...[
                    const SizedBox(width: 8),
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () {
                          _dismissNow();
                          widget.onAction!();
                        },
                        child: Text(
                          widget.actionLabel!,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: widget.iconColor,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: _dismissNow,
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Icon(Icons.close, size: 14, color: widget.fg.withAlpha(180)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Standardized, animated confirmation dialog for enterprise ERP operations.
/// Features smooth entrance transition, explicit audit preservation notes, and keyboard focus.
Future<bool?> showAppConfirmationDialog({
  required BuildContext context,
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool isDanger = false,
  String? auditNote,
}) {
  return showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: const Color(0xFF0F172A).withAlpha(115),
    transitionDuration: AppMotion.duration(context, AppMotion.normal),
    transitionBuilder: (ctx, anim1, anim2, child) {
      if (AppMotion.isReducedMotion(ctx)) return child;
      final curve = CurvedAnimation(parent: anim1, curve: AppMotion.easeOut);
      return FadeTransition(
        opacity: curve,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.97, end: 1.0).animate(curve),
          child: child,
        ),
      );
    },
    pageBuilder: (ctx, anim1, anim2) {
      return Center(
        child: Container(
          width: 440,
          margin: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppColors.radiusLg),
            boxShadow: AppColors.dialogShadow,
            border: Border.all(color: AppColors.border),
          ),
          child: Material(
            color: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isDanger ? AppColors.dangerBg : AppColors.brandLight,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: AppIcons.icon(
                          isDanger ? 'warning' : 'info',
                          size: 18,
                          color: isDanger ? AppColors.danger : AppColors.brandPrimary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                  if (auditNote != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(AppColors.radiusSm),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          AppIcons.icon('shield', size: 14, color: AppColors.textMuted),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              auditNote,
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: AppColors.textMuted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      AppButton(
                        label: cancelLabel,
                        variant: ButtonVariant.ghost,
                        onClick: () => Navigator.of(ctx).pop(false),
                      ),
                      const SizedBox(width: 8),
                      AppButton(
                        label: confirmLabel,
                        variant: isDanger ? ButtonVariant.danger : ButtonVariant.primary,
                        onClick: () => Navigator.of(ctx).pop(true),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// Refined desktop brand logo for Anwar Salt Factory ERP.
/// Features a layered cobalt badge, high-contrast typography, and subtle hover micro-interaction.
class AppBrandLogo extends StatefulWidget {
  final bool isCollapsed;
  final VoidCallback? onTap;

  const AppBrandLogo({
    super.key,
    required this.isCollapsed,
    this.onTap,
  });

  @override
  State<AppBrandLogo> createState() => _AppBrandLogoState();
}

class _AppBrandLogoState extends State<AppBrandLogo> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppMotion.duration(context, AppMotion.fast),
          curve: AppMotion.easeOut,
          height: 68,
          padding: EdgeInsets.symmetric(horizontal: widget.isCollapsed ? 0 : 18),
          alignment: widget.isCollapsed ? Alignment.center : Alignment.centerLeft,
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Color.fromRGBO(255, 255, 255, 0.07)),
            ),
          ),
          child: Row(
            mainAxisAlignment: widget.isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              AnimatedScale(
                scale: _isHovered ? 1.04 : 1.0,
                duration: AppMotion.duration(context, AppMotion.fast),
                curve: AppMotion.easeOut,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                    ),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: _isHovered
                          ? const Color.fromRGBO(255, 255, 255, 0.35)
                          : const Color.fromRGBO(255, 255, 255, 0.14),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _isHovered
                            ? const Color.fromRGBO(37, 99, 235, 0.5)
                            : const Color.fromRGBO(37, 99, 235, 0.35),
                        blurRadius: _isHovered ? 12 : 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'S',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ),
              if (!widget.isCollapsed) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'SaltFlow',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'FACTORY ERP',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Detail drawer / card key-value row.
class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isHighlight;

  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.isHighlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.borderLight),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 10.5,
                color: AppColors.textMuted,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: isHighlight ? AppColors.brandPrimary : AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Reusable Card Component for consistent desktop surface hierarchy.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final Border? border;
  final VoidCallback? onTap;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.backgroundColor,
    this.border,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.surface,
        border: border ?? Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppColors.radius),
        boxShadow: AppColors.cardShadow,
      ),
      child: child,
    );

    if (onTap != null) {
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(onTap: onTap, child: card),
      );
    }
    return card;
  }
}

/// Notice banner for system alerts, warnings, and dangerous factory states.
class DangerNotice extends StatelessWidget {
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback? onAction;

  const DangerNotice({
    super.key,
    required this.title,
    required this.message,
    required this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.dangerBg,
        border: Border.all(color: AppColors.dangerBorder),
        borderRadius: BorderRadius.circular(AppColors.radius),
        boxShadow: AppColors.shadowSm,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.dangerBorder),
            ),
            alignment: Alignment.center,
            child: AppIcons.icon('warning', size: 19, color: AppColors.danger),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.dangerText,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          AppButton(
            label: actionLabel,
            variant: ButtonVariant.danger,
            onClick: onAction,
            height: 32,
          ),
        ],
      ),
    );
  }
}
