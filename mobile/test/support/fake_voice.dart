import 'package:mediqore/voice/voice_guide.dart';

/// Stands in for the phone's text-to-speech: records what would be spoken.
class FakeVoice implements Voice {
  FakeVoice({this.hasUrdu = true});

  bool hasUrdu;
  final List<String> spoken = [];
  int stops = 0;

  @override
  Future<void> speak(String text) async => spoken.add(text);

  @override
  Future<void> stop() async => stops++;

  @override
  Future<bool?> canSpeakUrdu() async => hasUrdu;
}
