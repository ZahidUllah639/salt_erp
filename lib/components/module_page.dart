import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'app_components.dart';

class ModulePage extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? action;
  final VoidCallback? onAction;
  final VoidCallback? onExport;
  final Widget child;

  const ModulePage({
    super.key,
    required this.title,
    required this.subtitle,
    this.action,
    this.onAction,
    this.onExport,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 44),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
              // Page Head
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 680;
                    final titleCol = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: AppColors.brandPrimary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'ANWAR SALT FACTORY ERP',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          title,
                          style: AppTypography.display,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textMuted,
                            height: 1.35,
                          ),
                        ),
                      ],
                    );

                    final actions = action != null
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AppButton(
                                label: 'Export',
                                icon: 'download',
                                variant: ButtonVariant.secondary,
                                onClick: onExport ?? () {
                                  AppToast.showInfo(context, 'Exporting $title operational records...');
                                },
                                tooltip: 'Export table data to Excel or PDF',
                              ),
                              const SizedBox(width: 8),
                              AppButton(
                                label: action!,
                                icon: 'plus',
                                variant: ButtonVariant.primary,
                                onClick: onAction ?? () {},
                              ),
                            ],
                          )
                        : (onExport != null
                            ? AppButton(
                                label: 'Export',
                                icon: 'download',
                                variant: ButtonVariant.secondary,
                                onClick: onExport!,
                              )
                            : null);

                    if (isNarrow && actions != null) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          titleCol,
                          const SizedBox(height: 14),
                          actions,
                        ],
                      );
                    }

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(child: titleCol),
                        ?actions,
                      ],
                    );
                  },
                ),
              ),
              child,
            ],
          ),
        ),
      );
  }
}
