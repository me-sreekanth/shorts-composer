import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:googleapis/youtube/v3.dart' as youtube;
import 'package:googleapis_auth/googleapis_auth.dart';
import 'package:url_launcher/url_launcher.dart';

class UploadScreen extends StatefulWidget {
  final String generatedVideoPath;
  final GoogleSignInAccount? currentUser; // Receive the authenticated user
  final bool isAuthenticated;
  final Function onSignIn; // Handle sign-in method
  final Function onSignOut; // Handle sign-out method

  UploadScreen({
    required this.generatedVideoPath,
    required this.currentUser,
    required this.isAuthenticated,
    required this.onSignIn,
    required this.onSignOut,
  });

  @override
  _UploadScreenState createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  File? _selectedVideoFile;
  String? _videoUrl;

  @override
  void initState() {
    super.initState();
    _selectedVideoFile = File(widget.generatedVideoPath);
  }

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickVideo(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedVideoFile = File(pickedFile.path);
      });
    } else {
      print("No video selected");
    }
  }

  Future<void> _uploadVideoToYouTube() async {
    if (_selectedVideoFile != null && widget.currentUser != null) {
      final authHeaders = await widget.currentUser!.authHeaders;
      final client = AuthenticatedClient(http.Client(), authHeaders);
      youtube.YouTubeApi youtubeApi = youtube.YouTubeApi(client);

      var video = youtube.Video();
      video.snippet = youtube.VideoSnippet()
        ..title = "Generated Video"
        ..description = "Uploaded from Flutter";
      video.status = youtube.VideoStatus()..privacyStatus = "public";

      var media = youtube.Media(
        _selectedVideoFile!.openRead(),
        _selectedVideoFile!.lengthSync(),
      );

      try {
        var response = await youtubeApi.videos
            .insert(video, ["snippet", "status"], uploadMedia: media);
        setState(() {
          _videoUrl = 'https://www.youtube.com/watch?v=${response.id}';
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Upload successful: $_videoUrl'),
        ));
      } catch (e) {
        print('Error uploading video: $e');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Upload failed: $e'),
        ));
      }
    } else {
      print("No video file selected or not authenticated");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('No video available to upload or not authenticated.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Upload Generated Video'),
        actions: [
          if (widget.isAuthenticated)
            IconButton(
              icon: Icon(Icons.logout),
              onPressed: () {
                widget.onSignOut();
              },
            )
        ],
      ),
      body: Center(
        child: widget.isAuthenticated
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.currentUser != null)
                    ListTile(
                      leading:
                          GoogleUserCircleAvatar(identity: widget.currentUser!),
                      title: Text(widget.currentUser?.displayName ?? ''),
                      subtitle: Text(widget.currentUser?.email ?? ''),
                    ),
                  ElevatedButton(
                    onPressed: _pickVideo,
                    child: Text('Pick a Video'),
                  ),
                  if (_selectedVideoFile != null) ...[
                    Text('Selected video: ${_selectedVideoFile!.path}'),
                    ElevatedButton(
                      onPressed: _uploadVideoToYouTube,
                      child: Text('Upload Video'),
                    ),
                  ],
                  if (_videoUrl != null)
                    ElevatedButton(
                      onPressed: () {
                        launch(_videoUrl!);
                      },
                      child: Text('Open Video in YouTube'),
                    ),
                ],
              )
            : ElevatedButton(
                onPressed: () {
                  widget.onSignIn();
                },
                child: Text('Sign In with Google'),
              ),
      ),
    );
  }
}

// AuthenticatedClient class to handle authenticated API requests
class AuthenticatedClient extends http.BaseClient {
  final http.Client _inner;
  final Map<String, String> _headers;

  AuthenticatedClient(this._inner, this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _inner.send(request..headers.addAll(_headers));
  }
}
