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



Done:
7. Create Playstore account
4. Android compatability
13. Add new scene button functionality

Partially Done:
6. Play store release
8. Add Splash screen

Pending items:
1. Flutter upgrade
2. Crop customisation
3. Version 2.0
4. Preview issue
5. Allow only a fixed size of the watermark


Future plans:

1. Enable video pick along with
3. Add silence to the audio for each scene at the beggning and end
5. Website compactabilty
11. UI to edit the uploaded JSON
9. Notifications if the Youtube upload is success
10. Integrate GPT to generate the JSON
12. Login functionality





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

New animations

        // // Smooth Orbit Zoom In (Circular Pan)
        "zoompan=z='1.05+0.0003*on':x='iw/2-(iw/zoom/2)+cos(on*0.1)*30':y='ih/2-(ih/zoom/2)+sin(on*0.1)*30':d={duration}:s=1080x1920",


        // // Smooth Side-to-Side Pan with Subtle Zoom
        "zoompan=z='1.05+0.0005*on':x='iw/2-(iw/zoom/2)+sin(on*0.05)*100':y='ih/2-(ih/zoom/2)':d={duration}:s=1080x1920",

     // //Diagonal Pan with Zoom In
        "zoompan=z='zoom+0.002':x='iw/2-(iw/zoom/2)+(on*10)':y='ih/2-(ih/zoom/2)+(on*10)':d={duration}:s=1080x1920",

 // // Zoom Out with Shaking Effect
        "zoompan=z='1.2-0.01*on':x='iw/2-(iw/zoom/2)+sin(on*10)*15':y='ih/2-(ih/zoom/2)+cos(on*10)*15':d={duration}:s=1080x1920",

// // Oscillating Zoom with Horizontal Sway
        "zoompan=z='1+0.04*sin(on*6)':x='iw/2-(iw/zoom/2)+sin(on*3.14)*200':y='ih/2-(ih/zoom/2)':d={duration}:s=1080x1920"


        // // Soft Bounce Effect with Light Zoom
        "zoompan=z='1+0.02*sin(on*3.14/6)':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d={duration}:s=1080x1920",




        // // Zoom with Sudden Jerks (Random Positions)
        "zoompan=z='1.1+random(1)*0.1':x='random(1)*iw':y='random(1)*ih':d=5:s=1080x1920",


        // // Smooth Zoom In
        // "zoompan=z='1.05+0.0005*on':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d={duration}:s=1080x1920",


        // // Diagonal Pan with Slow Zoom
        "zoompan=z='1.1+0.0005*on':x='(iw-iw/zoom)*(on/({duration}*0.7))':y='(ih-ih/zoom)*(on/({duration}*0.7))':d={duration}:s=1080x1920",


        // // Gentle Zoom Out
        "zoompan=z='1.2-0.0005*on':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d={duration}:s=1080x1920",

   // // Vertical Slide with Subtle Zoom Out
        "zoompan=z='1.1-0.0005*on':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)-(on*5)':d={duration}:s=1080x1920",

        // // Smooth Circular Pan with Slow Zoom In
        "zoompan=z='1.1+0.0003*on':x='iw/2-(iw/zoom/2)+cos(on*0.05)*20':y='ih/2-(ih/zoom/2)+sin(on*0.05)*20':d={duration}:s=1080x1920",

        // // Slow Diagonal Slide with Zoom Out
        "zoompan=z='1.1-0.0004*on':x='(iw-iw/zoom)*(on/({duration}*0.7))':y='(ih-ih/zoom)*(1-on/({duration}*0.7))':d={duration}:s=1080x1920",

 // // Subtle Diagonal Pan Top-Left to Bottom-Right with Zoom Out
        "zoompan=z='1.1-0.0003*on':x='(iw-iw/zoom)*(1-on/({duration}*0.9))':y='(ih-ih/zoom)*(1-on/({duration}*0.9))':d={duration}:s=1080x1920",

        // // Gentle Orbit with Light Zoom In
        "zoompan=z='1.02+0.0002*on':x='iw/2-(iw/zoom/2)+cos(on*0.05)*15':y='ih/2-(ih/zoom/2)+sin(on*0.05)*15':d={duration}:s=1080x1920",

         // // Slow Vertical Sway with Zoom Out
        "zoompan=z='1.1-0.0003*on':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)+sin(on*0.05)*30':d={duration}:s=1080x1920"

         // // Horizontal Sway with Subtle Zoom
        "zoompan=z='1.02+0.0004*on':x='iw/2-(iw/zoom/2)+sin(on*0.1)*50':y='ih/2-(ih/zoom/2)':d={duration}:s=1080x1920",


All working animations

