import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediqore/app.dart';
import 'package:mediqore/app_services.dart';
import 'package:mediqore/data/patient_repository.dart';
import 'package:mediqore/l10n/app_localizations.dart';
import 'package:mediqore/location/location_service.dart';
import 'package:mediqore/screens/patient_file_screen.dart';
import 'package:mediqore/screens/patient_list_screen.dart';
import 'package:mediqore/screens/register_screen.dart';
import 'package:mediqore/screens/registration_saved_screen.dart';
import 'package:mediqore/settings/app_settings.dart';
import 'package:mediqore/widgets/form_fields.dart';

import '../helpers.dart';
import '../support/fake_location_service.dart';
import '../support/fake_sync_server.dart';

/// Module 2 in the whole app, offline, in Urdu: register a woman, see her ID,
/// open her file, find her in the list.
void main() {
  final l10n = lookupAppLocalizations(AppSettings.urdu);
  late FakeSyncServer server;
  late FakeLocationService gps;
  late AppServices services;

  setUp(() {
    server = FakeSyncServer();
    gps = FakeLocationService();
    services = testServices(server, null, null, gps);
  });
  tearDown(() => services.db.close());

  // Drift and the fake HTTP client finish their work outside the test clock.
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

  // Signed in on an approved phone, then offline, on the home screen.
  Future<void> pumpHome(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.runAsync(() => signInApproved(services, server));
    server.offline = true;
    await tester.pumpWidget(MediQoreApp(services: services));
    await settle(tester);
  }

  Finder field(String label) => find.descendant(
        of: find.byWidgetPredicate((w) => (w is AppTextField && w.label == label) || (w is NumberField && w.label == label)),
        matching: find.byType(TextFormField),
      );

  Future<void> enter(WidgetTester tester, String label, String text) async {
    await tester.ensureVisible(field(label));
    await tester.enterText(field(label), text);
  }

  Future<void> chooseMonth(WidgetTester tester, int month) async {
    final dropdown = find.byWidgetPredicate((w) => w is DropdownField<int>);
    await tester.ensureVisible(dropdown);
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.regMonthOption(month)).last);
    await tester.pumpAndSettle();
  }

  Future<void> fillRequired(WidgetTester tester, {String name = 'Synthetic Woman', String village = 'Dhok Syedan'}) async {
    await enter(tester, l10n.regName, name);
    await enter(tester, l10n.regAge, '26');
    await chooseMonth(tester, 3);
    await enter(tester, l10n.regVillage, village);
  }

  testWidgets('registers a woman offline, shows her patient ID, her file and her place in the list (M2 FE-1–3)', (tester) async {
    await pumpHome(tester);

    await tapAndWait(tester, find.text(l10n.homeRegisterButton));
    expect(find.byType(RegisterScreen), findsOneWidget);
    await fillRequired(tester);
    await enter(tester, l10n.regHusbandName, 'Synthetic Husband');
    await enter(tester, l10n.regContactNumber, '0300 123-4567');
    await enter(tester, l10n.regAddress, 'House 12');
    await enter(tester, l10n.regPreviousPregnancies, '2');
    await enter(tester, l10n.regPreviousCSections, '1');
    await enter(tester, l10n.regKnownConditions, 'Asthma');
    await tapAndWait(tester, find.text(l10n.gpsCaptureButton));
    expect(find.text(l10n.gpsCaptured(8)), findsOneWidget);
    expect(find.text('33.684412, 73.047912'), findsOneWidget);

    await tapAndWait(tester, find.text(l10n.regSaveButton));

    expect(find.byType(RegistrationSavedScreen), findsOneWidget);
    expect(find.text('LHW-DEMO-001-0001'), findsOneWidget);
    expect(find.text(l10n.savedOnPhone), findsOneWidget);
    expect(await tester.runAsync(services.db.pendingCount), 4);

    await tapAndWait(tester, find.text(l10n.savedOpenFile));
    expect(find.byType(PatientFileScreen), findsOneWidget);
    expect(find.text('Synthetic Woman'), findsOneWidget);
    expect(find.text('03001234567'), findsOneWidget, reason: 'spaces and dashes are removed');
    expect(find.text('33.684412, 73.047912'), findsOneWidget);
    expect(find.text('Asthma'), findsOneWidget);
    expect(find.text(l10n.syncWaiting), findsOneWidget);

    tester.state<NavigatorState>(find.byType(Navigator).first).pop(); // the phone's back gesture
    await settle(tester);
    await tapAndWait(tester, find.text(l10n.homePatientsButton));
    expect(find.byType(PatientListScreen), findsOneWidget);
    expect(find.text('Dhok Syedan'), findsOneWidget, reason: 'the village heading');
    expect(find.text('LHW-DEMO-001-0001'), findsOneWidget);
  });

  testWidgets('explains what to fix and saves nothing while the form has errors', (tester) async {
    await pumpHome(tester);
    await tapAndWait(tester, find.text(l10n.homeRegisterButton));

    await tapAndWait(tester, find.text(l10n.regSaveButton));

    expect(find.text(l10n.regErrorFix), findsOneWidget);
    expect(find.text(l10n.regErrorRequired), findsNWidgets(2), reason: 'name and village');
    expect(find.text(l10n.regErrorAge), findsOneWidget);
    expect(find.text(l10n.regErrorChooseMonth), findsOneWidget);

    await fillRequired(tester);
    await enter(tester, l10n.regContactNumber, '12345');
    await enter(tester, l10n.regPreviousPregnancies, '1');
    await enter(tester, l10n.regPreviousCSections, '2');
    await enter(tester, l10n.regStillbirths, '3');
    await tapAndWait(tester, find.text(l10n.regSaveButton));

    expect(find.text(l10n.regErrorContact), findsOneWidget);
    expect(find.text(l10n.regErrorMoreThanPregnancies), findsNWidgets(2));
    expect(find.byType(RegisterScreen), findsOneWidget);
    expect(await tester.runAsync(services.db.pendingCount), 0);
  });

  testWidgets('saves without GPS when the location is off, and records it later from the file (M2 FE-3)', (tester) async {
    gps.result = const LocationResult.failed(LocationProblem.serviceOff);
    await pumpHome(tester);
    await tapAndWait(tester, find.text(l10n.homeRegisterButton));
    await fillRequired(tester);

    await tapAndWait(tester, find.text(l10n.gpsCaptureButton));
    expect(find.text(l10n.gpsServiceOff), findsOneWidget);
    await tapAndWait(tester, find.text(l10n.gpsOpenSettings));
    expect(gps.openedSettings, [LocationProblem.serviceOff]);

    await tapAndWait(tester, find.text(l10n.regSaveButton));
    await tapAndWait(tester, find.text(l10n.savedOpenFile));
    expect(find.text(l10n.gpsNotRecorded), findsOneWidget);

    gps.result = const LocationResult.found(LocationFix(latitude: 33.7, longitude: 73.1, accuracyMetres: 12));
    await tapAndWait(tester, find.text(l10n.gpsCaptureButton));

    expect(find.text('33.700000, 73.100000'), findsOneWidget);
    expect(find.text(l10n.fileLocationSaved), findsOneWidget);
    final [woman] = await tester.runAsync(services.patients.list) ?? [];
    expect(woman.household?.latitude, 33.7);
  });

  testWidgets('a second woman can be registered in the same home', (tester) async {
    await pumpHome(tester);
    final first = (await tester.runAsync(() => services.patients.register(
          const RegistrationInput(name: 'First Woman', age: 30, pregnancyMonth: 5, village: 'Chak Beli'),
          by: services.session.user!,
        )))!;
    await tapAndWait(tester, find.text(l10n.homeRegisterButton));
    await enter(tester, l10n.regName, 'Second Woman');
    await enter(tester, l10n.regAge, '24');
    await chooseMonth(tester, 2);

    await tapAndWait(tester, find.text(l10n.regSameHome));
    expect(field(l10n.regVillage), findsNothing, reason: 'the home is already recorded');
    final whose = find.byWidgetPredicate((w) => w is DropdownField<String>);
    await tester.tap(whose);
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.regWomanOption('First Woman', 'LHW-DEMO-001-0001')).last);
    await tester.pumpAndSettle();
    await tapAndWait(tester, find.text(l10n.regSaveButton));

    expect(find.text('LHW-DEMO-001-0002'), findsOneWidget);
    final women = (await tester.runAsync(services.patients.list))!;
    expect(women.map((p) => p.woman.householdId).toSet(), {first.householdId});
  });

  testWidgets('the list finds women by name, ID or village and says when nothing matches', (tester) async {
    await pumpHome(tester);
    await tester.runAsync(() async {
      for (final (name, village) in [('Amina', 'Dhok Syedan'), ('Bushra', 'Chak Beli'), ('Kiran', 'Chak Beli')]) {
        await services.patients.register(
          RegistrationInput(name: name, age: 25, pregnancyMonth: 4, village: village),
          by: services.session.user!,
        );
      }
    });
    await tapAndWait(tester, find.text(l10n.homePatientsButton));
    expect(find.text(l10n.patientsCount(3)), findsOneWidget);

    await tester.runAsync(() async {
      await tester.enterText(find.byType(TextField).first, 'chak');
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(find.text('Bushra'), findsOneWidget);
    expect(find.text('Amina'), findsNothing);

    await tester.runAsync(() async {
      await tester.enterText(find.byType(TextField).first, 'nobody');
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(find.text(l10n.patientsNoMatch), findsOneWidget);
  });

  testWidgets('an account without an LHW code sees no registration buttons', (tester) async {
    server.lhwCode = null;
    await pumpHome(tester);

    expect(find.text(l10n.homeRegisterButton), findsNothing);
    expect(find.text(l10n.homePatientsButton), findsNothing);
  });
}
