import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediqore/app.dart';
import 'package:mediqore/app_services.dart';
import 'package:mediqore/data/app_database.dart';
import 'package:mediqore/data/patient_repository.dart';
import 'package:mediqore/l10n/app_localizations.dart';
import 'package:mediqore/screens/patient_file_screen.dart';
import 'package:mediqore/screens/pulse_counter_screen.dart';
import 'package:mediqore/screens/visit_screen.dart';
import 'package:mediqore/theme/app_colors.dart';
import 'package:mediqore/settings/app_settings.dart';
import 'package:mediqore/widgets/form_fields.dart';

import '../helpers.dart';
import '../support/fake_sync_server.dart';

/// Module 3 in the whole app, offline: a visit from the woman's file, with the
/// range checks (FE-1) and its sync state (FE-2).
void main() {
  final ur = lookupAppLocalizations(AppSettings.urdu);
  late FakeSyncServer server;
  late AppServices services;

  setUp(() {
    server = FakeSyncServer();
    services = testServices(server);
  });
  tearDown(() => services.dispose());

  // Drift, the fake HTTP client and the config file finish outside the test clock.
  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();
  }

  Future<void> tapAndWait(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(finder);
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
    await settle(tester);
  }

  // Signed in, a woman registered, offline, on the home screen.
  // Month 8 by default: past the gestational age at which fetal movement is asked.
  Future<void> pumpHome(WidgetTester tester, {int month = 8}) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await activateApp(services, server);
      await services.patients.register(
        RegistrationInput(name: 'Synthetic Woman', age: 26, pregnancyMonth: month, village: 'Dhok Syedan'),
        by: services.session.user!,
      );
    });
    server.offline = true;
    await tester.pumpWidget(MediQoreApp(services: services));
    await settle(tester);
  }

  // Then her file and the visit form.
  Future<void> openVisitForm(WidgetTester tester, {AppLocalizations? l10n, int month = 8}) async {
    l10n ??= ur;
    await pumpHome(tester, month: month);
    await tapAndWait(tester, find.text(l10n.homePatientsButton));
    await tapAndWait(tester, find.text('Synthetic Woman'));
    expect(find.byType(PatientFileScreen), findsOneWidget);
    expect(find.text(l10n.fileNoVisits), findsOneWidget);
    await tapAndWait(tester, find.text(l10n.fileNewVisitButton));
    expect(find.byType(VisitScreen), findsOneWidget);
  }

  Finder vital(String label) =>
      find.descendant(of: find.byWidgetPredicate((w) => w is VitalField && w.label == label), matching: find.byType(TextFormField));

  Future<void> enter(WidgetTester tester, String label, String text) async {
    await tester.ensureVisible(vital(label));
    await tester.enterText(vital(label), text);
  }

  Future<void> fillVitals(WidgetTester tester, AppLocalizations l10n, {String systolic = '118'}) async {
    await enter(tester, l10n.fieldSystolicBp, systolic);
    await enter(tester, l10n.fieldDiastolicBp, '76');
    await enter(tester, l10n.fieldWeight, '61.5');
    await enter(tester, l10n.fieldTemperature, '36.9');
    await enter(tester, l10n.fieldPulse, '84');
  }

  Future<List<LocalVisit>> savedVisits(WidgetTester tester) async =>
      (await tester.runAsync(() => services.db.select(services.db.visits).get()))!;

  Future<void> next(WidgetTester tester, String label) => tapAndWait(tester, find.text(label));

  // Step 3: answers every danger sign "no", or "yes" for those in [yes].
  Future<void> answerDangerSigns(WidgetTester tester, {Set<String> yes = const {}}) async {
    for (final sign in dangerSigns) {
      final (label, _) = dangerSignLabel(ur, sign);
      final card = find.ancestor(of: find.text(label), matching: find.byType(Card)).first;
      final button = find.descendant(of: card, matching: find.text(yes.contains(sign) ? ur.answerYes : ur.answerNo));
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
    }
  }

  // A whole visit with normal values: step 1, step 2 as it is, step 3 all "no".
  Future<void> recordNormalVisit(WidgetTester tester) async {
    await fillVitals(tester, ur);
    await next(tester, ur.visitNextSigns);
    await next(tester, ur.visitNextDanger);
    await answerDangerSigns(tester);
    await tapAndWait(tester, find.text(ur.visitSaveButton));
  }

  testWidgets('records a visit offline in three steps and lists it as not sent yet (M3 FE-1, FE-2)', (tester) async {
    await openVisitForm(tester);
    expect(find.text(ur.stepOf(1, 3, ur.visitVitalsSection)), findsOneWidget);
    await fillVitals(tester, ur);
    // A blood sugar typed in mg/dL, from a lab report.
    await tester.tap(find.widgetWithText(OutlinedButton, ur.unitMgDl));
    await tester.pumpAndSettle();
    await enter(tester, ur.fieldBloodSugar, '140');
    await tester.pumpAndSettle();
    await tester.tap(find.text(ur.sugarSourceLab));
    await tester.pumpAndSettle();
    await next(tester, ur.visitNextSigns);

    expect(find.text(ur.stepOf(2, 3, ur.visitSymptomsSection)), findsOneWidget);
    await tester.tap(find.text(ur.fetalMovementReduced));
    await tester.pumpAndSettle();
    final swelling = find.ancestor(of: find.text(ur.fieldSwelling), matching: find.byType(Card)).first;
    await tester.tap(find.descendant(of: swelling, matching: find.text(ur.answerYes)));
    await tester.pumpAndSettle();
    await next(tester, ur.visitNextDanger);

    expect(find.text(ur.stepOf(3, 3, ur.visitStepDanger)), findsOneWidget);
    expect(find.text(ur.decisionSupportNote), findsOneWidget, reason: 'LI-5');
    await answerDangerSigns(tester, yes: {'severeHeadache'});
    await tapAndWait(tester, find.text(ur.visitSaveButton));

    expect(find.byType(PatientFileScreen), findsOneWidget);
    expect(find.text(ur.visitSaved), findsOneWidget);
    expect(find.text('118/76 ${ur.unitMmHg}'), findsOneWidget);
    expect(find.textContaining(ur.fieldSwelling), findsOneWidget);
    expect(find.textContaining(ur.dangerSevereHeadache), findsOneWidget);
    expect(find.text(ur.syncWaiting), findsWidgets);
    final [visit] = await savedVisits(tester);
    expect(
      (visit.systolicBpMmhg, visit.diastolicBpMmhg, visit.weightKg, visit.temperatureC, visit.pulseBpm),
      (118, 76, 61.5, 36.9, 84),
    );
    expect(
      (visit.bloodSugarValue, visit.bloodSugarUnit, visit.bloodSugarSource, visit.bloodSugarMeasuredOn),
      (140.0, 'mg_dl', 'lab_report', PatientRepository.calendarDate(DateTime.now())),
      reason: '140 mg/dL is stored as 140 in the unit it was recorded in (M3 FE-1)',
    );
    expect((visit.fetalMovement, visit.swelling, visit.bleeding), ('reduced', true, false));
    expect((visit.convulsions, visit.severeHeadache, visit.feverWithWeakness), (false, true, false));
    expect(await tester.runAsync(services.db.pendingCount), 5, reason: 'the registration and the visit wait for sync');
  });

  testWidgets('a vital outside its normal range is highlighted, without stopping the form (SRS FR3.3)', (tester) async {
    await openVisitForm(tester);
    await fillVitals(tester, ur, systolic: '150');
    await tester.pumpAndSettle();

    expect(find.text(ur.vitalAboveNormal), findsOneWidget, reason: 'BP from 140 is outside the normal range of the table');
    await enter(tester, ur.fieldSystolicBp, '118');
    await tester.pumpAndSettle();
    expect(find.text(ur.vitalAboveNormal), findsNothing);
    await enter(tester, ur.fieldPulse, '52');
    await tester.pumpAndSettle();
    expect(find.text(ur.vitalBelowNormal), findsOneWidget);
  });

  testWidgets('early in pregnancy, fetal movement is "not applicable yet" and nothing is recorded (M3 FE-1)', (tester) async {
    await openVisitForm(tester, month: 4);
    await fillVitals(tester, ur);
    await next(tester, ur.visitNextSigns);

    final weeks = services.clinicalRules!.fetalMovementFromWeeks;
    expect(find.text(ur.fetalMovementNotYet(weeks)), findsOneWidget);
    expect(find.text(ur.fetalMovementReduced), findsNothing);
    await next(tester, ur.visitNextDanger);
    await answerDangerSigns(tester);
    await tapAndWait(tester, find.text(ur.visitSaveButton));

    final [visit] = await savedVisits(tester);
    expect(visit.fetalMovement, isNull);
  });

  testWidgets('step 1 refuses missing and impossible values with the reason, and does not move on', (tester) async {
    await openVisitForm(tester);

    await next(tester, ur.visitNextSigns);
    expect(find.text(ur.regErrorRequired), findsNWidgets(5), reason: 'every vital, pulse included, but blood sugar');

    await fillVitals(tester, ur);
    await enter(tester, ur.fieldTemperature, '98.6'); // Fahrenheit: impossible in °C
    await enter(tester, ur.fieldDiastolicBp, '130');
    await enter(tester, ur.fieldBloodSugar, '6.1');
    await tester.pumpAndSettle();
    await next(tester, ur.visitNextSigns);

    expect(find.text(ur.visitErrorNotPossible('25', '45')), findsOneWidget);
    expect(find.text(ur.visitErrorDiastolic), findsOneWidget);
    expect(find.text(ur.sugarErrorSource), findsOneWidget, reason: 'a blood sugar needs its source');
    expect(find.text(ur.stepOf(1, 3, ur.visitVitalsSection)), findsOneWidget);
    expect(await savedVisits(tester), isEmpty);
  });

  testWidgets('step 3 needs an answer to every danger sign; a yes turns its card red', (tester) async {
    await openVisitForm(tester);
    await fillVitals(tester, ur);
    await next(tester, ur.visitNextSigns);
    await next(tester, ur.visitNextDanger);

    await tapAndWait(tester, find.text(ur.visitSaveButton));
    expect(find.text(ur.dangerUnanswered), findsNWidgets(6));
    expect(await savedVisits(tester), isEmpty);

    final card = find.ancestor(of: find.text(ur.dangerConvulsions), matching: find.byType(Card)).first;
    await tester.tap(find.descendant(of: card, matching: find.text(ur.answerYes)));
    await tester.pumpAndSettle();
    expect(tester.widget<Card>(card).color, AppColors.statusProblemBackground);
    expect(find.text(ur.dangerUnanswered), findsNWidgets(5));
  });

  testWidgets('the 30-second counter fills in the pulse (M3 FE-1)', (tester) async {
    await openVisitForm(tester);
    await tester.tap(find.text(ur.pulseCountButton(30)));
    await tester.pumpAndSettle();
    expect(find.byType(PulseCounterScreen), findsOneWidget);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, ur.pulseUse)).onPressed, isNull);

    for (var i = 0; i < 41; i++) {
      await tester.tap(find.text(ur.pulseTapButton));
      await tester.pump(const Duration(milliseconds: 500));
    }
    await tester.pump(const Duration(seconds: 15));
    expect(find.text(ur.pulseDone(30)), findsOneWidget);
    expect(find.text('41 × 2 = 82 ${ur.unitPerMinute}'), findsOneWidget);

    await tester.tap(find.text(ur.pulseUse));
    await tester.pumpAndSettle();
    expect(find.byType(VisitScreen), findsOneWidget);
    expect(tester.widget<TextFormField>(vital(ur.fieldPulse)).controller!.text, '82');
  });

  testWidgets('a value outside the usual range asks for confirmation: correct it, or confirm and go on (M3 FE-1)', (
    tester,
  ) async {
    await openVisitForm(tester);
    await fillVitals(tester, ur, systolic: '255');

    await next(tester, ur.visitNextSigns);
    expect(find.text(ur.rangeCheckTitle), findsOneWidget);
    expect(find.text('255 ${ur.unitMmHg}'), findsOneWidget);
    expect(find.text('60–250 ${ur.unitMmHg}'), findsOneWidget, reason: 'the roadmap example: systolic BP 60–250');

    await tapAndWait(tester, find.text(ur.rangeCheckCorrect));
    expect(find.text(ur.stepOf(1, 3, ur.visitVitalsSection)), findsOneWidget);

    await next(tester, ur.visitNextSigns);
    await tapAndWait(tester, find.text(ur.rangeCheckConfirm));
    await next(tester, ur.visitNextDanger);
    await answerDangerSigns(tester);
    await tapAndWait(tester, find.text(ur.visitSaveButton));
    expect(find.byType(PatientFileScreen), findsOneWidget);
    expect((await savedVisits(tester)).single.systolicBpMmhg, 255);
  });

  testWidgets('a visit the server holds for the supervisor says so in the file (M3 FE-2)', (tester) async {
    await openVisitForm(tester);
    await recordNormalVisit(tester);
    final [visit] = await savedVisits(tester);
    server
      ..offline = false
      ..holdIds.add(visit.id);

    final report = (await tester.runAsync(services.session.sync))!;
    expect(report.held, 1);
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await settle(tester);
    await tapAndWait(tester, find.text('Synthetic Woman'));

    expect(find.text(ur.syncHeld), findsOneWidget);
  });
}
