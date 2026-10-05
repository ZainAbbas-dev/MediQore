// M1 FE-2: build-time switches.

/// A test build for phones, made by `.github/workflows/apk.yml`:
///   flutter build apk --dart-define=MEDIQORE_TEST_BUILD=true
///
/// In a test build the server address can be changed on the sign-in screen, so
/// testers can point the app at a laptop on the same Wi-Fi, and the Phase 0
/// checks are on the home screen. The workflow also allows plain HTTP for it.
/// Builds for LHWs never set it: they use one HTTPS address fixed at build time.
const bool testBuild = bool.fromEnvironment('MEDIQORE_TEST_BUILD');
