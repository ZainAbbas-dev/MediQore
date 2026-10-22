import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart' show DateFormat;
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
import 'package:mediqore/widgets/step_scaffold.dart';

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
  tearDown(() => services.dispose());

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
    await tester.runAsync(() => activateApp(services, server));
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

  Future<void> next(WidgetTester tester) => tapAndWait(tester, find.text(l10n.stepNext));

  DateTime today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  // The notice under the pregnancy step: estimated delivery date and weeks (M2 FE-1).
  String eddNotice(DateTime edd) {
    final gestation = services.clinicalRules!.gestationalAge;
    return l10n.regEddResult('\u2066${DateFormat.yMMMd('ur').format(edd)}\u2069', gestation.completedWeeksOn(edd, today()));
  }

  Future<void> chooseMonth(WidgetTester tester, int month) async {
    await tester.tap(find.widgetWithText(OutlinedButton, '$month'));
    await tester.pumpAndSettle();
  }

  Future<void> setCounter(WidgetTester tester, String label, int value) async {
    final counter = find.byWidgetPredicate((w) => w is CounterField && w.label == label);
    await tester.ensureVisible(counter);
    final current = tester.widget<CounterField>(counter).value;
    final button = find.descendant(of: counter, matching: find.byTooltip(value > current ? l10n.stepperMore : l10n.stepperLess));
    for (var i = 0; i < (value - current).abs(); i++) {
      await tester.tap(button);
      await tester.pump();
    }
  }

  testWidgets('registers a woman offline in four steps, shows her ID, her file with risk factors and her place in the list (M2 FE-1–3)', (tester) async {
    await pumpHome(tester);

    await tapAndWait(tester, find.text(l10n.patientsNewButton));
    expect(find.byType(RegisterScreen), findsOneWidget);
    expect(find.text(l10n.stepOf(1, 4, l10n.regWomanSection)), findsOneWidget);
    await enter(tester, l10n.regName, 'Synthetic Woman');
    await enter(tester, l10n.regAge, '36');
    await enter(tester, l10n.regHusbandName, 'Synthetic Husband');
    await enter(tester, l10n.regContactNumber, '0300 123-4567');
    await next(tester);

    expect(find.text(l10n.stepOf(2, 4, l10n.regPregnancySection)), findsOneWidget);
    await chooseMonth(tester, 6);
    final edd = services.clinicalRules!.gestationalAge.eddFromMonth(6, today());
    expect(find.text(eddNotice(edd)), findsOneWidget);
    await next(tester);

    expect(find.text(l10n.stepOf(3, 4, l10n.regHomeSection)), findsOneWidget);
    await enter(tester, l10n.regVillage, 'Dhok Syedan');
    await enter(tester, l10n.regAddress, 'House 12');
    await tapAndWait(tester, find.text(l10n.gpsCaptureButton));
    expect(find.text(l10n.gpsCaptured(8)), findsOneWidget);
    expect(find.text('33.684412, 73.047912'), findsOneWidget);
    // Back and forward keeps every answer, the GPS position too.
    await tapAndWait(tester, find.text(l10n.stepBack));
    expect(find.text(eddNotice(edd)), findsOneWidget);
    await next(tester);
    expect(find.text('33.684412, 73.047912'), findsOneWidget);
    await next(tester);

    expect(find.text(l10n.stepOf(4, 4, l10n.regHistorySection)), findsOneWidget);
    await setCounter(tester, l10n.regPreviousPregnancies, 2);
    await setCounter(tester, l10n.regPreviousCSections, 1);
    await enter(tester, l10n.regKnownConditions, 'Asthma');
    await tapAndWait(tester, find.text(l10n.regSaveButton));

    expect(find.byType(RegistrationSavedScreen), findsOneWidget);
    expect(find.text('LHW-DEMO-001-03-0001'), findsOneWidget, reason: '[LHW code]-[activation number]-[sequence] (M2 FE-1)');
    expect(find.text(l10n.savedOnPhone), findsOneWidget);
    expect(await tester.runAsync(services.db.pendingCount), 4);

    await tapAndWait(tester, find.text(l10n.savedOpenFile));
    expect(find.byType(PatientFileScreen), findsOneWidget);
    expect(find.text('Synthetic Woman'), findsOneWidget);
    expect(find.text('03001234567'), findsOneWidget, reason: 'spaces and dashes are removed');
    expect(find.text('33.684412, 73.047912'), findsOneWidget);
    expect(find.text('Asthma'), findsOneWidget);
    expect(find.text(l10n.syncWaiting), findsOneWidget);
    // M2 FE-2: the flags the Clinical Rules Table finds in her history.
    expect(find.text(l10n.flagPreviousCSection), findsOneWidget);
    expect(find.text(l10n.flagKnownMedicalCondition), findsOneWidget);
    expect(find.text(l10n.flagAdvancedMaternalAge), findsOneWidget);
    expect(find.text(l10n.flagPreviousStillbirth), findsNothing);
    expect(find.text(l10n.fileRiskFactorsPending(clinicalRules.version)), findsOneWidget);

    tester.state<NavigatorState>(find.byType(Navigator).first).pop(); // the phone's back gesture
    await settle(tester);
    await tapAndWait(tester, find.text(l10n.homePatientsButton));
    expect(find.byType(PatientListScreen), findsOneWidget);
    expect(find.text('Dhok Syedan'), findsOneWidget, reason: 'the village heading');
    expect(find.text('LHW-DEMO-001-03-0001'), findsOneWidget);
  });

  testWidgets('each step explains what to fix and does not move on; nothing is saved', (tester) async {
    await pumpHome(tester);
    await tapAndWait(tester, find.text(l10n.patientsNewButton));

    await next(tester);
    expect(find.text(l10n.regErrorRequired), findsOneWidget, reason: 'the name');
    expect(find.text(l10n.regErrorAge), findsOneWidget);
    await enter(tester, l10n.regName, 'Synthetic Woman');
    await enter(tester, l10n.regAge, '26');
    await enter(tester, l10n.regContactNumber, '12345');
    await next(tester);
    expect(find.text(l10n.regErrorContact), findsOneWidget);
    await enter(tester, l10n.regContactNumber, '');
    await next(tester);

    await next(tester);
    expect(find.text(l10n.regErrorChooseMonth), findsOneWidget);
    await chooseMonth(tester, 3);
    await next(tester);

    await next(tester);
    expect(find.text(l10n.regErrorRequired), findsOneWidget, reason: 'the village');
    await enter(tester, l10n.regVillage, 'Dhok Syedan');
    await next(tester);

    await setCounter(tester, l10n.regPreviousPregnancies, 1);
    await setCounter(tester, l10n.regPreviousCSections, 2);
    await setCounter(tester, l10n.regStillbirths, 3);
    expect(find.text(l10n.regErrorMoreThanPregnancies), findsNWidgets(2));
    await tapAndWait(tester, find.text(l10n.regSaveButton));

    expect(find.byType(RegisterScreen), findsOneWidget);
    expect(await tester.runAsync(services.db.pendingCount), 0);
  });

  testWidgets('saves without GPS when the location is off, and records it later from the file (M2 FE-3)', (tester) async {
    gps.result = const LocationResult.failed(LocationProblem.serviceOff);
    await pumpHome(tester);
    await tapAndWait(tester, find.text(l10n.patientsNewButton));
    await enter(tester, l10n.regName, 'Synthetic Woman');
    await enter(tester, l10n.regAge, '26');
    await next(tester);
    await chooseMonth(tester, 3);
    await next(tester);
    await enter(tester, l10n.regVillage, 'Dhok Syedan');

    await tapAndWait(tester, find.text(l10n.gpsCaptureButton));
    expect(find.text(l10n.gpsServiceOff), findsOneWidget);
    await tapAndWait(tester, find.text(l10n.gpsOpenSettings));
    expect(gps.openedSettings, [LocationProblem.serviceOff]);

    await next(tester);
    await tapAndWait(tester, find.text(l10n.regSaveButton));
    await tapAndWait(tester, find.text(l10n.savedOpenFile));
    expect(find.text(l10n.gpsNotRecorded), findsOneWidget);
    expect(find.text(l10n.fileNoRiskFactors), findsOneWidget);

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
    await tapAndWait(tester, find.text(l10n.patientsNewButton));
    await enter(tester, l10n.regName, 'Second Woman');
    await enter(tester, l10n.regAge, '24');
    await next(tester);
    await chooseMonth(tester, 2);
    await next(tester);

    await tapAndWait(tester, find.text(l10n.regSameHome));
    expect(field(l10n.regVillage), findsNothing, reason: 'the home is already recorded');
    final whose = find.byWidgetPredicate((w) => w is DropdownField<String>);
    await tester.tap(whose);
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.regWomanOption('First Woman', 'LHW-DEMO-001-03-0001')).last);
    await tester.pumpAndSettle();
    await next(tester);
    await tapAndWait(tester, find.text(l10n.regSaveButton));

    expect(find.text('LHW-DEMO-001-03-0002'), findsOneWidget);
    final women = (await tester.runAsync(services.patients.list))!;
    expect(women.map((p) => p.woman.householdId).toSet(), {first.householdId});
  });

  testWidgets('the pregnancy date from the last period gives the delivery date and weeks, and is kept (M2 FE-1)', (tester) async {
    await pumpHome(tester);
    await tapAndWait(tester, find.text(l10n.patientsNewButton));
    await enter(tester, l10n.regName, 'Dated Woman');
    await enter(tester, l10n.regAge, '27');
    await next(tester);

    await tapAndWait(tester, find.text(l10n.regBasisLmp));
    expect(find.text(l10n.regLmpHint), findsOneWidget);
    await next(tester);
    expect(find.text(l10n.regErrorChooseDate), findsWidgets, reason: 'the date is needed');
    expect(find.text(l10n.stepOf(2, 4, l10n.regPregnancySection)), findsOneWidget);

    // The picker opens on the latest possible LMP; choose the 1st of the month shown.
    await tapAndWait(tester, find.text(l10n.regPickDate));
    final initial = tester.widget<CalendarDatePicker>(find.byType(CalendarDatePicker)).initialDate!;
    await tester.tap(find.text('1').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(MaterialLocalizations.of(tester.element(find.byType(CalendarDatePicker))).okButtonLabel));
    await settle(tester); // the picker was opened outside the test clock
    final lmp = DateTime(initial.year, initial.month, 1);
    final edd = services.clinicalRules!.gestationalAge.eddFromLmp(lmp);
    expect(find.text(eddNotice(edd)), findsOneWidget);
    await next(tester);
    await enter(tester, l10n.regVillage, 'Dhok Syedan');
    await next(tester);
    await tapAndWait(tester, find.text(l10n.regSaveButton));

    final [woman] = (await tester.runAsync(services.patients.list))!;
    expect(woman.pregnancy!.eddBasis, 'lmp');
    expect(woman.pregnancy!.lmpDate, PatientRepository.calendarDate(lmp));
    expect(woman.pregnancy!.estimatedDeliveryDate, PatientRepository.calendarDate(edd));
    expect(
      woman.pregnancy!.pregnancyMonthAtRegistration,
      services.clinicalRules!.gestationalAge.monthOn(edd, today()),
      reason: 'the month follows from the date',
    );
  });

  testWidgets('a woman already on the phone is pointed out before a second registration (M2 FE-1)', (tester) async {
    await pumpHome(tester);
    await tester.runAsync(() => services.patients.register(
          const RegistrationInput(name: 'Amina Bibi', age: 30, husbandName: 'Imran', pregnancyMonth: 5, village: 'Chak Beli'),
          by: services.session.user!,
        ));
    await tapAndWait(tester, find.text(l10n.patientsNewButton));
    await enter(tester, l10n.regName, '  amina   BIBI ');
    await enter(tester, l10n.regAge, '30');
    await enter(tester, l10n.regHusbandName, 'imran');
    await next(tester);

    expect(find.text(l10n.regDuplicateTitle), findsOneWidget);
    await tapAndWait(tester, find.text(l10n.regDuplicateContinue));
    expect(find.text(l10n.stepOf(2, 4, l10n.regPregnancySection)), findsOneWidget, reason: 'she may be someone else');

    await tapAndWait(tester, find.text(l10n.stepBack));
    await next(tester);
    await tapAndWait(tester, find.text(l10n.regDuplicateOpen));
    expect(find.byType(PatientFileScreen), findsOneWidget);
    expect(find.text('Amina Bibi'), findsOneWidget);
  });

  Future<void> registerThree(WidgetTester tester) => tester.runAsync(() async {
        for (final (name, village, lat) in [('Amina', 'Dhok Syedan', 33.70), ('Bushra', 'Chak Beli', 33.61), ('Kiran', 'Chak Beli', null)]) {
          await services.patients.register(
            RegistrationInput(name: name, age: 25, pregnancyMonth: 4, village: village, latitude: lat, longitude: lat == null ? null : 73.0),
            by: services.session.user!,
          );
        }
      });

  testWidgets('the list finds women by name, ID or village and says when nothing matches', (tester) async {
    await pumpHome(tester);
    await registerThree(tester);
    await tapAndWait(tester, find.text(l10n.homePatientsButton));
    expect(find.text('${l10n.patientsCount(3)} · ${l10n.patientsVillages(2)}'), findsOneWidget);

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

  testWidgets('the list sorts women by distance from the LHW, nearest first (M2 FE-3)', (tester) async {
    gps.result = const LocationResult.found(LocationFix(latitude: 33.60, longitude: 73.0, accuracyMetres: 10));
    await pumpHome(tester);
    await registerThree(tester);
    await tapAndWait(tester, find.text(l10n.homePatientsButton));

    await tapAndWait(tester, find.text(l10n.patientsSortNearest));

    double top(String name) => tester.getTopLeft(find.text(name)).dy;
    expect(top('Bushra'), lessThan(top('Amina')));
    expect(top('Amina'), lessThan(top('Kiran')), reason: 'no home location: last');
    expect(find.text('Chak Beli · ${l10n.patientsDistance('1.1')}'), findsOneWidget);
    expect(find.text('Chak Beli · ${l10n.patientsNoGps}'), findsOneWidget);

    gps.result = const LocationResult.failed(LocationProblem.unavailable);
    await tapAndWait(tester, find.text(l10n.patientsSortVillage));
    await tapAndWait(tester, find.text(l10n.patientsSortNearest));
    expect(find.text(l10n.gpsUnavailable), findsOneWidget);
    expect(top('Bushra'), lessThan(top('Amina')), reason: 'back to villages: Chak Beli first');
  });

  testWidgets('an account without an LHW code sees no registration buttons', (tester) async {
    server.lhwCode = null;
    await pumpHome(tester);

    expect(find.text(l10n.patientsNewButton), findsNothing);
    expect(find.text(l10n.homePatientsButton), findsNothing);
  });
}
