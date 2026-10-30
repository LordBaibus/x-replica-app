import 'dart:async';
import 'dart:math' as math;

import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

/// Finds place names for the composer's "Tag location" sheet.
///
/// GPS comes from the phone (the OS shows its own permission prompt) and the
/// names from the phone's built-in geocoder, so no API key is needed.
class LocationService {
  LocationService._();

  /// The phone's position, or null when location is off / not allowed.
  static Future<Position?> currentPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      try {
        return await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
            timeLimit: Duration(seconds: 12),
          ),
        );
      } catch (_) {
        return await Geolocator.getLastKnownPosition();
      }
    } catch (_) {
      return null;
    }
  }

  /// "Arayat, Central Luzon"
  static String? labelOf(Placemark p) {
    String? pick(List<String?> xs) {
      for (final x in xs) {
        if (x != null && x.trim().isNotEmpty) return x.trim();
      }
      return null;
    }

    final place = pick([p.locality, p.subAdministrativeArea, p.subLocality, p.name]);
    final region = pick([p.administrativeArea, p.country]);
    if (place == null) return region;
    if (region == null || region == place) return place;
    return '$place, $region';
  }

  static Future<String?> _labelAt(double lat, double lng) async {
    try {
      final marks = await placemarkFromCoordinates(lat, lng);
      for (final m in marks) {
        final l = labelOf(m);
        if (l != null) return l;
      }
    } catch (_) {
      // The geocoder can refuse a request; the next point may work.
    }
    return null;
  }

  /// Places around [pos]: the spot itself, then rings 5 km and 10 km out.
  /// Yields each new name as soon as it is known (at most [max]).
  static Stream<String> nearby(Position pos, {int max = 10}) async* {
    final seen = <String>{};
    final points = <List<double>>[
      [pos.latitude, pos.longitude],
    ];
    for (final r in const [0.045, 0.09]) {
      for (var deg = 0; deg < 360; deg += 45) {
        final rad = deg * math.pi / 180;
        points.add([
          pos.latitude + r * math.sin(rad),
          pos.longitude + r * math.cos(rad),
        ]);
      }
    }
    for (final pt in points) {
      if (seen.length >= max) return;
      final label = await _labelAt(pt[0], pt[1]);
      if (label != null && seen.add(label)) yield label;
    }
  }

  /// Places that match [query].
  static Future<List<String>> search(String query) async {
    final out = <String>[];
    try {
      final hits = await locationFromAddress(query);
      for (final h in hits.take(4)) {
        final l = await _labelAt(h.latitude, h.longitude);
        if (l != null && !out.contains(l)) out.add(l);
      }
    } catch (_) {
      // No match: the caller still offers the typed text.
    }
    return out;
  }
}
