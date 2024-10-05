# shorts_composer

MVP for composing shorts or reels video on the go and upload to YouTube.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.



Video mixing (FFMPEG)

1. Mix scene and audio for each scene
2. Add background music
3. Add silence to the audio for each scene at the beggning and end
4. 




Pending items:

1. Preview the mixed images and voiceovers
8. Add Splash screen
2. Create subtitles trascription
3. Add watermarks
6. Play store release
11. UI to edit the uploaded JSON
4. Android compatability
5. Website compactabilty
7. Create Playstore account


Future plans:

9. Notifications if the Youtube upload is success
10. Integrate GPT to generate the JSON
12. Login functionality
13. Add new scene button functionality

Working animations

0
"zoompan=z='zoom+0.0015':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d={duration}:s=1080x1920"

1
"zoompan=z='zoom+0.005':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=25:s=1080x1920",

4
"zoompan=z=1.5:x='iw/2-(iw/zoom/2)':y='random(1)*20':d={duration}:s=1080x1920"

5
"split[original][copy];[copy]crop=iw:ih/3:0:ih/3,boxblur=10[blurred];[original][blurred]overlay=0:(H-h)/2",


Not working

2
"zoompan=z=1.5:x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d={duration}:s=1080x1920"

3
"zoompan=z=1.5:x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d={duration}:s=1080x1920"


Optimising the Video processing time

1. Hardware acceleration
  final ffmpegCommand = [
          '-y',
          '-hwaccel', 'auto', // Enable hardware acceleration
          '-i', imagePath,
          '-i', audioPath,
          '-i', watermarkPath,
          '-filter_complex',
          "[0:v]$selectedEffect[bg];" + watermarkFilter,
          '-c:v', 'libx264',
          '-pix_fmt', 'yuv420p',
          '-c:a', 'aac',
          '-b:a', '192k',
          '-shortest',
          '-t', scene.duration.toString(),
          outputPath,
        ];

2. Reduce the size of the generating video

final List<String> effects = [
  "zoompan=z='zoom+0.0015':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d={duration}:s=720x1280",
];

3. Lowering bit rate

'-b:v', '1000k',  // Lower video bitrate for faster processing

4. Parallel processing

await Future.wait(scenes.map((scene) async {
  await generateSceneVideo(scene);
}));


