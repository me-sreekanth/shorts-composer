import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:googleapis/youtube/v3.dart' as youtube;
import 'package:googleapis_auth/googleapis_auth.dart';
import 'package:open_filex/open_filex.dart'; // Add open_filex package
import 'package:video_player/video_player.dart'; // Add video_player package
import 'package:path/path.dart' as path; // For file name extraction
import 'package:url_launcher/url_launcher.dart'; // Add url_launcher package

class UploadScreen extends StatefulWidget {
  final String generatedVideoPath;
  final GoogleSignInAccount? currentUser; // Receive the authenticated user
  final bool isAuthenticated;
  final Function onSignIn; // Handle sign-in method
  final Function onSignOut; // Handle sign-out method

  // Add TextEditingController as a parameter to maintain state
  final TextEditingController titleController;
  final TextEditingController descriptionController;

  UploadScreen({
    required this.generatedVideoPath,
    required this.currentUser,
    required this.isAuthenticated,
    required this.onSignIn,
    required this.onSignOut,
    required this.titleController, // Maintain the state of title input
    required this.descriptionController, // Maintain the state of description input
  });

  @override
  _UploadScreenState createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  File? _selectedVideoFile;
  String? _videoUrl;
  VideoPlayerController? _videoController;
  bool _isUploading = false; // Track upload progress
  final _formKey = GlobalKey<FormState>(); // Form key for validation

  @override
  void initState() {
    super.initState();
    if (widget.generatedVideoPath.isNotEmpty) {
      _selectedVideoFile = File(widget.generatedVideoPath);
      _initializeVideoPlayer();
    }
  }

