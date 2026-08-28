import 'package:flutter/foundation.dart';

const String _envBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');

String get apiBaseUrl {
  if (_envBaseUrl.isNotEmpty) return _envBaseUrl;
  if (kIsWeb) return 'http://localhost:5000/api';
  if (defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.2.2:5000/api';
  return 'http://localhost:5000/api';
}

const String conferenceName = 'MAPCON 2026';
const String conferenceShort = 'MAPCON 2026';
const String defaultBanner = 'assets/images/banner.jpg';
const String defaultMapUrl = 'https://www.google.com/maps/search/?api=1&query=Hotel+Sayaji+Kolhapur';
