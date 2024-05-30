class Scene {
  final int sceneNumber;
  final int duration;
  final String voiceOverText;
  final String text;
  String description;
  String? imageUrl;

  Scene({
    required this.sceneNumber,
    required this.duration,
    required this.voiceOverText,
    required this.text,
    required this.description,
    this.imageUrl,
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

  void updateImageUrl(String newImageUrl) {
    imageUrl = newImageUrl;
  }
}
