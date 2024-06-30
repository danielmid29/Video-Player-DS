import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart' as p;
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'package:intl/intl.dart';

import 'DetectFaces.dart';
import 'DetectLocation.dart';

class Loading extends StatefulWidget {
  const Loading({Key? key}) : super(key: key);

  @override
  State<Loading> createState() => _LoadingState();
}

List<String?> systemFileNames = [];
List<CameraDescription> cameras = [];

class _LoadingState extends State<Loading> {
  bool loading = false;
  var response = [];
  VideoPlayerController? _controller =
      VideoPlayerController.asset("assets/loading.mp4");
  int index = 0;
  DetectFaces detectFaces = DetectFaces();
  late String currentCity;
  final storage = const FlutterSecureStorage();
  String? videoName = '';

  @override
  void initState() {
    super.initState();
    authenticateUser("testuser", "password");
    loadCachedLibraryFiles();
    getPermissions();
    initiateTimer(150);
    detectFaces.initiateCameraTimer();
    _controller?.addListener(_videoListener);
  }

  @override
  void dispose() {
    _controller?.removeListener(_videoListener);
    _controller?.dispose();
    runSync.cancel();
    stateSync.cancel();
    super.dispose();
  }

  late Timer runSync;
  late Timer stateSync;
  void initiateTimer(int seconds) {
    runSync = Timer.periodic(Duration(seconds: seconds), (timer) {
      loadCachedLibraryFiles();
      getPermissions();
      getLocation();
    });
    stateSync = Timer.periodic(const Duration(seconds: 1), (timer) {
      setStateInitializer();
      loadCachedLibraryFiles();
    });
  }

  bool _isChangingVideo = false;

  void _initiateVideoController(String? videoPath) {
    if (kDebugMode) {
      print("_initiateVideoController $videoPath");
      print("_initiateVideoController $_isChangingVideo");
    }
    if (_isChangingVideo &&
        _controller != null &&
        _controller!.value.isInitialized &&
        _controller!.value.isPlaying) return;
    _isChangingVideo = true;

    if (_controller != null && _controller!.value.isInitialized) {
      _controller?.removeListener(_videoListener);
      _controller?.dispose();
      _controller = null; // Set the controller to null after disposing
    }

    print("init video response : $videoPath $response");

    if (videoPath == null || response.isEmpty) {
      _controller = VideoPlayerController.asset("assets/loading.mp4");
      _controller?.initialize().then((_) {
        if (mounted) {
          setState(() {
            _controller?.play();
          });
        }
        _controller?.addListener(_videoListener);
        _isChangingVideo = false;
        videoName = '';
      });
    } else {
      if (kDebugMode) {
        print(videoPath);
      }
      DateTime now = DateTime.now();
      String currentTime = DateFormat.Hms().format(now);
      String currentDay = DateFormat.EEEE().format(now);
      print(currentDay);
      bool videoFound = false;
      if (kDebugMode) {
        print(response);
      }

      int loop = 0;
      for (var data in response) {
        String videoName = data['videoName'];
        String fromTime = data['fromTime'];
        String toTime = data['toTime'];
        String weekAvailability = data['weekAvailability'];
        String location = data['location'];
        bool enable = data['enable'];

        if (kDebugMode) {
          print(videoPath.contains(videoName));
        }

        if (videoPath.contains(videoName)) {
          if (enable &&
              isWithinTimeRange(currentTime, fromTime, toTime) &&
              isWithinWeekAvailability(currentDay, weekAvailability) &&
              (currentCity.contains(location) || location.contains("All"))) {
            _controller = VideoPlayerController.file(File(videoPath));
            _controller?.initialize().then((_) {
              if (mounted) {
                setState(() {
                  _controller?.play();
                });
              }
              _isChangingVideo = false;
            });
            _controller?.setVolume(1.0);
            _controller?.addListener(_videoListener);
            videoFound = true;
            this.videoName = '';
            if (kDebugMode) {
              print('Video is available to play: $videoName');
            }
            break;
          } else {
            if (kDebugMode) {
              print('Video is not available to play: $videoName');
              print(
                  'Time range: ${isWithinTimeRange(currentTime, fromTime, toTime)}');
              print(
                  'Week availability: ${isWithinWeekAvailability(currentDay, weekAvailability)}');
            }
          }
        }
      }

      if (!videoFound) {
        _moveToNextVideo(false);
      }
    }
  }

