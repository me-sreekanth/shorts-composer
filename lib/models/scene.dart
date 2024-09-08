class Scene {
  final int sceneNumber;
  final int duration;
  final String text;
  String description;
  String? imageUrl;
  bool isLocalImage;
  String? voiceoverUrl;
  bool isLocalVoiceover;
  String? videoPath; // Add this field

  Scene({
    required this.sceneNumber,
    required this.duration,
    required this.text,
    required this.description,
    this.imageUrl,
    this.isLocalImage = false,
    this.voiceoverUrl,
    this.isLocalVoiceover = false,
    this.videoPath, // Initialize this field
  });

  factory Scene.fromJson(Map<String, dynamic> json) {
    return Scene(
      sceneNumber: json['SceneNumber'] is int
          ? json['SceneNumber']
          : int.tryParse(json['SceneNumber']) ?? 0,
      duration: json['Duration'] is int
          ? json['Duration']
          : int.tryParse(json['Duration']) ?? 0,
      text: json['Text'] ?? '',
      description: json['Description'] ?? '',
      imageUrl: json['ImageUrl'],
      isLocalImage: json['IsLocalImage'] ?? false,
      voiceoverUrl: json['VoiceoverUrl'],
      isLocalVoiceover: json['IsLocalVoiceover'] ?? false,
      videoPath: json['VideoPath'], // Add this line
    );
  }

  void updateDescription(String newDescription) {
    description = newDescription;
  }

  void updateImageUrl(String newImageUrl, {bool isLocal = false}) {
    imageUrl = newImageUrl;
    isLocalImage = isLocal;
  }

  void updateVoiceoverUrl(String newVoiceoverUrl, {bool isLocal = false}) {
    voiceoverUrl = newVoiceoverUrl;
    isLocalVoiceover = isLocal;
  }

  void updateVideoPath(String newVideoPath) {
    videoPath = newVideoPath;
  }
}