  Future<void> _initializeVideoPlayer() async {
    if (_selectedVideoFile != null) {
      _videoController = VideoPlayerController.file(_selectedVideoFile!)
        ..initialize().then((_) {
          setState(() {}); // Ensure that the video preview updates
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
    } else {
      print("No video selected");
    }
  }

  Future<void> _uploadVideoToYouTube() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedVideoFile != null && widget.currentUser != null) {
        setState(() {
          _isUploading = true; // Start the upload, show the progress indicator
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
            _isUploading =
                false; // Upload complete, hide the progress indicator
          });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Upload successful: $_videoUrl'),
          ));
        } catch (e) {
          setState(() {
            _isUploading = false; // Hide the progress indicator if upload fails
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

  Future<void> _openVideo() async {
    if (_selectedVideoFile != null) {
      await OpenFilex.open(
          _selectedVideoFile!.path); // Open video file using open_filex
    }
  }

  // Helper function to launch a URL
  Future<void> _launchYouTubeUrl(String url) async {
    final Uri _url = Uri.parse(url);
    if (!await launchUrl(_url, mode: LaunchMode.externalApplication)) {
      throw 'Could not launch $_url';
    }
  }

  Widget _buildLoggedOutBottomSheet() {
    return Container(
      width: MediaQuery.of(context).size.width, // Fill entire screen width
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Sign in to upload videos",
            style: TextStyle(color: Colors.black, fontSize: 18),
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              widget.onSignIn();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red, // Red background for the button
              foregroundColor: Colors.white, // White text color
            ),
            child: Text('Sign In with YouTube'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoggedInBottomSheet() {
    return Container(
      width: MediaQuery.of(context).size.width, // Fill entire screen width
      decoration: BoxDecoration(
        color: Colors.white, // Set the background color to white
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20), // Curved top border
        ),
      ),
      padding: EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: GoogleUserCircleAvatar(identity: widget.currentUser!),
            title: Text(widget.currentUser?.displayName ?? ''),
            subtitle: Text(widget.currentUser?.email ?? ''),
            trailing: IconButton(
              icon: Icon(Icons.logout),
              onPressed: () {
                widget.onSignOut();
              },
            ),
          ),
          // Show CircularProgressIndicator during upload
          if (_isUploading)
            Center(
              child: CircularProgressIndicator(),
            )
          else
            ElevatedButton(
              onPressed: _uploadVideoToYouTube,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, // Red background for the button
                foregroundColor: Colors.white, // White text color
              ),
              child: Text('Upload to YouTube'),
            ),
          if (_videoUrl != null)
            ElevatedButton(
              onPressed: () {
                _launchYouTubeUrl(_videoUrl!); // Use the new helper method
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, // Red background for the button
                foregroundColor: Colors.white, // White text color
              ),
              child: Text('Open Video in YouTube'),
            ),
        ],
      ),
    );
  }

  Widget _buildVideoPreview() {
    if (_selectedVideoFile == null || _videoController == null) {
      return Container();
    }

    return Stack(
      children: [
        // Video Preview with play button at the center
        Stack(
          children: [
            Container(
              height:
                  MediaQuery.of(context).size.height / 2, // Half screen height
              width: double.infinity,
              child: _videoController!.value.isInitialized
                  ? VideoPlayer(_videoController!)
                  : Container(color: Colors.black),
            ),
            Positioned.fill(
              child: Center(
                child: IconButton(
                  icon: Icon(
                    Icons.play_circle_fill,
                    color: Colors.white,
                    size: 64,
                  ),
                  onPressed:
                      _openVideo, // Open the video file on play button click
                ),
              ),
            ),
          ],
        ),
        // Display the file name at the bottom left above the preview area
        Positioned(
          left: 10,
          bottom: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(
                vertical: 8.0, horizontal: 12.0), // Inner padding
            decoration: BoxDecoration(
              color: Colors.black, // Background color
              borderRadius: BorderRadius.circular(12), // Curved border
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
    );
  }

  Widget _buildEmptyState() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.center, // Center content horizontally
      children: [
        // Grey background with the same dimensions as the video preview area
        Container(
          height: MediaQuery.of(context).size.height / 2, // Half screen height
          width: MediaQuery.of(context).size.width, // Full screen width
          color: Colors.grey[300], // Grey background color
          child: Center(
            child: ElevatedButton(
              onPressed: _pickVideo,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, // Red background for the button
                foregroundColor: Colors.white, // White text color
              ),
              child: Text('Pick a Video from Gallery'),
            ),
          ),
        ),
      ],
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
              labelText: widget.generatedVideoPath.isNotEmpty
                  ? 'Your Generated video title'
                  : 'Your video title',
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
                labelText: widget.generatedVideoPath.isNotEmpty
                    ? 'Your Generated video description'
                    : 'Your video description',
                border: OutlineInputBorder(),
                alignLabelWithHint: true),
            maxLines: 3,
          ),
        ),
        SizedBox(
            height:
                50), // Add bottom margin to avoid blocking by the bottom sheet
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    String appBarTitle;
    if (widget.generatedVideoPath.isNotEmpty) {
      appBarTitle = 'Upload Generated Video';
    } else if (_selectedVideoFile != null) {
      appBarTitle = 'Upload Picked Video';
    } else {
      appBarTitle = 'Upload to YouTube';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          appBarTitle,
          style: TextStyle(
            fontSize: 20,
          ),
        ), // Dynamic title
      ),
      body: SingleChildScrollView(
        // Make the entire content scrollable
        child: Form(
          key: _formKey, // Add the form key for validation
          child: Column(
            children: [
              // Video Preview Section
              if (_selectedVideoFile == null)
                _buildEmptyState()
              else if (_selectedVideoFile != null && _videoController != null)
                _buildVideoPreview(),
              SizedBox(height: 20),
              // Show title and description input fields only when a video is selected or generated
              if (_selectedVideoFile != null ||
                  widget.generatedVideoPath.isNotEmpty)
                _buildTextInputFields(),
              SizedBox(height: 100), // Add spacing at the bottom
            ],
          ),
        ),
      ),
      bottomSheet: widget.isAuthenticated
          ? _buildLoggedInBottomSheet()
          : _buildLoggedOutBottomSheet(),
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
