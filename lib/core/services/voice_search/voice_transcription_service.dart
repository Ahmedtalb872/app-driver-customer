import 'dart:convert';

import '../../config/supabase_config.dart';

/// Sends a recorded voice-search clip to the `voice-transcribe` Supabase
/// Edge Function (Google Cloud Speech-to-Text, server-side) and returns the
/// transcript - the higher-accuracy counterpart to the free on-device
/// `speech_to_text` recognizer [VoiceRoutePipeline]'s Stage 2/3 corrections
/// were built to work around. Never throws: a failure (no network, API
/// error, empty result) is an empty string, same never-block-the-caller
/// convention as [GooglePlacesSearchService].
class VoiceTranscriptionService {
  const VoiceTranscriptionService();

  /// [audioBytes] must be a WAV (PCM) recording - see
  /// [VoiceRideRequestSheet]'s recorder config. The Edge Function reads the
  /// sample rate straight from the WAV header, so no format details need
  /// to be passed alongside it here.
  Future<String> transcribe(List<int> audioBytes) async {
    if (audioBytes.isEmpty) return '';
    try {
      final response = await SupabaseConfig.client.functions.invoke(
        'voice-transcribe',
        body: {'audio': base64Encode(audioBytes)},
      );
      final data = response.data;
      if (data is! Map) return '';
      return (data['transcript'] as String?) ?? '';
    } catch (_) {
      return '';
    }
  }
}
