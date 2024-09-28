import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'dart:convert';

import 'package:http_parser/http_parser.dart';

void main() {
  runApp(TranscriptionApp());
}

class TranscriptionApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Deepgram Transcription Test',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: TranscriptionScreen(),
    );
  }
}

class TranscriptionScreen extends StatefulWidget {
  @override
  _TranscriptionScreenState createState() => _TranscriptionScreenState();
}

class _TranscriptionScreenState extends State<TranscriptionScreen> {
  String? _pickedFilePath;
  AudioPlayer? _audioPlayer;
  bool _isPlaying = false;
  bool _isLoading = false;
  String? _transcriptionResult;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
  }

  void _pickAudioFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav'],
    );

    if (result != null) {
      setState(() {
        _pickedFilePath = result.files.single.path;
        _transcriptionResult = null; // Clear previous results
      });
      print('Selected file path: $_pickedFilePath');
    } else {
      print('No file selected');
    }
  }

  void _playAudio() async {
    if (_pickedFilePath != null && !_isPlaying) {
      await _audioPlayer!
          .play(DeviceFileSource(_pickedFilePath!)); // Play local file
      setState(() {
        _isPlaying = true;
      });
      print('Playing audio...');
    } else {
      print('No file selected or audio is already playing');
    }
  }

  void _stopAudio() async {
    if (_isPlaying) {
      await _audioPlayer!.stop();
      setState(() {
        _isPlaying = false;
      });
      print('Audio stopped');
    } else {
      print('Audio is not playing');
    }
  }

  Future<void> _transcribeAudio() async {
    if (_pickedFilePath == null) {
      print('No audio file selected');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Determine the correct content type based on the file extension
      String contentType;
      if (_pickedFilePath!.endsWith('.mp3')) {
        contentType = 'audio/mpeg'; // MP3 file type
      } else if (_pickedFilePath!.endsWith('.wav')) {
        contentType = 'audio/wav'; // WAV file type
      } else {
        print('Unsupported file type');
        return;
      }

      // Read the file as binary data
      File file = File(_pickedFilePath!);
      List<int> fileBytes = await file.readAsBytes();

      Uri url = Uri.parse(
          'https://api.deepgram.com/v1/listen?smart_format=true&model=nova-2&language=en-IN');

      // Make the POST request with binary data
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Token 03dba774090bd9452500c57e664d0d5b99f93fd5',
          'Content-Type': contentType,
        },
        body: fileBytes, // Send the binary data
      );

      print('Response status code: ${response.statusCode}');
      if (response.statusCode == 200) {
        setState(() {
          _transcriptionResult = jsonDecode(response.body)['results']
              ['channels'][0]['alternatives'][0]['transcript'];
        });
        print('Transcription: $_transcriptionResult');
      } else {
        print('Error: ${response.body}');
        setState(() {
          _transcriptionResult = 'Error: ${response.body}';
        });
      }
    } catch (e) {
      print('Error during transcription: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _audioPlayer!.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Audio Transcription'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_pickedFilePath != null)
                Text('Selected file: ${_pickedFilePath!.split('/').last}'),
              SizedBox(height: 10),
              ElevatedButton(
                onPressed: _pickAudioFile,
                child: Text('Pick Audio File (MP3 or WAV)'),
              ),
              SizedBox(height: 10),
              if (_pickedFilePath != null)
                ElevatedButton(
                  onPressed: _isPlaying ? _stopAudio : _playAudio,
                  child: Text(_isPlaying ? 'Stop Audio' : 'Play Audio'),
                ),
              SizedBox(height: 10),
              if (_pickedFilePath != null)
                ElevatedButton(
                  onPressed: _transcribeAudio,
                  child: Text('Transcribe Audio'),
                ),
              SizedBox(height: 20),
              if (_isLoading) CircularProgressIndicator(),
              if (_transcriptionResult != null)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text('Transcription: $_transcriptionResult'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
