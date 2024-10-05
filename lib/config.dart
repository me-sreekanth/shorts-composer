// config.dart

class Config {
  //IMAGE generation configs
  static const String imageGenerationToken =
      'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VybmFtZSI6IjM3ZDFlNWEyYjI0NGJhZjc1NWFmYjg4OGQ4N2NmMzI2IiwiY3JlYXRlZF9hdCI6IjIwMjMtMTEtMThUMTA6NTU6MzguMjc5MjI2In0.kOrXHhfVOgqRNeuQxRM6e8-HRuodtwCzQ4jtHiNpDfs';
  static const String imageGenerationApiUrl =
      'https://monsterapi.ai/backend/v2playground';

//VOICEOVERS configs
  static const String voiceoverGenerationToken =
      'sk_f0dccc6bca2c9549cefb5fd1c3972e452925046fbdca8d34';
  static const String voiceoverGenerationApiUrl =
      'https://api.elevenlabs.io/v1/text-to-speech';
  static const String voiceoverVoiceId =
      'TX3LPaxmHKxFdv7VOQHJ'; // Voice id of Liam

//TRANSCRIBE VOICEOVERS configs
  static const String transcribeVoiceoversToken =
      'f925ef20cec038e58baad218728318273ed8631b';
}
