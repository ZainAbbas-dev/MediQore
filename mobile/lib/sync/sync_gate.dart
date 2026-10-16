// M3 FE-2: keeps the open app and background sync (background_sync.dart) from
// syncing at the same time. Both use the same refresh token, which the server
// replaces at every use, so two syncs at once could leave the phone with a token
// the server no longer accepts.
// - While the app is unlocked it marks itself open and renews the mark every
//   minute; background sync then leaves the work to the app.
// - Background sync marks itself running; the app waits for it to finish
//   before its own sync.
// A mark older than [SyncGate.staleAfter] is ignored, so a crash never blocks
// sync for long. The marks use the phone's clock only to expire, never to order
// records (LI-7).
import 'dart:io';

import 'package:path_provider/path_provider.dart';

abstract class SyncGate {
  /// A mark older than this is ignored.
  static const Duration staleAfter = Duration(minutes: 3);

  /// How often the open app renews its mark.
  static const Duration renewEvery = Duration(minutes: 1);

  /// The app is unlocked: called at unlock and then every [renewEvery].
  Future<void> markAppOpen();

  /// The app locked.
  Future<void> clearAppOpen();

  /// Whether the app is unlocked, as background sync sees it.
  Future<bool> appIsOpen();

  /// Marks background sync as running; false if it is already running.
  Future<bool> startBackground();

  /// Background sync finished.
  Future<void> endBackground();

  /// Whether background sync is running.
  Future<bool> backgroundRunning();

  /// Waits until background sync has finished, at most [timeout].
  Future<void> waitForBackground({
    Duration timeout = const Duration(seconds: 60),
    Duration poll = const Duration(milliseconds: 500),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (await backgroundRunning() && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(poll);
    }
  }
}

/// The marks as two small files in the app's private support folder, which every
/// isolate of the app can see (the app's and the one Android starts for
/// background work).
class FileSyncGate extends SyncGate {
  FileSyncGate({Future<Directory> Function()? directory, DateTime Function()? clock})
    : _directory = directory ?? getApplicationSupportDirectory,
      _clock = clock ?? DateTime.now;

  final Future<Directory> Function() _directory;
  final DateTime Function() _clock;

  Future<File> _file(String name) async => File('${(await _directory()).path}/$name');

  Future<void> _mark(String name) async =>
      (await _file(name)).writeAsString('${_clock().millisecondsSinceEpoch}', flush: true);

  Future<void> _clear(String name) async {
    final file = await _file(name);
    if (await file.exists()) await file.delete();
  }

  Future<bool> _fresh(String name) async {
    final file = await _file(name);
    if (!await file.exists()) return false;
    final at = int.tryParse((await file.readAsString()).trim());
    if (at == null) return false;
    final age = _clock().millisecondsSinceEpoch - at;
    // A clock set back makes the mark look new; it still expires.
    return age.abs() < SyncGate.staleAfter.inMilliseconds;
  }

  static const String _appFile = 'sync-app-open';
  static const String _backgroundFile = 'sync-background';

  @override
  Future<void> markAppOpen() => _mark(_appFile);

  @override
  Future<void> clearAppOpen() => _clear(_appFile);

  @override
  Future<bool> appIsOpen() => _fresh(_appFile);

  @override
  Future<bool> startBackground() async {
    if (await _fresh(_backgroundFile)) return false;
    await _mark(_backgroundFile);
    return true;
  }

  @override
  Future<void> endBackground() => _clear(_backgroundFile);

  @override
  Future<bool> backgroundRunning() => _fresh(_backgroundFile);
}

/// The marks in memory, for tests: the app and background sync share one gate.
class MemorySyncGate extends SyncGate {
  bool appOpen = false;
  bool background = false;

  @override
  Future<void> markAppOpen() async => appOpen = true;

  @override
  Future<void> clearAppOpen() async => appOpen = false;

  @override
  Future<bool> appIsOpen() async => appOpen;

  @override
  Future<bool> startBackground() async {
    if (background) return false;
    return background = true;
  }

  @override
  Future<void> endBackground() async => background = false;

  @override
  Future<bool> backgroundRunning() async => background;
}