// //Zoom in multiple times
        // "zoompan=z='zoom+0.005':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=25:s=1080x1920",
        // //Jerk animation
        // "zoompan=z=1.5:x='iw/2-(iw/zoom/2)':y='random(1)*20':d={duration}:s=1080x1920",
        // //Random zoom with both horizontal and vertical random panning
        // "zoompan=z='1.3+random(1)*0.1':x='random(1)*iw':y='random(1)*ih':d={duration}:s=1080x1920",
        // //Pan left to right
        // "zoompan=z=1.3:x='(iw-iw/zoom)*(1-on/({duration}*0.7))':y='ih/2-(ih/zoom/2)':d={duration}:s=1080x1920",
        // "zoompan=z=1.4:x='(iw-iw/zoom)*(1-on/({duration}*0.5))':y='ih/2-(ih/zoom/2)':d={duration}:s=1080x1920",
        // //Pan right to left
        // "zoompan=z=1.3:x='(iw-iw/zoom)*(on/({duration}*0.7))':y='ih/2-(ih/zoom/2)':d={duration}:s=1080x1920",
        // "zoompan=z=1.3:x='(iw-iw/zoom)*(on/({duration}*0.5))':y='ih/2-(ih/zoom/2)':d={duration}:s=1080x1920"

//         // // Smooth Orbit Zoom In (Circular Pan)
        // "zoompan=z='1.05+0.0003*on':x='iw/2-(iw/zoom/2)+cos(on*0.1)*30':y='ih/2-(ih/zoom/2)+sin(on*0.1)*30':d={duration}:s=1080x1920",

//             // // Smooth Orbit Zoom In (Circular Pan)
        // "zoompan=z='1.05+0.0003*on':x='iw/2-(iw/zoom/2)+cos(on*0.1)*30':y='ih/2-(ih/zoom/2)+sin(on*0.1)*30':d={duration}:s=1080x1920",

//         // //Diagonal Pan with Zoom In
        // "zoompan=z='zoom+0.002':x='iw/2-(iw/zoom/2)+(on*10)':y='ih/2-(ih/zoom/2)+(on*10)':d={duration}:s=1080x1920",

//         // // Zoom Out with Shaking Effect
        // "zoompan=z='1.2-0.01*on':x='iw/2-(iw/zoom/2)+sin(on*10)*15':y='ih/2-(ih/zoom/2)+cos(on*10)*15':d={duration}:s=1080x1920",

// // // Oscillating Zoom with Horizontal Sway
        // "zoompan=z='1+0.04*sin(on*6)':x='iw/2-(iw/zoom/2)+sin(on*3.14)*200':y='ih/2-(ih/zoom/2)':d={duration}:s=1080x1920"

//             // // Soft Bounce Effect with Light Zoom
        // "zoompan=z='1+0.02*sin(on*3.14/6)':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d={duration}:s=1080x1920",

//         // // Zoom with Sudden Jerks (Random Positions)
        // "zoompan=z='1.1+random(1)*0.1':x='random(1)*iw':y='random(1)*ih':d=5:s=1080x1920",

//         // // Smooth Zoom In
        // "zoompan=z='1.05+0.0005*on':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d={duration}:s=1080x1920",

//         // // Diagonal Pan with Slow Zoom
        // "zoompan=z='1.1+0.0005*on':x='(iw-iw/zoom)*(on/({duration}*0.7))':y='(ih-ih/zoom)*(on/({duration}*0.7))':d={duration}:s=1080x1920",

//         // // Gentle Zoom Out
        // "zoompan=z='1.2-0.0005*on':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d={duration}:s=1080x1920",

//         // // Vertical Slide with Subtle Zoom Out
        // "zoompan=z='1.1-0.0005*on':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)-(on*5)':d={duration}:s=1080x1920",

//         // // Smooth Circular Pan with Slow Zoom In
        // "zoompan=z='1.1+0.0003*on':x='iw/2-(iw/zoom/2)+cos(on*0.05)*20':y='ih/2-(ih/zoom/2)+sin(on*0.05)*20':d={duration}:s=1080x1920",

//         // // Slow Diagonal Slide with Zoom Out
        // "zoompan=z='1.1-0.0004*on':x='(iw-iw/zoom)*(on/({duration}*0.7))':y='(ih-ih/zoom)*(1-on/({duration}*0.7))':d={duration}:s=1080x1920",

//         // // Subtle Diagonal Pan Top-Left to Bottom-Right with Zoom Out
        // "zoompan=z='1.1-0.0003*on':x='(iw-iw/zoom)*(1-on/({duration}*0.9))':y='(ih-ih/zoom)*(1-on/({duration}*0.9))':d={duration}:s=1080x1920",

//         // // Gentle Orbit with Light Zoom In
        // "zoompan=z='1.02+0.0002*on':x='iw/2-(iw/zoom/2)+cos(on*0.05)*15':y='ih/2-(ih/zoom/2)+sin(on*0.05)*15':d={duration}:s=1080x1920",

//         // // Slow Vertical Sway with Zoom Out
        // "zoompan=z='1.1-0.0003*on':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)+sin(on*0.05)*30':d={duration}:s=1080x1920"

//             // // Horizontal Sway with Subtle Zoom
        // "zoompan=z='1.02+0.0004*on':x='iw/2-(iw/zoom/2)+sin(on*0.1)*50':y='ih/2-(ih/zoom/2)':d={duration}:s=1080x1920",
        
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


