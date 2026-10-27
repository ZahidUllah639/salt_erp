import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saltflow/theme/app_theme.dart';
import 'package:saltflow/components/app_components.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Anwar Salt Factory ERP - Animations & Interactions Test Suite', () {
    testWidgets('1. AppMotion Tokens & Reduced Motion Support', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Builder(
            builder: (context) {
              final isNormalReduced = AppMotion.isReducedMotion(context);
              final normalDur = AppMotion.duration(context, AppMotion.normal);

              return MediaQuery(
                data: const MediaQueryData(disableAnimations: true),
                child: Builder(
                  builder: (ctxReduced) {
                    final isReduced = AppMotion.isReducedMotion(ctxReduced);
                    final reducedDur = AppMotion.duration(ctxReduced, AppMotion.normal);

                    return Column(
                      children: [
                        Text('NormalReduced: $isNormalReduced'),
                        Text('NormalDurMs: ${normalDur.inMilliseconds}'),
                        Text('IsReduced: $isReduced'),
                        Text('ReducedDurMs: ${reducedDur.inMilliseconds}'),
                      ],
                    );
                  },
                ),
              );
            },
          ),
        ),
      );

      expect(find.text('NormalReduced: false'), findsOneWidget);
      expect(find.text('NormalDurMs: 200'), findsOneWidget);
      expect(find.text('IsReduced: true'), findsOneWidget);
      expect(find.text('ReducedDurMs: 0'), findsOneWidget);
    });

    testWidgets('2. AppButton Tactile Feedback, Focus & Loading State', (WidgetTester tester) async {
      int clickCount = 0;
      bool isLoading = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return Center(
                  child: AppButton(
                    label: 'Process Sale',
                    isLoading: isLoading,
                    onClick: () {
                      clickCount++;
                      setState(() => isLoading = true);
                    },
                  ),
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Process Sale'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      // Verify tap triggers once
      await tester.tap(find.byType(AppButton));
      await tester.pump();

      expect(clickCount, equals(1));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Verify second tap is blocked while loading (prevents double transaction submission)
      await tester.tap(find.byType(AppButton));
      await tester.pump();
      expect(clickCount, equals(1));
    });

    testWidgets('3. MetricCard Value Transition & Hover Elevation', (WidgetTester tester) async {
      String metricValue = 'Rs 100,000';

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  children: [
                    MetricCard(
                      label: "Today's sales",
                      value: metricValue,
                      hint: "+12.4%",
                      icon: "trend",
                    ),
                    ElevatedButton(
                      onPressed: () => setState(() => metricValue = 'Rs 250,000'),
                      child: const Text('Update Metric'),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Rs 100,000'), findsOneWidget);

      // Update value and trigger animated transition
      await tester.tap(find.text('Update Metric'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(find.text('Rs 250,000'), findsOneWidget);
    });

    testWidgets('4. AppSkeleton & AppTableSkeleton Loading States', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: Center(
              child: AppTableSkeleton(rowCount: 4, columnCount: 5),
            ),
          ),
        ),
      );

      expect(find.byType(AppSkeleton), findsWidgets);
      // Advance timer for breathing pulse
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
    });

    testWidgets('5. AppToast Floating Notification & Auto-Dismiss', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    AppToast.showSuccess(context, 'Transaction SAL-10482 posted successfully');
                  },
                  child: const Text('Trigger Toast'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Trigger Toast'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Transaction SAL-10482 posted successfully'), findsOneWidget);

      // Tap close button on toast
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.text('Transaction SAL-10482 posted successfully'), findsNothing);
    });

    testWidgets('6. showAppConfirmationDialog Smooth Entrance & Actions', (WidgetTester tester) async {
      bool? dialogResult;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    dialogResult = await showAppConfirmationDialog(
                      context: context,
                      title: 'Archive Profile?',
                      message: 'Historical records remain strictly preserved.',
                      confirmLabel: 'Archive',
                      isDanger: true,
                      auditNote: 'Locked in SQLite general ledger.',
                    );
                  },
                  child: const Text('Open Confirm'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Confirm'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();

      expect(find.text('Archive Profile?'), findsOneWidget);
      expect(find.text('Historical records remain strictly preserved.'), findsOneWidget);
      expect(find.text('Locked in SQLite general ledger.'), findsOneWidget);

      // Tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(dialogResult, isFalse);
    });

    testWidgets('7. AppBrandLogo Treatment in Expanded & Collapsed Modes', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: Column(
              children: [
                AppBrandLogo(isCollapsed: false),
                AppBrandLogo(isCollapsed: true),
              ],
            ),
          ),
        ),
      );

      expect(find.text('S'), findsNWidgets(2));
      expect(find.text('SaltFlow'), findsOneWidget);
      expect(find.text('FACTORY ERP'), findsOneWidget);
    });

    testWidgets('8. AppEmptyState Subtle Upward Drift Animation', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: AppEmptyState(
              title: 'No transactions found',
              message: 'Try adjusting your search criteria.',
              actionLabel: 'Reset Filters',
              onAction: () {},
            ),
          ),
        ),
      );

      expect(find.text('No transactions found'), findsOneWidget);
      expect(find.text('Reset Filters'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
    });

    testWidgets('9. AppInteractiveRow Hover and Selection States', (WidgetTester tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: AppInteractiveRow(
              onTap: () => tapped = true,
              isSelected: true,
              child: const Text('Test Row Content'),
            ),
          ),
        ),
      );

      expect(find.text('Test Row Content'), findsOneWidget);
      await tester.tap(find.text('Test Row Content'));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });
  });
}
