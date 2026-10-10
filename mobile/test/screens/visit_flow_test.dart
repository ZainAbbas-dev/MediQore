import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediqore/app.dart';
import 'package:mediqore/app_services.dart';
import 'package:mediqore/data/app_database.dart';
import 'package:mediqore/data/patient_repository.dart';
import 'package:mediqore/l10n/app_localizations.dart';
import 'package:mediqore/screens/patient_file_screen.dart';
import 'package:mediqore/screens/visit_screen.dart';
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
  Future<void> pumpHome(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await activateApp(services, server);
      await services.patients.register(
        const RegistrationInput(name: 'Synthetic Woman', age: 26, pregnancyMonth: 5, village: 'Dhok Syedan'),
        by: services.session.user!,
      );
    });
    server.offline = true;
    await tester.pumpWidget(MediQoreApp(services: services));
    await settle(tester);
  }

  // Then her file and the visit form.
  Future<void> openVisitForm(WidgetTester tester, {AppLocalizations? l10n}) async {
    l10n ??= ur;
    await pumpHome(tester);
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

  testWidgets('records a visit offline from the woman\'s file and lists it as not sent yet (M3 FE-1, FE-2)', (tester) async {
    await openVisitForm(tester);
    await fillVitals(tester, ur);
    final fetal = find.byWidgetPredicate((w) => w is DropdownField<String> && w.label == ur.fieldFetalMovement);
    await tester.ensureVisible(fetal);
    await tester.tap(fetal);
    await tester.pumpAndSettle();
    await tester.tap(find.text(ur.fetalMovementReduced).last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(ur.fieldSwelling));
    await tester.tap(find.text(ur.fieldSwelling));
    await tester.pumpAndSettle();

    await tapAndWait(tester, find.text(ur.visitSaveButton));

    expect(find.byType(PatientFileScreen), findsOneWidget);
    expect(find.text(ur.visitSaved), findsOneWidget);
    expect(find.text('118/76 ${ur.unitMmHg}'), findsOneWidget);
    expect(find.text('61.5 ${ur.unitKg}'), findsOneWidget);
    expect(find.textContaining(ur.fieldSwelling), findsOneWidget);
    expect(find.text(ur.syncWaiting), findsWidgets);
    final [visit] = await savedVisits(tester);
    expect((visit.systolicBpMmhg, visit.diastolicBpMmhg, visit.weightKg, visit.temperatureC, visit.pulseBpm), (118, 76, 61.5, 36.9, 84));
    expect((visit.bloodSugarMmolL, visit.fetalMovement, visit.swelling, visit.bleeding), (null, 'reduced', true, false));
    expect(await tester.runAsync(services.db.pendingCount), 5, reason: 'the registration and the visit wait for sync');
  });

  testWidgets('missing and impossible values are refused with the reason, and nothing is saved', (tester) async {
    await openVisitForm(tester);

    await tapAndWait(tester, find.text(ur.visitSaveButton));
    expect(find.text(ur.regErrorRequired), findsNWidgets(5), reason: 'every vital but blood sugar is required');
    expect(find.text(ur.regErrorFix), findsOneWidget);

    await fillVitals(tester, ur);
    await enter(tester, ur.fieldTemperature, '98.6'); // Fahrenheit: impossible in °C
    await enter(tester, ur.fieldDiastolicBp, '130');
    await tapAndWait(tester, find.text(ur.visitSaveButton));

    expect(find.text(ur.visitErrorNotPossible('25', '45')), findsOneWidget);
    expect(find.text(ur.visitErrorDiastolic), findsOneWidget);
    expect(find.byType(VisitScreen), findsOneWidget);
    expect(await savedVisits(tester), isEmpty);
  });

  testWidgets('a value outside the usual range asks for confirmation: correct it, or confirm and save (M3 FE-1)', (tester) async {
    await openVisitForm(tester);
    await fillVitals(tester, ur, systolic: '255');

    await tapAndWait(tester, find.text(ur.visitSaveButton));
    expect(find.text(ur.rangeCheckTitle), findsOneWidget);
    expect(find.text('255 ${ur.unitMmHg}'), findsOneWidget);
    expect(find.text('60–250 ${ur.unitMmHg}'), findsOneWidget, reason: 'the roadmap example: systolic BP 60–250');
    expect(find.text(ur.fieldWeight), findsOneWidget, reason: 'only the unusual value is listed, not weight');

    await tapAndWait(tester, find.text(ur.rangeCheckCorrect));
    expect(find.byType(VisitScreen), findsOneWidget);
    expect(await savedVisits(tester), isEmpty);

    await tapAndWait(tester, find.text(ur.visitSaveButton));
    await tapAndWait(tester, find.text(ur.rangeCheckConfirm));
    expect(find.byType(PatientFileScreen), findsOneWidget);
    expect((await savedVisits(tester)).single.systolicBpMmhg, 255);
  });

  testWidgets('a visit the server holds for the supervisor says so in the file (M3 FE-2)', (tester) async {
    await openVisitForm(tester);
    await fillVitals(tester, ur);
    await tapAndWait(tester, find.text(ur.visitSaveButton));
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
