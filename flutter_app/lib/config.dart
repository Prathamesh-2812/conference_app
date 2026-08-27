import 'package:flutter/foundation.dart';

const String _envBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');

String get apiBaseUrl {
  if (_envBaseUrl.isNotEmpty) return _envBaseUrl;
  if (kIsWeb) return 'http://localhost:5000/api';
  if (defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.2.2:5000/api';
  return 'http://localhost:5000/api';
}

const String conferenceName = '100th DPU AIU VC Conference 2026';
const String conferenceShort = '100th DPU AIU VC Conference';
const String defaultBanner = 'https://images.unsplash.com/photo-1540575467063-178a50c2df87?w=1600';
const String defaultMapUrl = 'https://www.google.com/maps/search/?api=1&query=Dr.+D.+Y.+Patil+Vidyapeeth+Pimpri+Pune';
