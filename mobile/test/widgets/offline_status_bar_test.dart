import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediqore/widgets/offline_status_bar.dart';

import '../helpers.dart';

void main() {
  testWidgets('offline: says data will be sent later', (tester) async {
    await tester.pumpWidget(wrapInApp(const OfflineStatusBar(isOnline: false, pendingCount: 4)));
    await tester.pumpAndSettle();

    expect(find.text('آف لائن: انٹرنیٹ ملنے پر ڈیٹا بھیج دیا جائے گا'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_off), findsOneWidget);
  });

  testWidgets('online with records waiting: shows the count', (tester) async {
    await tester.pumpWidget(wrapInApp(const OfflineStatusBar(isOnline: true, pendingCount: 3)));
    await tester.pumpAndSettle();

    expect(find.text('آن لائن: 3 ریکارڈ بھیجے جانے باقی ہیں'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_upload), findsOneWidget);
  });

  testWidgets('online with one record waiting: uses the singular', (tester) async {
    await tester.pumpWidget(wrapInApp(const OfflineStatusBar(isOnline: true, pendingCount: 1)));
    await tester.pumpAndSettle();

    expect(find.text('آن لائن: 1 ریکارڈ بھیجا جانا باقی ہے'), findsOneWidget);
  });

  testWidgets('online and synced', (tester) async {
    await tester.pumpWidget(wrapInApp(const OfflineStatusBar(isOnline: true)));
    await tester.pumpAndSettle();

    expect(find.text('آن لائن: تمام ڈیٹا بھیج دیا گیا ہے'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_done), findsOneWidget);
  });
}
