import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:googleapis/youtube/v3.dart' as youtube;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'custom_media_stream.dart';

class YouTubeUploader {
  final GoogleSignIn googleSignIn; // Made public to allow external access

  YouTubeUploader({required String clientId})
      : googleSignIn = GoogleSignIn(
          serverClientId: clientId,
          clientId: clientId,
          scopes: [
            youtube.YouTubeApi.youtubeUploadScope,
            'email',
          ],
        );

  Future<AuthClient?> authenticate() async {
    try {
      print("Starting Google Sign-In process...");

      // Attempt to sign in
      final account = await googleSignIn.signIn();
      if (account == null) {
        throw Exception("Sign in aborted or failed.");
      }

      print("Google Sign-In successful. Account: ${account.email}");

      // Obtain auth headers
      final authHeaders = await account.authHeaders;
      if (authHeaders == null) {
        throw Exception("Failed to obtain auth headers.");
      }

      print("Auth Headers received: $authHeaders");

      // Extract access token and prepare credentials
      final accessToken = AccessToken(
        'Bearer',
        authHeaders['Authorization']!.split(' ').last,
        DateTime.now().add(Duration(seconds: 3600)).toUtc(),
      );

      print("Access Token generated: ${accessToken.data}");

      // Create credentials
      final credentials = AccessCredentials(
        accessToken,
        "", // No refresh token
        [],
      );

      print("Returning authenticated client with credentials.");

      return authenticatedClient(
        http.Client(),
        credentials,
      );
    } on PlatformException catch (e) {
      print("PlatformException during authentication: ${e.message}");
      return null;
    } catch (e) {
      print("General error during authentication: $e");
      return null;
    }
  }

  Future<String> uploadVideo(AuthClient client, String filePath, String title,
      String description, Function(double) onUploadProgress) async {
    try {
      print("Preparing to upload video. File path: $filePath");

      final youtubeApi = youtube.YouTubeApi(client);
      final mediaFile = File(filePath);
      final mediaLength = mediaFile.lengthSync();

      print("File length: $mediaLength bytes.");

      final mediaStream = CustomMediaStream(
          mediaFile.openRead(), mediaLength, onUploadProgress);
      final media = youtube.Media(mediaStream, mediaLength);

      final video = youtube.Video()
        ..snippet = (youtube.VideoSnippet()
          ..title = title
          ..description = description
          ..tags = ["shorts"]
          ..categoryId = "22")
        ..status = (youtube.VideoStatus()..privacyStatus = "public");

      print("Uploading video with title: $title");

      final response = await youtubeApi.videos.insert(
        video,
        ['snippet', 'status'],
        uploadMedia: media,
      );

      print("Video upload successful. Video ID: ${response.id}");

      return response.id!;
    } catch (e) {
      print("Error during video upload: $e");
      throw e;
    }
  }
}
