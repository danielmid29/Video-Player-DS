import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;

List<CameraDescription> cameras = [];

class DetectFaces {
  late Timer runSync;
  late String _deviceId;

  void initiateCameraTimer() async {
    cameras = await availableCameras();
    _getDeviceId();
  }

  Future<void> requestCameraPermission() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      if (kDebugMode) {
        print('Camera permission granted');
      }
    } else if (status.isDenied) {
      // Camera permission is denied
      if (kDebugMode) {
        print('Camera permission denied');
      }
    } else if (status.isPermanentlyDenied) {
      // Camera permission is permanently denied
      if (kDebugMode) {
        print('Camera permission permanently denied');
      }
      await openAppSettings(); // Open app settings to grant permission
    }
  }

  Future<void> captureImageAndDetectFaces(String videoName, String currentCity,
      Future<String?> Function() getValidToken) async {
    videoName = videoName.replaceAll(
        "/storage/emulated/0/Android/data/com.video.player.sync.video_player_ds/files/",
        "");

    if (kDebugMode) {
      print("Video file name : $videoName");
    }
    CameraDescription frontCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => cameras[
          0], // fallback to the first camera if no front camera is found
    );
    // Initialize camera
    final CameraController cameraController = CameraController(
      frontCamera,
      ResolutionPreset.high, // Adjust as needed
      enableAudio: false,
    );

    try {
      var token = await getValidToken();
      if (kDebugMode) {
        print("token camera $token");
      }
      await cameraController.initialize();
      final XFile picture = await cameraController.takePicture();
      await _uploadImage(picture.path, videoName, currentCity, token);
    } catch (e) {
      if (kDebugMode) {
        print('Failed to initialize camera: $e');
      }
    } finally {
      cameraController.dispose();
    }
  }

  Future<void> _uploadImage(String imagePath, String videoName,
      String currentCity, String? token) async {
    if (token == null) {
      if (kDebugMode) {
        print('No JWT token found');
      }
      return;
    }

    final uri = Uri.parse(
        'http://ec2-51-20-53-56.eu-north-1.compute.amazonaws.com:8080/keto-motors/api/logs/save');
    var request = http.MultipartRequest('POST', uri);

    request.fields['device'] = _deviceId;
    request.fields['video'] = videoName;
    request.fields['location'] = currentCity; // Adjust as needed
    request.fields['date'] = DateTime.now().toIso8601String();

    var file = await http.MultipartFile.fromPath('image', imagePath);
    request.files.add(file);

    request.headers['Content-Type'] = 'image/jpeg';
    request.headers['Authorization'] = 'Bearer $token';

    try {
      final response = await request.send();
      if (response.statusCode == 201) {
        if (kDebugMode) {
          print('Image uploaded successfully');
        }
      } else {
        if (kDebugMode) {
          print('Failed to upload image: ${response.statusCode}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to upload image: $e');
      }
    }
  }

  Future<void> _getDeviceId() async {
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    final deviceData = await deviceInfo.deviceInfo;
    if (deviceData is AndroidDeviceInfo) {
      _deviceId = deviceData.id; // This is the Android ID
    } else if (deviceData is IosDeviceInfo) {
      _deviceId = deviceData.identifierForVendor!; // This is the iOS ID
    }
  }
}
