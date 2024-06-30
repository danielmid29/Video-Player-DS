import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

Future<String> getCurrentCity() async {
  bool serviceEnabled;
  LocationPermission permission;

  try {
    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return 'Location services are disabled';
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return 'Location permissions are denied';
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return 'Location permissions are permanently denied';
    }

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    if (position == null) {
      return 'All';
    }

    return await _getAddressFromLatLng(position);
  } on Exception catch (e) {
    print("Platform Exception: $e");
    return 'All';
  }
}

Future<String> _getAddressFromLatLng(Position position) async {
  try {
    List<Placemark> placemarks = await placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    );

    if (placemarks.isEmpty) {
      return 'Failed to get address';
    }

    Placemark place = placemarks[0];
    return '${place.locality}, ${place.country}';
  } catch (e) {
    print('Failed : $e');
    return 'Failed to get address';
  }
}
