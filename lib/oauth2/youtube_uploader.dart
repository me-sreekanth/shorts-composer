import 'dart:convert';
import 'dart:io';
import 'package:googleapis_auth/auth_io.dart';
import 'package:googleapis/youtube/v3.dart' as youtube;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'custom_media_stream.dart';

class YouTubeUploader {
  final GoogleSignIn _googleSignIn;

  YouTubeUploader({required String clientId})
      : _googleSignIn = GoogleSignIn(
          clientId: clientId,
          scopes: [
            youtube.YouTubeApi.youtubeUploadScope,
          ],
        );

  Future<AuthClient?> authenticate() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        throw Exception("Sign in aborted or failed.");
      }

      final authHeaders = await account.authHeaders;
      if (authHeaders == null) {
        throw Exception("Failed to obtain auth headers.");
      }

      print("Auth Headers: $authHeaders");

      final accessToken = AccessToken(
        'Bearer',
        authHeaders['Authorization']!.split(' ').last,
        DateTime.now()
            .add(Duration(seconds: 3600))
            .toUtc(), // Ensure the expiry date is in UTC
      );

      final credentials = AccessCredentials(
        accessToken,
        "", // No refresh token
        [],
      );

      return authenticatedClient(
        http.Client(),
        credentials,
      );
    } catch (e) {
      print("Error during authentication: $e");
      return null;
    }
  }

  Future<String> uploadVideo(AuthClient client, String filePath, String title,
      String description, Function(double) onUploadProgress) async {
    final youtubeApi = youtube.YouTubeApi(client);
    final mediaFile = File(filePath);
    final mediaLength = mediaFile.lengthSync();

    final mediaStream =
        CustomMediaStream(mediaFile.openRead(), mediaLength, onUploadProgress);
    final media = youtube.Media(mediaStream, mediaLength);

    final video = youtube.Video()
      ..snippet = (youtube.VideoSnippet()
        ..title = title
        ..description = description
        ..tags = ["shorts"]
        ..categoryId = "22")
      ..status = (youtube.VideoStatus()..privacyStatus = "public");

    final response = await youtubeApi.videos.insert(
      video,
      ['snippet', 'status'],
      uploadMedia: media,
    );

    return response.id!;
  }
}
