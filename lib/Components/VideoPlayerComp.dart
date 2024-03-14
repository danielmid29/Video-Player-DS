import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart' as hooks;
import 'package:video_player/video_player.dart';

class VideoPlayerSync extends StatefulWidget {
  const VideoPlayerSync({Key? key}) : super(key: key);

  @override
  State<VideoPlayerSync> createState() => _VideoPlayerSyncState();
}

class _VideoPlayerSyncState extends State<VideoPlayerSync> {
  late VideoPlayerController _controller;
  late VoidCallback listener;
 @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(
        '/storage/emulated/0/Download/5 Second Video Watch the Milky Way Rise.mp4'))
      ..initialize()
      ..setVolume(1.0)
      ..play();
  }

  @override
  Widget build(BuildContext context) {

    _controller.addListener(() {setState(() {
      if (!_controller.value.isPlaying &&_controller.value.isInitialized &&
          (_controller.value.duration ==_controller.value.position)) { //checking the duration and position every time
        _controller = VideoPlayerController.file(File(
            '/storage/emulated/0/Download/[NO COPYRIGHT ANIMATION] 5-second Countdown Timer in Fire with Sound Effect.mp4'))
          ..initialize()
          ..setVolume(1.0)
          ..play();
      }
    });});


    return Container(
        child: _controller.value.isInitialized
            ? AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              )
            : Container());
  }
}
