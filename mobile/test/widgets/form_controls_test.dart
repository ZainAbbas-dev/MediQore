import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediqore/theme/app_theme.dart';
import 'package:mediqore/widgets/form_fields.dart';
import 'package:mediqore/widgets/large_button.dart';

import '../helpers.dart';

void main() {
  group('LargeButton', () {
    testWidgets('is full width, at least the large control height, and tappable', (tester) async {
      var taps = 0;
      await tester.pumpWidget(wrapInApp(LargeButton(label: 'محفوظ کریں', onPressed: () => taps++)));
      await tester.pumpAndSettle();

      final size = tester.getSize(find.byType(FilledButton));
      expect(size.height, greaterThanOrEqualTo(AppTheme.largeControlHeight));
      expect(size.width, tester.getSize(find.byType(ListView)).width - 32);

      await tester.tap(find.byType(LargeButton));
      expect(taps, 1);
    });

    testWidgets('secondary style is outlined', (tester) async {
      await tester.pumpWidget(wrapInApp(LargeButton(label: 'منسوخ کریں', secondary: true, onPressed: () {})));
      await tester.pumpAndSettle();

      expect(find.byType(OutlinedButton), findsOneWidget);
    });
  });

  group('VitalField', () {
    testWidgets('keeps the number and unit left to right inside the Urdu layout', (tester) async {
      await tester.pumpWidget(wrapInApp(const VitalField(label: 'اوپر والا بلڈ پریشر', unit: 'mmHg')));
      await tester.pumpAndSettle();

      final field = tester.element(find.byType(TextField));
      expect(Directionality.of(field), TextDirection.ltr);
      final label = tester.element(find.text('اوپر والا بلڈ پریشر'));
      expect(Directionality.of(label), TextDirection.rtl);
      expect(find.text('mmHg'), findsOneWidget);
    });

    testWidgets('accepts digits only', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(wrapInApp(VitalField(label: 'BP', unit: 'mmHg', controller: controller)));

      await tester.enterText(find.byType(TextField), '12a0');
      expect(controller.text, isNot(contains('a')));
      await tester.enterText(find.byType(TextField), '120');
      expect(controller.text, '120');
    });

    testWidgets('accepts one decimal point when allowed', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        wrapInApp(VitalField(label: 'T', unit: '°C', allowDecimal: true, controller: controller)),
      );

      await tester.enterText(find.byType(TextField), '37.5');
      expect(controller.text, '37.5');
    });
  });

  testWidgets('CheckboxField reports the new value', (tester) async {
    bool? reported;
    await tester.pumpWidget(
      wrapInApp(CheckboxField(label: 'خون آنا', value: false, onChanged: (v) => reported = v)),
    );

    await tester.tap(find.text('خون آنا'));
    expect(reported, isTrue);
  });

  testWidgets('DropdownField shows its options and reports the choice', (tester) async {
    String? chosen;
    await tester.pumpWidget(
      wrapInApp(
        DropdownField<String>(
          label: 'بچے کی حرکت',
          value: null,
          onChanged: (v) => chosen = v,
          options: const [DropdownOption('normal', 'معمول کے مطابق'), DropdownOption('reduced', 'کم')],
        ),
      ),
    );

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('کم').last);
    await tester.pumpAndSettle();

    expect(chosen, 'reduced');
  });
}
