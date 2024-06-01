class Scene {
  final int sceneNumber;
  final int duration;
  String voiceOverText; // Remove 'final'
  final String text;
  String description;
  String? imageUrl;
  bool isLocalImage;

  Scene({
    required this.sceneNumber,
    required this.duration,
    required this.voiceOverText,
    required this.text,
    required this.description,
    this.imageUrl,
    this.isLocalImage = false,
  });

  factory Scene.fromJson(Map<String, dynamic> json) {
    return Scene(
      sceneNumber: json['SceneNumber'],
      duration: int.parse(json['Duration']),
      voiceOverText: json['VoiceOverText'],
      text: json['Text'],
      description: json['Description'],
    );
  }

  void updateDescription(String newDescription) {
    description = newDescription;
  }

  void updateImageUrl(String newImageUrl, {bool isLocal = false}) {
    imageUrl = newImageUrl;
    isLocalImage = isLocal;
  }

  void updateVoiceOverText(String newVoiceOverText) {
    voiceOverText = newVoiceOverText;
  }
}
