import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediqore/l10n/app_localizations.dart';
import 'package:mediqore/settings/app_settings.dart';
import 'package:mediqore/theme/app_theme.dart';
import 'package:mediqore/widgets/language_switch.dart';

/// The language row in Settings and its sheet (M3 FE-3): the app switches
/// only on Save, and the choice is kept on the phone.
void main() {
  late MemorySettingsStore store;
  late AppSettings settings;

  setUp(() {
    store = MemorySettingsStore();
    settings = AppSettings(store: store);
  });

  /// The settings row in an app that follows [settings], as `MediQoreApp` does.
  Future<void> pumpRow(WidgetTester tester) async {
    await tester.pumpWidget(
      ListenableBuilder(
        listenable: settings,
        builder: (context, _) => MaterialApp(
          theme: AppTheme.light(urdu: settings.isUrdu),
          locale: settings.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: ListView(children: [Card(child: LanguageSettingTile(settings: settings))]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  void smallPhone(WidgetTester tester) {
    tester.view.physicalSize = const Size(640, 1280);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
  }

  testWidgets('the row shows the current language and opens the sheet with Urdu chosen', (tester) async {
    final ur = lookupAppLocalizations(AppSettings.urdu);
    await pumpRow(tester);

    expect(find.textContaining('زبان · Language', findRichText: true), findsOneWidget);
    expect(find.text(ur.languageNameUrdu), findsOneWidget);
    expect(Directionality.of(tester.element(find.byType(LanguageSettingTile))), TextDirection.rtl);

    await tester.tap(find.byType(LanguageSettingTile));
    await tester.pumpAndSettle();

    expect(find.text('زبان منتخب کریں'), findsOneWidget);
    expect(find.text('Choose language'), findsOneWidget);
    expect(find.text('Urdu'), findsOneWidget);
    expect(find.text('انگریزی'), findsOneWidget);
    expect(find.text('محفوظ کریں'), findsOneWidget);
    expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);
    // The Urdu option is the chosen one.
    final urduRow = find.ancestor(of: find.text('Urdu'), matching: find.byType(Row)).first;
    expect(find.descendant(of: urduRow, matching: find.byIcon(Icons.radio_button_checked)), findsOneWidget);
  });

  testWidgets('choosing English switches the app only on Save, and the choice is kept', (tester) async {
    await pumpRow(tester);
    await tester.tap(find.byType(LanguageSettingTile));
    await tester.pumpAndSettle();

    await tester.tap(find.text('انگریزی'));
    await tester.pumpAndSettle();
    expect(settings.locale, AppSettings.urdu, reason: 'nothing changes before Save');
    final englishRow = find.ancestor(of: find.text('انگریزی'), matching: find.byType(Row)).first;
    expect(find.descendant(of: englishRow, matching: find.byIcon(Icons.radio_button_checked)), findsOneWidget);
    expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);

    await tester.tap(find.text('محفوظ کریں'));
    await tester.pumpAndSettle();

    expect(find.text('محفوظ کریں'), findsNothing, reason: 'the sheet closes');
    expect(settings.locale, AppSettings.english);
    expect(AppSettings(store: store).locale, AppSettings.english, reason: 'the next app start reads it');
    expect(find.textContaining('Language · زبان', findRichText: true), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(Directionality.of(tester.element(find.byType(LanguageSettingTile))), TextDirection.ltr);

    // And back to Urdu from the English sheet.
    await tester.tap(find.byType(LanguageSettingTile));
    await tester.pumpAndSettle();
    expect(find.text('Choose language'), findsOneWidget);
    expect(find.text('زبان منتخب کریں'), findsOneWidget);
    await tester.tap(find.text('Urdu'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(settings.locale, AppSettings.urdu);
    expect(Directionality.of(tester.element(find.byType(LanguageSettingTile))), TextDirection.rtl);
  });

  testWidgets('closing the sheet without Save keeps the language', (tester) async {
    await pumpRow(tester);
    await tester.tap(find.byType(LanguageSettingTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('انگریزی'));
    await tester.pumpAndSettle();

    // A tap on the dimmed background closes the sheet.
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    expect(find.text('محفوظ کریں'), findsNothing);
    expect(settings.locale, AppSettings.urdu);
    expect(AppSettings(store: store).locale, AppSettings.urdu);
  });

  testWidgets('the options tell a screen reader which one is chosen', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpRow(tester);
    await tester.tap(find.byType(LanguageSettingTile));
    await tester.pumpAndSettle();

    expect(tester.getSemantics(find.text('Urdu')), isSemantics(isChecked: true, isInMutuallyExclusiveGroup: true));
    expect(tester.getSemantics(find.text('انگریزی')), isSemantics(isChecked: false, isInMutuallyExclusiveGroup: true));
    semantics.dispose();
  });

  for (final english in [false, true]) {
    testWidgets('the sheet fits a small phone (${english ? 'English' : 'Urdu'})', (tester) async {
      smallPhone(tester);
      await settings.setLocale(english ? AppSettings.english : AppSettings.urdu);
      await pumpRow(tester);
      await tester.tap(find.byType(LanguageSettingTile));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final save = english ? 'Save' : 'محفوظ کریں';
      expect(tester.getRect(find.text(save)).bottom, lessThanOrEqualTo(640));
      for (final option in ['Urdu', 'انگریزی']) {
        final row = find.ancestor(of: find.text(option), matching: find.byType(ConstrainedBox)).first;
        expect(tester.getSize(row).height, greaterThanOrEqualTo(76));
      }
    });
  }
}
