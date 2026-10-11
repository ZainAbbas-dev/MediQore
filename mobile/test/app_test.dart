import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediqore/app.dart';
import 'package:mediqore/app_services.dart';
import 'package:mediqore/clinical/visit_ranges.dart';
import 'package:mediqore/data/app_database.dart';
import 'package:mediqore/data/patient_repository.dart';
import 'package:mediqore/data/visit_repository.dart';
import 'package:mediqore/l10n/app_localizations.dart';
import 'package:mediqore/screens/dev_home_screen.dart';
import 'package:mediqore/screens/home_screen.dart';
import 'package:mediqore/screens/activation_screen.dart';
import 'package:mediqore/screens/lock_screen.dart';
import 'package:mediqore/screens/pin_create_screen.dart';
import 'package:mediqore/screens/pin_reset_screen.dart';
import 'package:mediqore/screens/pulse_counter_screen.dart';
import 'package:mediqore/screens/sign_in_again_screen.dart';
import 'package:mediqore/screens/patient_file_screen.dart';
import 'package:mediqore/screens/patient_list_screen.dart';
import 'package:mediqore/screens/register_screen.dart';
import 'package:mediqore/screens/settings_screen.dart';
import 'package:mediqore/screens/registration_saved_screen.dart';
import 'package:mediqore/screens/sync_test_screen.dart';
import 'package:mediqore/screens/visit_screen.dart';
import 'package:mediqore/screens/widget_kit_screen.dart';
import 'package:mediqore/settings/app_settings.dart';
import 'package:mediqore/theme/app_theme.dart';

import 'helpers.dart';
import 'support/fake_sync_server.dart';

