import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart' as p;
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;
import 'package:googleapis/drive/v2.dart' as v2;
import 'package:dio/dio.dart';

import 'GoogleAuthClient.dart';

class Loading extends StatefulWidget {
  const Loading({Key? key}) : super(key: key);

  @override
  State<Loading> createState() => _LoadingState();
}

List<String?> systemFileNames = [];

class _LoadingState extends State<Loading> {
  bool loading = false;

  VideoPlayerController _controller =
      VideoPlayerController.asset("assets/loading.mp4");
  late VoidCallback listener;
  int index = 0;

  final String _clientId =
      '62178366962-svi1sjho7f40aug610hjlojcrfk6csc7.apps.googleusercontent.com';
  final String _clientSecret = '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';
  final String _refreshToken =
      '1//0gLu1dURyDe6yCgYIARAAGBASNwF-L9IrNc_ePMlstR_RDTgYYz06nSpb1Ih226KDNZPGRU4BczJhiGrZQlcTS3EM2NMtRV_ti5k';

  void getPermissions() async {
    AndroidDeviceInfo build = await DeviceInfoPlugin().androidInfo;
    print('Android Version : ${build.version.release}');
    if (build.version.sdkInt > 33) {
      var re = await p.Permission.manageExternalStorage.request();
      if (!re.isGranted) {
        getPermissions();
      } else {
        syncDriveFiles();
      }
    } else if (build.version.release == '13') {
      if (!await p.Permission.photos.isGranted) {
        p.Permission.photos.request();
      } else {
        syncDriveFiles();
      }
    } else {
      if (!await p.Permission.storage.isGranted) {
        p.Permission.storage.request();
      } else {
        syncDriveFiles();
      }
    }
  }

  void _initiateVideoController(String? videoPath) {
    _controller.dispose();
    if (videoPath == null) {
      _controller = VideoPlayerController.asset("assets/loading.mp4");
    } else {
      _controller = VideoPlayerController.file(File(videoPath!))
        ..initialize()
        ..setVolume(1.0)
        ..play();

      setState(() {});
    }
  }

  late Timer runSync;
  int timerSecs = 15;

  void initiateTimer(int seconds) {
    runSync = Timer.periodic(Duration(seconds: seconds), (timer) {
      getPermissions();
    });
  }

  @override
  void initState() {
    getPermissions();
    initiateTimer(30);
    print(_controller.value.duration);
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
    _controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _controller.addListener(() {
      setState(() {
        if (!_controller.value.isPlaying &&
            _controller.value.isInitialized &&
            (_controller.value.duration == _controller.value.position)) {
          //checking the duration and position every time

          index++;

          if (systemFileNames.length - 1 < index) {
            index = 0;
          }

          if (systemFileNames.isNotEmpty) {
            _initiateVideoController(systemFileNames.elementAt(index));
          } else {
            _initiateVideoController(null);
          }
        }
      });
    });

    return Container(
      color: Colors.white12,
      child: _controller.value.isInitialized
          ? AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: VideoPlayer(_controller),
            )
          : Center(
              child: getSpinkit(),
            ),
    );
  }

  Widget getSpinkit() {
    if (loading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SpinKitSpinningLines(
              color: Colors.amber,
              size: 100.0,
            ),
            Padding(
              padding: EdgeInsets.only(top: 50),
              child: Text(
                "Downloading Video ...",
                style: TextStyle(
                    color: Colors.amber,
                    letterSpacing: 5,
                    fontWeight: FontWeight.w100,
                    fontSize: 25,
                    decoration: TextDecoration.none),
              ),
            )
          ],
        ),
      );
    } else {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SpinKitSpinningLines(
              color: Colors.amber,
              size: 100.0,
            ),
            Padding(
              padding: EdgeInsets.only(top: 50),
              child: Text(
                "Loading ...",
                style: TextStyle(
                    color: Colors.amber,
                    letterSpacing: 5,
                    fontWeight: FontWeight.w100,
                    fontSize: 25,
                    decoration: TextDecoration.none),
              ),
            )
          ],
        ),
      );
    }
  }

  void syncDriveFiles() async {
    List<String?> driveFileNames = [];

    Directory? directory = await getExternalStorageDirectory();
    List<FileSystemEntity>? fileSystem = directory?.listSync().toList();
    print(fileSystem);
    systemFileNames = [];
    fileSystem?.forEach((systemFile) {
      systemFileNames.add(systemFile.path);
    });

    try {
      final queryParameters = {
        'client_id': _clientId,
        'client_secret': _clientSecret,
        'refresh_token': _refreshToken,
        'grant_type': 'refresh_token',
      };

      var url = Uri.https('oauth2.googleapis.com', '/token', queryParameters);

      final response = await http.post(url, headers: Map.of({'Accept': '*/*'}));
      var decoded = json.decode(response.body);
      final listFilesParameters = {
        'q': 'trashed\=false',
      };
      String accessToken = decoded['access_token'];
      var listFilesUri = Uri.https(
          'www.googleapis.com', '/drive/v3/files/', listFilesParameters);

      final listFilesResponse = await http.get(listFilesUri,
          headers:
          Map.of({'Accept': '*/*', 'Authorization': 'Bearer $accessToken'}));

      var lfDecodedResponse = json.decode(listFilesResponse.body);

      for (var singleResponse in lfDecodedResponse['files']) {
        String name = singleResponse['name'];

        if (name.endsWith('mp4')) {
          driveFileNames.add('${directory?.path}/$name');
          if (!systemFileNames.contains('${directory?.path}/$name')) {
            if (systemFileNames.isEmpty) {
              setState(() {
                loading = true;
              });
            }
            final dio = Dio();
            await dio
                .download(
                'https://www.googleapis.com/drive/v3/files/${singleResponse['id']}/?alt=media',
                '${directory?.path}/$name',
                options: Options(
                    headers: {'Authorization': 'Bearer $accessToken'},
                    method: 'GET'))
                .then((value) {
              if (value.statusCode == 200) {
                setState(() {
                  if (systemFileNames.isEmpty) {
                    loading = false;
                    _initiateVideoController('${directory?.path}/$name');
                    systemFileNames.add('${directory?.path}/$name');
                  }
                });
              }
            });
          }
        }
      }

      List<String> deleteFiles = [];
      for (var sfName in systemFileNames) {
        if (!driveFileNames.contains(sfName)) {
          File deleteFile = File(sfName!);
          print(deleteFile.path);
          deleteFile.deleteSync();
          deleteFiles.add(sfName);
          print('Deleted ${deleteFile.path!}');
        }
      }

      for (var del in deleteFiles) {
        systemFileNames.remove(del);
      }
      deleteFiles.clear();
    }catch(e){
      print(e.toString());
    }
    if (!_controller.value.isPlaying) {
      if (systemFileNames.isNotEmpty) {
        _initiateVideoController(systemFileNames.first);
      } else {
        _initiateVideoController(null);
      }
    }
  }
}