  void _videoListener() {
    if (!_isChangingVideo &&
        _controller != null &&
        _controller!.value.isInitialized &&
        !_controller!.value.isPlaying &&
        _controller!.value.position >=
            _controller!.value.duration - const Duration(milliseconds: 100)) {
      _moveToNextVideo(true);
    }
  }

  void _moveToNextVideo(bool firstLoop) {
    if (_isChangingVideo &&
        _controller != null &&
        _controller!.value.isInitialized &&
        _controller!.value.isPlaying) return;
    _isChangingVideo = true;

    setState(() {
      index++;
      if (index >= systemFileNames.length) {
        index = 0;
      }
      if (systemFileNames.isNotEmpty) {
        if (videoName != systemFileNames.elementAt(index)) {
          if (firstLoop) {
            videoName = systemFileNames.elementAt(index);
          }
          _initiateVideoController(systemFileNames.elementAt(index));
        } else {
          videoName = '';
          _initiateVideoController(null);
        }
      } else {
        _initiateVideoController(null);
        videoName = '';
      }
    });
  }

  Future<void> getLocation() async {
    currentCity = await getCurrentCity();
    await detectFace();
  }

  Future<void> detectFace() async {
    await detectFaces.requestCameraPermission();
    if (systemFileNames.isNotEmpty) {
      await detectFaces.captureImageAndDetectFaces(
          systemFileNames[index]!, currentCity, getValidToken);
    }
  }

  void getPermissions() async {
    AndroidDeviceInfo build = await DeviceInfoPlugin().androidInfo;
    bool permissionGranted = false;
    if (kDebugMode) {
      print("sync files");
    }
    if (build.version.sdkInt > 33) {
      var status = await p.Permission.manageExternalStorage.request();
      permissionGranted = status.isGranted;
    } else if (build.version.release == '13') {
      var status = await p.Permission.photos.request();
      permissionGranted = status.isGranted;
    } else {
      var status = await p.Permission.storage.request();
      permissionGranted = status.isGranted;
    }

    if (permissionGranted) {
      if (kDebugMode) {
        print("Storage permission Granted");
      }
      syncLibraryFiles();
      await getLocation();
    } else {
      getPermissions();
    }
  }