void main() {
  late FakeSyncServer server;
  late AppServices services;

  setUp(() {
    server = FakeSyncServer();
    services = testServices(server);
  });
  tearDown(() => services.dispose());

  testWidgets('app starts on the activation screen in Urdu, right to left', (tester) async {
    await tester.pumpWidget(MediQoreApp(services: services));
    await tester.pumpAndSettle();

    expect(find.byType(ActivationScreen), findsOneWidget);
    expect(find.text('اس فون کو پہلی بار فعال کریں'), findsOneWidget);
    expect(Directionality.of(tester.element(find.byType(ActivationScreen))), TextDirection.rtl);
  });

  testWidgets('English strings exist for every key', (tester) async {
    await services.settings.setLocale(AppSettings.english);
    await tester.pumpWidget(MediQoreApp(services: services));
    await tester.pumpAndSettle();

    expect(find.text('Activate phone'), findsWidgets);
    expect(Directionality.of(tester.element(find.byType(ActivationScreen))), TextDirection.ltr);
  });

  testWidgets('the language switch on the activation screen changes the whole app and is saved (M1 FE-4)', (tester) async {
    final store = MemorySettingsStore();
    await services.dispose();
    services = testServices(server, AppSettings(store: store));
    await tester.pumpWidget(MediQoreApp(services: services));
    await tester.pumpAndSettle();

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(find.text('LHW ID'), findsOneWidget);
    expect(Directionality.of(tester.element(find.byType(ActivationScreen))), TextDirection.ltr);
    expect(
      Theme.of(tester.element(find.byType(ActivationScreen))).textTheme.bodyLarge?.fontFamily,
      isNot(AppTheme.urduFontFamily),
    );

    // The next app start reads the saved choice.
    expect(AppSettings(store: store).locale, AppSettings.english);

    await tester.tap(find.text('اردو'));
    await tester.pumpAndSettle();
    expect(find.text('ایل ایچ ڈبلیو آئی ڈی'), findsOneWidget);
    expect(Directionality.of(tester.element(find.byType(ActivationScreen))), TextDirection.rtl);
    expect(AppSettings(store: store).locale, AppSettings.urdu);
  });

  test('the installation ID is made once and kept (M1 FE-2)', () {
    final store = MemorySettingsStore();
    final first = AppSettings(store: store).deviceId;

    expect(first, matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
    expect(AppSettings(store: store).deviceId, first);
  });

  test('theme uses Jameel Noori Nastaleeq for Urdu letters, with taller lines, in Urdu', () {
    final theme = AppTheme.light();
    // Urdu letters come from the Nastaliq font; Latin letters and digits keep the standard font.
    expect(theme.textTheme.bodyLarge?.fontFamily, AppTheme.latinFontFamily);
    expect(theme.textTheme.bodyLarge?.fontFamilyFallback, [AppTheme.urduFontFamily]);
    expect(theme.textTheme.bodyLarge?.height, AppTheme.urduLineHeight);
    expect(theme.appBarTheme.titleTextStyle?.fontFamilyFallback, [AppTheme.urduFontFamily]);
    // Button labels too: a button text style without the font would fall back to the system font.
    expect(theme.filledButtonTheme.style?.textStyle?.resolve({})?.fontFamilyFallback, [AppTheme.urduFontFamily]);
    expect(theme.outlinedButtonTheme.style?.textStyle?.resolve({})?.fontFamilyFallback, [AppTheme.urduFontFamily]);
  });

  test('theme uses the standard Latin font and line height in English', () {
    final theme = AppTheme.light(urdu: false);
    expect(theme.textTheme.bodyLarge?.fontFamily, isNot(AppTheme.urduFontFamily));
    expect(theme.textTheme.bodyLarge?.fontFamilyFallback ?? const [], isNot(contains(AppTheme.urduFontFamily)));
    expect(theme.textTheme.bodyLarge?.height, isNot(AppTheme.urduLineHeight));
    expect(theme.filledButtonTheme.style?.minimumSize?.resolve({})?.height, AppTheme.largeControlHeight);
  });

  group('on a small phone with the real Nastaliq font', () {
    setUp(() async {
      final font = FontLoader(AppTheme.urduFontFamily)..addFont(rootBundle.load('assets/fonts/JameelNooriNastaleeq.ttf'));
      await font.load();
    });

    // 320 x 640 logical pixels: a small, low-cost Android phone.
    void smallPhone(WidgetTester tester) {
      tester.view.physicalSize = const Size(640, 1280);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
    }

    Future<void> pumpScreen(WidgetTester tester, Widget screen, {required bool english}) async {
      smallPhone(tester);
      final locale = english ? AppSettings.english : AppSettings.urdu;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(urdu: !english),
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: screen,
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> scrollToEnd(WidgetTester tester) async {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -6000));
      await tester.pumpAndSettle();
    }

    // Long Urdu names and villages, so the rows have to wrap.
    Future<LocalWoman> registerLongNames() async {
      await activateApp(services, server);
      final first = await services.patients.register(
        const RegistrationInput(
          name: 'سیدہ فاطمہ بی بی زوجہ محمد اسلم',
          age: 34,
          husbandName: 'محمد اسلم خان',
          contactNumber: '03001234567',
          pregnancyMonth: 7,
          village: 'ڈھوک سیداں والی بستی نمبر دو',
          address: 'مکان نمبر 12، گلی نمبر 3، نزد جامع مسجد',
          previousPregnancies: 4,
          previousCSections: 2,
          stillbirths: 1,
          knownConditions: 'ہائی بلڈ پریشر اور خون کی کمی',
        ),
        by: services.session.user!,
      );
      await services.patients.register(
        const RegistrationInput(name: 'Synthetic Woman With A Long English Name', age: 22, pregnancyMonth: 2, village: 'Chak Beli Khan'),
        by: services.session.user!,
      );
      return first;
    }

    for (final english in [false, true]) {
      final language = english ? 'English' : 'Urdu';

      testWidgets('the activation screen fits, with an error ($language)', (tester) async {
        final l10n = lookupAppLocalizations(english ? AppSettings.english : AppSettings.urdu);
        await pumpScreen(tester, ActivationScreen(services: services), english: english);
        await tester.ensureVisible(find.text(l10n.activateButton));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.activateButton));
        await tester.pumpAndSettle();
        expect(find.text(l10n.activateFillAll), findsOneWidget);
        await scrollToEnd(tester);
        expect(tester.takeException(), isNull);
      });

      testWidgets('the PIN screen fits, with an error ($language)', (tester) async {
        final l10n = lookupAppLocalizations(english ? AppSettings.english : AppSettings.urdu);
        await pumpScreen(tester, PinCreateScreen(services: services, mode: PinCreateMode.activation), english: english);
        for (final pin in ['123456', '654321']) {
          for (final digit in pin.split('')) {
            await tester.tap(find.text(digit));
          }
          await tester.pumpAndSettle();
        }
        expect(find.text(l10n.pinMismatch), findsOneWidget);
        await scrollToEnd(tester);
        expect(tester.takeException(), isNull);
      });

      testWidgets('the lock screen fits, while waiting after a wrong PIN ($language)', (tester) async {
        final l10n = lookupAppLocalizations(english ? AppSettings.english : AppSettings.urdu);
        await tester.runAsync(() async {
          await activateApp(services, server);
          services.session.lock();
          await services.session.closed;
          await services.session.unlock('000000');
        });
        await pumpScreen(tester, LockScreen(services: services), english: english);
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pump();
        expect(find.text(l10n.lockWrongPin), findsOneWidget);
        expect(find.text(l10n.emergencyCallButton), findsOneWidget);
        await scrollToEnd(tester);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox()); // stops the countdown
      });

      testWidgets('the PIN reset screen fits, with an error ($language)', (tester) async {
        final l10n = lookupAppLocalizations(english ? AppSettings.english : AppSettings.urdu);
        await tester.runAsync(() async {
          await activateApp(services, server);
          services.session.lock();
        });
        await pumpScreen(tester, PinResetScreen(services: services), english: english);
        await tester.enterText(find.byType(TextFormField), '12345678');
        await tester.ensureVisible(find.text(l10n.resetCheckButton));
        await tester.runAsync(() async {
          await tester.tap(find.text(l10n.resetCheckButton));
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });
        await tester.pumpAndSettle();
        expect(find.text(l10n.resetWrongReply), findsOneWidget);
        await scrollToEnd(tester);
        expect(tester.takeException(), isNull);
      });

      testWidgets('the sign-in-again screen fits ($language)', (tester) async {
        await tester.runAsync(() => activateApp(services, server));
        await pumpScreen(tester, SignInAgainScreen(services: services), english: english);
        await scrollToEnd(tester);
        expect(tester.takeException(), isNull);
      });

      testWidgets('the home screen fits ($language)', (tester) async {
        await tester.runAsync(() => activateApp(services, server));
        await pumpScreen(tester, HomeScreen(services: services), english: english);
        await scrollToEnd(tester);
        expect(tester.takeException(), isNull);
      });

      testWidgets('the settings fit ($language)', (tester) async {
        await tester.runAsync(() => activateApp(services, server));
        await pumpScreen(tester, SettingsScreen(services: services), english: english);
        await scrollToEnd(tester);
        expect(tester.takeException(), isNull);
      });

      testWidgets('the widget kit fits ($language)', (tester) async {
        await pumpScreen(tester, DevHomeScreen(services: services), english: english);
        await tester.tap(find.text(english ? 'Widget kit' : 'ویجٹ کٹ'));
        await tester.pumpAndSettle();
        expect(find.byType(WidgetKitScreen), findsOneWidget);
        await scrollToEnd(tester);
        expect(tester.takeException(), isNull);
      });

      testWidgets('every step of the registration fits, errors shown ($language)', (tester) async {
        await tester.runAsync(registerLongNames);
        await pumpScreen(tester, RegisterScreen(services: services), english: english);
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pumpAndSettle();
        final l10n = lookupAppLocalizations(english ? AppSettings.english : AppSettings.urdu);
        Future<void> next() async {
          await tester.tap(find.text(l10n.stepNext));
          await tester.pumpAndSettle();
        }

        await next();
        expect(find.text(l10n.regErrorAge), findsOneWidget);
        await scrollToEnd(tester);
        expect(tester.takeException(), isNull);
        await tester.enterText(find.byType(TextFormField).at(0), 'سیدہ فاطمہ بی بی زوجہ محمد اسلم');
        await tester.enterText(find.byType(TextFormField).at(1), '34');
        await next();

        await next();
        expect(find.text(l10n.regErrorChooseMonth), findsOneWidget);
        await tester.tap(find.widgetWithText(OutlinedButton, '7'));
        await tester.pumpAndSettle();
        expect(find.text(l10n.regMonthChosen(7)), findsOneWidget);
        expect(tester.takeException(), isNull);
        await next();

        expect(find.text(l10n.regSameHome), findsOneWidget, reason: 'women are registered, so the option shows');
        await next();
        expect(find.text(l10n.regErrorRequired), findsOneWidget);
        await scrollToEnd(tester);
        expect(tester.takeException(), isNull);
        await tester.enterText(find.byType(TextFormField).first, 'ڈھوک سیداں والی بستی نمبر دو');
        await next();

        for (var i = 0; i < 2; i++) {
          await tester.tap(find.byTooltip(l10n.stepperMore).at(1));
          await tester.pump();
        }
        await tester.pumpAndSettle();
        expect(find.text(l10n.regErrorMoreThanPregnancies), findsOneWidget);
        await scrollToEnd(tester);
        expect(tester.takeException(), isNull);
      });

      testWidgets('the saved screen fits ($language)', (tester) async {
        final woman = (await tester.runAsync(registerLongNames))!;
        await pumpScreen(tester, RegistrationSavedScreen(services: services, woman: woman), english: english);
        await scrollToEnd(tester);
        expect(tester.takeException(), isNull);
      });

      testWidgets('the patient list fits ($language)', (tester) async {
        await tester.runAsync(registerLongNames);
        await pumpScreen(tester, PatientListScreen(services: services), english: english);
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pumpAndSettle();
        expect(find.textContaining('LHW-DEMO-001-000'), findsWidgets);
        await scrollToEnd(tester);
        expect(find.textContaining('LHW-DEMO-001-000'), findsWidgets);
        expect(tester.takeException(), isNull);
      });

      testWidgets('the patient file fits, without GPS yet ($language)', (tester) async {
        final woman = (await tester.runAsync(registerLongNames))!;
        await pumpScreen(tester, PatientFileScreen(services: services, womanId: woman.id), english: english);
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pumpAndSettle();
        await scrollToEnd(tester);
        expect(tester.takeException(), isNull);
      });

      testWidgets('the visit form fits, with errors and the range check dialog ($language)', (tester) async {
        final l10n = lookupAppLocalizations(english ? AppSettings.english : AppSettings.urdu);
        final woman = (await tester.runAsync(registerLongNames))!;
        final file = (await tester.runAsync(() => services.patients.file(woman.id)))!;
        final ranges = (await tester.runAsync(VisitRanges.load))!;
        await pumpScreen(
          tester,
          VisitScreen(
            services: services,
            pregnancyId: file.pregnancy!.id,
            title: '${woman.name} · ${woman.patientCode}',
            ranges: ranges,
          ),
          english: english,
        );
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pumpAndSettle();

        // The keyboard closed, so no field scrolls itself back into view.
        Future<void> tapButton(String label) async {
          await tester.pumpAndSettle();
          FocusManager.instance.primaryFocus?.unfocus();
          await tester.pumpAndSettle();
          await tester.tap(find.text(label));
          await tester.pumpAndSettle();
        }

        // Every vital refused at once: the longest error under each field.
        for (final (index, text) in ['999', '999', '999', '99', '999', '99'].indexed) {
          final field = find.byType(TextFormField).at(index);
          await tester.ensureVisible(field);
          await tester.enterText(field, text);
        }
        await tapButton(l10n.visitNextSigns);
        expect(find.text(l10n.sugarErrorSource), findsOneWidget);
        await scrollToEnd(tester);
        expect(tester.takeException(), isNull);

        // Every vital unusual at once: the longest dialog.
        for (final (index, text) in ['290', '190', '240', '43.5', '240', '45'].indexed) {
          final field = find.byType(TextFormField).at(index);
          await tester.ensureVisible(field);
          await tester.enterText(field, text);
        }
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text(l10n.sugarSourceGlucometer));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.sugarSourceGlucometer));
        await tapButton(l10n.visitNextSigns);
        expect(find.text(l10n.rangeCheckTitle), findsOneWidget);
        await tester.drag(find.byType(Scrollable).last, const Offset(0, -3000));
        await tester.pumpAndSettle();
        expect(find.text(l10n.rangeCheckConfirm), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tapButton(l10n.rangeCheckConfirm);

        // Step 2, then step 3 with every question unanswered.
        expect(find.text(l10n.stepOf(2, 3, l10n.visitSymptomsSection)), findsOneWidget);
        await scrollToEnd(tester);
        expect(tester.takeException(), isNull);
        await tapButton(l10n.visitNextDanger);
        await tapButton(l10n.visitSaveButton);
        expect(find.text(l10n.dangerUnanswered), findsWidgets);
        await scrollToEnd(tester);
        expect(find.text(l10n.decisionSupportNote), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('the pulse counter fits, counting and done ($language)', (tester) async {
        final l10n = lookupAppLocalizations(english ? AppSettings.english : AppSettings.urdu);
        await pumpScreen(tester, const PulseCounterScreen(), english: english);
        expect(tester.takeException(), isNull);
        for (var i = 0; i < 40; i++) {
          await tester.tap(find.text(l10n.pulseTapButton));
          await tester.pump(const Duration(milliseconds: 400));
        }
        await tester.pump(const Duration(seconds: 30));
        expect(find.text('40 × 2 = 80 ${l10n.unitPerMinute}'), findsOneWidget);
        await scrollToEnd(tester);
        expect(tester.takeException(), isNull);
      });

      testWidgets('the patient file with visits fits ($language)', (tester) async {
        final woman = (await tester.runAsync(registerLongNames))!;
        await tester.runAsync(() async {
          final pregnancy = (await services.patients.file(woman.id))!.pregnancy!;
          for (final systolic in [118, 165]) {
            await services.visits.record(
              VisitInput(
                pregnancyId: pregnancy.id,
                systolicBpMmhg: systolic,
                diastolicBpMmhg: 112,
                weightKg: 72.5,
                temperatureC: 38.4,
                pulseBpm: 124,
                bloodSugarMmolL: 11.2,
                fetalMovement: 'absent',
                swelling: true,
                bleeding: true,
                fever: true,
                anaemiaSigns: 'severe',
                urineSymptoms: true,
              ),
              by: services.session.user!,
            );
          }
        });
        await pumpScreen(tester, PatientFileScreen(services: services, womanId: woman.id), english: english);
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pumpAndSettle();
        await scrollToEnd(tester);
        expect(find.textContaining('/112 '), findsWidgets);
        expect(tester.takeException(), isNull);
      });

      testWidgets('the sync test screen fits ($language)', (tester) async {
        await tester.runAsync(() => activateApp(services, server));
        await pumpScreen(tester, SyncTestScreen(services: services), english: english);
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pumpAndSettle();
        await scrollToEnd(tester);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
