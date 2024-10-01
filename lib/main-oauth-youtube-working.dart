import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:googleapis/youtube/v3.dart' as youtube;
import 'package:googleapis_auth/googleapis_auth.dart';

/// Define the required scopes for YouTube upload
const List<String> scopes = <String>[
  'email',
  'https://www.googleapis.com/auth/youtube.upload',
];

GoogleSignIn _googleSignIn = GoogleSignIn(
  scopes: scopes,
  // serverClientId:
  //     'YOUR-WEB-CLIENT-ID.apps.googleusercontent.com', // Replace with your Web Client ID
);

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  GoogleSignInAccount? _currentUser;
  File? _selectedVideoFile;
  bool _isAuthorized = false;

  @override
  void initState() {
    super.initState();
    _googleSignIn.onCurrentUserChanged
        .listen((GoogleSignInAccount? account) async {
      bool isAuthorized = account != null;
      setState(() {
        _currentUser = account;
        _isAuthorized = isAuthorized;
      });
    });

    _googleSignIn.signInSilently();
  }

  Future<void> _handleSignIn() async {
    try {
      await _googleSignIn.signIn();
      setState(() {});
    } catch (error) {
      print('Error signing in: $error');
    }
  }

  Future<void> _handleSignOut() async {
    await _googleSignIn.disconnect();
    setState(() {
      _currentUser = null;
      _isAuthorized = false;
    });
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
    if (_selectedVideoFile != null) {
      final authHeaders = await _googleSignIn.currentUser!.authHeaders;
      final client = AuthenticatedClient(http.Client(), authHeaders);
      youtube.YouTubeApi youtubeApi = youtube.YouTubeApi(client);

      var video = youtube.Video();
      video.snippet = youtube.VideoSnippet()
        ..title = "Test Video"
        ..description = "Uploaded from Flutter";
      video.status = youtube.VideoStatus()..privacyStatus = "public";

      var media = youtube.Media(
          _selectedVideoFile!.openRead(), _selectedVideoFile!.lengthSync());

      try {
        var response = await youtubeApi.videos
            .insert(video, ["snippet", "status"], uploadMedia: media);
        print("Video uploaded with ID: ${response.id}");
      } catch (e) {
        print('Error uploading video: $e');
      }
    } else {
      print("No video file selected");
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text('Google Sign-In and YouTube Upload'),
        ),
        body: Center(
          child: _currentUser == null
              ? ElevatedButton(
                  onPressed: _handleSignIn,
                  child: Text('Sign In'),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_currentUser != null)
                      ListTile(
                        leading:
                            GoogleUserCircleAvatar(identity: _currentUser!),
                        title: Text(_currentUser?.displayName ?? ''),
                        subtitle: Text(_currentUser?.email ?? ''),
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
                    ElevatedButton(
                      onPressed: _handleSignOut,
                      child: Text('Sign Out'),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class AuthenticatedClient extends http.BaseClient {
  final http.Client _inner;
  final Map<String, String> _headers;

  AuthenticatedClient(this._inner, this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _inner.send(request..headers.addAll(_headers));
  }
}