  void setStateInitializer() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white12,
      child: _controller!.value.isInitialized
          ? AspectRatio(
              aspectRatio: _controller!.value.aspectRatio,
              child: VideoPlayer(_controller!),
            )
          : Center(child: getSpinkit()),
    );
  }

  Widget getSpinkit() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SpinKitSpinningLines(
            color: Colors.amber,
            size: 100.0,
          ),
          Padding(
            padding: const EdgeInsets.only(top: 50),
            child: Text(
              loading ? "Downloading Video ..." : "Loading ...",
              style: const TextStyle(
                color: Colors.amber,
                letterSpacing: 5,
                fontWeight: FontWeight.w100,
                fontSize: 25,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<String?> getValidToken() async {
    String? token = await storage.read(key: 'jwt_token');
    String? expiryDateStr = await storage.read(key: 'jwt_token_expiry');

    if (token == null || expiryDateStr == null) {
      return null;
    }

    DateTime expiryDate = DateTime.parse(expiryDateStr);

    if (DateTime.now().isAfter(expiryDate)) {
      // Token has expired, authenticate again
      await authenticateUser('your_username', 'your_password');
      token = await storage.read(key: 'jwt_token');
    }

    return token;
  }

  void syncLibraryFiles() async {
    if (kDebugMode) {
      print("Sync videos");
    }
    List<String?> libraryFileNames = [];
    Directory? directory = await getExternalStorageDirectory();
    List<FileSystemEntity>? fileSystem = directory?.listSync().toList();
    systemFileNames = fileSystem?.map((e) => e.path).toList() ?? [];

    try {
      // Get valid JWT token
      String? token = await getValidToken();
      if (token == null) {
        throw Exception('No JWT token found');
      }

      var url = Uri.parse(
          'http://ec2-51-20-53-56.eu-north-1.compute.amazonaws.com:8080/keto-motors/api/library/search');
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (kDebugMode) {
        print("response : $response");
      }
      if (response.statusCode == 200) {
        var decodedResponse = json.decode(response.body);
        if (kDebugMode) {
          print("decodedResponse : $decodedResponse");
        }
        for (var singleResponse in decodedResponse) {
          String videoName = singleResponse['videoName'];
          int mainId = singleResponse['mainId'];
          String fileName = '${directory?.path}/$videoName';
          libraryFileNames.add(fileName);

          if (!systemFileNames.contains(fileName)) {
            if (systemFileNames.isEmpty) {
              setState(() {
                loading = true;
              });
            }

            final dio = Dio();
            var videoUrl = Uri.parse(
                'http://ec2-51-20-53-56.eu-north-1.compute.amazonaws.com:8080/keto-motors/api/library/videos/$mainId');
            await dio
                .download(videoUrl.toString(), fileName,
                    options: Options(
                      method: 'GET',
                      headers: {
                        'Authorization': 'Bearer $token',
                      },
                    ))
                .then((value) {
              if (value.statusCode == 200) {
                setState(() {
                  if (systemFileNames.isEmpty) {
                    loading = false;
                    _initiateVideoController(fileName);
                    systemFileNames.add(fileName);
                  }
                });
              }
            });
          }
        }
        // Save the response to SharedPreferences
        SharedPreferences prefs = await SharedPreferences.getInstance();
        prefs.setString('library_response', response.body);

        loadCachedLibraryFiles();
        // Deleting files that are not in the librar
        List<String> deleteFiles = [];
        for (var sfName in systemFileNames) {
          if (!libraryFileNames.contains(sfName)) {
            File deleteFile = File(sfName!);
            deleteFile.deleteSync();
            deleteFiles.add(sfName);
          }
        }

        systemFileNames.removeWhere((name) => deleteFiles.contains(name));
      } else {
        throw Exception('Failed to fetch library files ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print("error fetch : $e");
      }
      _videoListener();
    }

    if (!_controller!.value.isPlaying) {
      if (systemFileNames.isNotEmpty) {
        _initiateVideoController(systemFileNames.first);
      } else {
        _initiateVideoController(null);
      }
    }
    loadCachedLibraryFiles();
  }

  // Load the cached response
  void loadCachedLibraryFiles() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? cachedResponse = prefs.getString('library_response');

    if (cachedResponse != null) {
      response = json.decode(cachedResponse);
    } else {
      // No cached response found, handle accordingly
    }
  }

  bool isWithinTimeRange(String currentTime, String fromTime, String toTime) {
    DateTime now = DateFormat.Hms().parse(currentTime);
    DateTime from = DateFormat.Hms().parse(fromTime);
    DateTime to = DateFormat.Hms().parse(toTime);

    return now.isAfter(from) && now.isBefore(to);
  }

  bool isWithinWeekAvailability(String currentDay, String weekAvailability) {
    List<String> availableDays = [];
    if (weekAvailability.contains("Weekend")) {
      availableDays = ["Saturday", "Sunday"];
    } else if (weekAvailability.contains("All days")) {
      availableDays = ["Monday", "Sunday"];
    } else {
      availableDays = weekAvailability.split(' - ');
    }
    if (availableDays.length == 2) {
      DateTime now = DateTime.now();
      int currentDayIndex = now.weekday;
      int startDayIndex = getWeekdayIndex(availableDays[0]);
      int endDayIndex = getWeekdayIndex(availableDays[1]);
      return currentDayIndex >= startDayIndex && currentDayIndex <= endDayIndex;
    }
    return false;
  }

  int getWeekdayIndex(String day) {
    switch (day) {
      case 'Monday':
        return DateTime.monday;
      case 'Tuesday':
        return DateTime.tuesday;
      case 'Wednesday':
        return DateTime.wednesday;
      case 'Thursday':
        return DateTime.thursday;
      case 'Friday':
        return DateTime.friday;
      case 'Saturday':
        return DateTime.saturday;
      case 'Sunday':
        return DateTime.sunday;
      default:
        return -1;
    }
  }

  Future<void> authenticateUser(String username, String password) async {
    var url = Uri.parse(
        'http://ec2-51-20-53-56.eu-north-1.compute.amazonaws.com:8080/keto-motors/authenticate');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'username': username, 'password': password}),
    );

    if (response.statusCode == 200) {
      var decodedResponse = json.decode(response.body);
      String token = decodedResponse['jwt'];
      // Assume the response contains an expiration time in seconds or milliseconds
      DateTime expiryDate =
          DateTime.now().add(const Duration(seconds: 60 * 60 * 24));

      await storage.write(key: 'jwt_token', value: token);
      await storage.write(
          key: 'jwt_token_expiry', value: expiryDate.toIso8601String());
    } else {
      throw Exception('Failed to authenticate user');
    }
  }
}
