import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/youtube/v3.dart' as youtube;
import 'package:googleapis_auth/googleapis_auth.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:video_player/video_player.dart';
import 'package:path/path.dart' as path;
import 'package:image_picker/image_picker.dart'; // Add for video picking
import 'package:url_launcher/url_launcher.dart';

class UploadScreen extends StatefulWidget {
  final String generatedVideoPath;
  final GoogleSignInAccount? currentUser;
  final bool isAuthenticated;
  final Function onSignIn;
  final Function onSignOut;

  final TextEditingController titleController;
  final TextEditingController descriptionController;

  UploadScreen({
    required this.generatedVideoPath,
    required this.currentUser,
    required this.isAuthenticated,
    required this.onSignIn,
    required this.onSignOut,
    required this.titleController,
    required this.descriptionController,
  });

  @override
  _UploadScreenState createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  File? _selectedVideoFile;
  String? _videoUrl;
  VideoPlayerController? _videoController;
  bool _isUploading = false;
  bool _isFetching = true;

  String? _channelName;
  String? _channelEmail;
  String? _channelLogoUrl;

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    if (widget.generatedVideoPath.isNotEmpty) {
      _selectedVideoFile = File(widget.generatedVideoPath);
      _initializeVideoPlayer();
    }
    _fetchYouTubeChannelDetails();
  }

  Future<void> _fetchYouTubeChannelDetails() async {
    if (widget.currentUser != null) {
      try {
        final authHeaders = await widget.currentUser!.authHeaders;
        final client = AuthenticatedClient(http.Client(), authHeaders);
        final youtubeApi = youtube.YouTubeApi(client);

        var channelsResponse = await youtubeApi.channels.list(
          ["snippet"],
          mine: true,
        );

        if (channelsResponse.items != null &&
            channelsResponse.items!.isNotEmpty) {
          var channel = channelsResponse.items!.first;
          setState(() {
            _channelName = channel.snippet?.title;
            _channelEmail = widget.currentUser?.email;
            _channelLogoUrl = channel.snippet?.thumbnails?.default_?.url;
            _isFetching = false;
          });
        }
      } catch (e) {
        print("Error fetching YouTube channel details: $e");
        setState(() => _isFetching = false);
      }
    }
  }

  Future<void> _initializeVideoPlayer() async {
    if (_selectedVideoFile != null) {
      _videoController = VideoPlayerController.file(_selectedVideoFile!)
        ..initialize().then((_) {
          setState(() {});
        });
    }
  }

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickVideo(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedVideoFile = File(pickedFile.path);
      });
      _initializeVideoPlayer();
    }
  }

  Future<void> _uploadVideoToYouTube() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedVideoFile != null && widget.currentUser != null) {
        setState(() {
          _isUploading = true;
        });
        final authHeaders = await widget.currentUser!.authHeaders;
        final client = AuthenticatedClient(http.Client(), authHeaders);
        youtube.YouTubeApi youtubeApi = youtube.YouTubeApi(client);

        var video = youtube.Video();
        video.snippet = youtube.VideoSnippet()
          ..title = widget.titleController.text
          ..description = widget.descriptionController.text;
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
            _isUploading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Upload successful: $_videoUrl'),
          ));
        } catch (e) {
          setState(() {
            _isUploading = false;
          });
          print('Error uploading video: $e');
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Upload failed: $e'),
          ));
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('No video available to upload or not authenticated.'),
        ));
      }
    }
  }

  Future<void> _launchYouTubeUrl(String url) async {
    final Uri _url = Uri.parse(url);
    if (!await launchUrl(_url, mode: LaunchMode.externalApplication)) {
      throw 'Could not launch $_url';
    }
  }

  Widget _buildVideoArea() {
    return Container(
      height: MediaQuery.of(context).size.height / 2, // Set minimum height
      color: Colors.grey[300], // Background color when no video is present
      child: _selectedVideoFile != null && _videoController != null
          ? Stack(
              children: [
                _videoController!.value.isInitialized
                    ? VideoPlayer(_videoController!)
                    : Center(child: CircularProgressIndicator()),
                Positioned.fill(
                  child: Center(
                    child: IconButton(
                      icon: Icon(
                        Icons.play_circle_fill,
                        color: Colors.white,
                        size: 64,
                      ),
                      onPressed: () => OpenFilex.open(_selectedVideoFile!.path),
                    ),
                  ),
                ),
                Positioned(
                  left: 10,
                  bottom: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 8.0, horizontal: 12.0),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'File: ${path.basename(_selectedVideoFile!.path)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            )
          : Center(
              child: ElevatedButton(
                onPressed: _pickVideo,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: Text('Pick a Video from Gallery'),
              ),
            ),
    );
  }

  Widget _buildTextInputFields() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextFormField(
            controller: widget.titleController,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a video title';
              }
              return null;
            },
            decoration: InputDecoration(
              labelText: 'Your video title',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextFormField(
            controller: widget.descriptionController,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a video description';
              }
              return null;
            },
            decoration: InputDecoration(
              labelText: 'Your video description',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            maxLines: 3,
          ),
        ),
        SizedBox(height: 50),
      ],
    );
  }

  Widget _buildLoggedInBottomSheet() {
    if (_isFetching) {
      return Center(child: CircularProgressIndicator());
    }
    return Container(
      width: MediaQuery.of(context).size.width,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: _channelLogoUrl != null
                ? CircleAvatar(backgroundImage: NetworkImage(_channelLogoUrl!))
                : Icon(Icons.account_circle, size: 40),
            title: Text(_channelName ?? 'Channel Name'),
            subtitle: Text(_channelEmail ?? 'Channel Email'),
            trailing: IconButton(
              icon: Icon(Icons.logout),
              onPressed: () => widget.onSignOut(),
            ),
          ),
          if (_isUploading)
            Center(child: CircularProgressIndicator())
          else
            ElevatedButton(
              onPressed: _uploadVideoToYouTube,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text('Upload to YouTube'),
            ),
          if (_videoUrl != null)
            ElevatedButton(
              onPressed: () => _launchYouTubeUrl(_videoUrl!),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text('Open Video in YouTube'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String appBarTitle = widget.generatedVideoPath.isNotEmpty
        ? 'Upload Generated Video'
        : (_selectedVideoFile != null
            ? 'Upload Picked Video'
            : 'Upload to YouTube');

    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle, style: TextStyle(fontSize: 20)),
      ),
      body: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildVideoArea(), // Consistent video area layout
              SizedBox(height: 20),
              if (_selectedVideoFile != null ||
                  widget.generatedVideoPath.isNotEmpty)
                _buildTextInputFields(),
              SizedBox(height: 100),
            ],
          ),
        ),
      ),
      bottomSheet: widget.isAuthenticated
          ? _buildLoggedInBottomSheet()
          : Center(child: Text("Please sign in to upload videos")),
    );
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
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
