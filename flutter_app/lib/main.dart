import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'dart:async';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'config.dart';
import 'services/api_service.dart';
import 'services/webcam_service.dart';
import 'services/qr_scanner_service.dart';
import 'services/realtime_service.dart';

const Color maroon = Color(0xFF8C1119);
const Color cream = Color(0xFFFCFAF5);
const Color gold = Color(0xFFC8A45A);
const Color darkMaroon = Color(0xFF5B0A0F);
const Color muted = Color(0xFF64748B);
const Color slate = Color(0xFF1E293B);

void main() => runApp(const ConferenceApp());

// Helper Date & Time Formatters
String formatSessionDate(dynamic rawDate) {
  if (rawDate == null) return '';
  final str = rawDate.toString().trim();
  if (str.isEmpty) return '';
  try {
    DateTime? dt;
    if (str.contains('T') || str.endsWith('Z')) {
      dt = DateTime.tryParse(str)?.toLocal();
    } else {
      dt = DateTime.tryParse(str);
    }
    if (dt != null) {
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final weekday = weekdays[dt.weekday - 1];
      final month = months[dt.month - 1];
      return '$weekday, ${dt.day} $month ${dt.year}';
    }
  } catch (_) {}
  return str;
}

String formatShortDate(dynamic rawDate) {
  if (rawDate == null) return '';
  final str = rawDate.toString().trim();
  if (str.isEmpty) return '';
  try {
    DateTime? dt;
    if (str.contains('T') || str.endsWith('Z')) {
      dt = DateTime.tryParse(str)?.toLocal();
    } else {
      dt = DateTime.tryParse(str);
    }
    if (dt != null) {
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${dt.day} ${months[dt.month - 1]}';
    }
  } catch (_) {}
  return str;
}

String formatSingleTime(dynamic t) {
  if (t == null) return '';
  final s = t.toString().trim();
  if (s.isEmpty) return '';
  if (s.toLowerCase().contains('am') || s.toLowerCase().contains('pm')) return s;
  final parts = s.split(':');
  if (parts.isNotEmpty) {
    final hour = int.tryParse(parts[0]);
    if (hour != null) {
      final minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
      final ampm = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
      final displayMin = minute.toString().padLeft(2, '0');
      return '$displayHour:$displayMin $ampm';
    }
  }
  return s;
}

String formatTimeRange(dynamic startTime, dynamic endTime) {
  final sFormatted = formatSingleTime(startTime);
  final eFormatted = formatSingleTime(endTime);
  if (sFormatted.isNotEmpty && eFormatted.isNotEmpty) {
    return '$sFormatted – $eFormatted';
  } else if (sFormatted.isNotEmpty) {
    return sFormatted;
  }
  return '';
}

String resolveSpeakerPhoto(dynamic rawPhoto) {
  if (rawPhoto == null || rawPhoto.toString().isEmpty) {
    return 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=500';
  }
  final str = rawPhoto.toString();
  if (str.startsWith('http://') || str.startsWith('https://')) {
    return str;
  }
  final base = apiBaseUrl.replaceAll(RegExp(r'/api/?$'), '');
  return '$base${str.startsWith('/') ? '' : '/'}$str';
}

String resolveMediaUrl(dynamic rawUrl, [String defaultFallback = '']) {
  if (rawUrl == null) return defaultFallback;
  final str = rawUrl.toString().trim();
  if (str.isEmpty) return defaultFallback;
  if (str.startsWith('http://') || str.startsWith('https://') || str.startsWith('data:')) {
    return str;
  }
  final base = apiBaseUrl.replaceAll(RegExp(r'/api/?$'), '');
  return '$base${str.startsWith('/') ? '' : '/'}$str';
}

String formatErrorMessage(dynamic error, [String defaultMessage = 'An unexpected error occurred. Please try again.']) {
  if (error == null) return defaultMessage;
  String msg = error.toString().trim();
  while (msg.startsWith('Exception:')) {
    msg = msg.substring('Exception:'.length).trim();
  }
  while (msg.startsWith('Error:')) {
    msg = msg.substring('Error:'.length).trim();
  }
  if (msg.toLowerCase().contains('clientexception') || 
      msg.toLowerCase().contains('failed to fetch') || 
      msg.toLowerCase().contains('socketexception') ||
      msg.toLowerCase().contains('networkerror') ||
      msg.toLowerCase().contains('connection refused')) {
    return 'Unable to reach the server. Please check your internet connection.';
  }
  if (msg.toLowerCase().contains('login failed (404)') || 
      msg.toLowerCase().contains('login failed') ||
      msg.toLowerCase().contains('invalid credentials') ||
      msg.toLowerCase().contains('user not found') ||
      msg.toLowerCase().contains('invalid email')) {
    return 'Invalid email or password. Please check your credentials and try again.';
  }
  if (msg.isEmpty) return defaultMessage;
  return msg;
}

// App Shell for Desktop/Web Responsive Layout
class AppShell extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const AppShell({
    super.key,
    required this.child,
    this.maxWidth = 720,
  });

  @override
  Widget build(BuildContext context) {
    final content = Material(
      color: Colors.white,
      child: child,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > maxWidth) {
          return Container(
            color: const Color(0xFFE2E8F0),
            child: Center(
              child: SizedBox(
                width: maxWidth,
                height: constraints.maxHeight,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 28,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRect(child: content),
                ),
              ),
            ),
          );
        }
        return content;
      },
    );
  }
}

class ConferenceInfo {
  final String name;
  final String shortName;
  final String welcomeMessage;
  final String description;
  final String aboutConference;
  final String venueName;
  final String venueAddress;
  final String venueCity;
  final String venueState;
  final String venuePincode;
  final String parkingInfo;
  final String directions;
  final String venueContact;
  final String mapUrl;
  final String? bannerUrl;
  final String? logoUrl;
  final String? organizerLogoUrl;
  final String startDate;
  final String endDate;
  final String contactEmail;
  final String contactPhone;
  final Color primaryColor;
  final Color secondaryColor;
  final Color accentColor;
  final Color backgroundColor;
  final Map<String, bool> settings;

  const ConferenceInfo({
    required this.name,
    required this.shortName,
    required this.welcomeMessage,
    required this.description,
    required this.aboutConference,
    required this.venueName,
    required this.venueAddress,
    required this.venueCity,
    required this.venueState,
    required this.venuePincode,
    required this.parkingInfo,
    required this.directions,
    required this.venueContact,
    required this.mapUrl,
    required this.startDate,
    required this.endDate,
    required this.contactEmail,
    required this.contactPhone,
    required this.primaryColor,
    required this.secondaryColor,
    required this.accentColor,
    required this.backgroundColor,
    required this.settings,
    this.bannerUrl,
    this.logoUrl,
    this.organizerLogoUrl,
  });

  factory ConferenceInfo.fallback() => const ConferenceInfo(
        name: conferenceName,
        shortName: conferenceShort,
        welcomeMessage: 'Welcome to MAPCON 2026',
        description: '47th Annual Conference of Maharashtra Chapter (MAPCON 2026)',
        aboutConference: 'A Greener Conference for a Healthier Tomorrow. Connect | Collaborate | Create Impact. Initiative by D.Y. Patil Education Society, Deemed to be University, Kolhapur.',
        venueName: 'Hotel Sayaji, Kolhapur',
        venueAddress: 'Old Pune-Bangalore Highway, Kawala Naka, Kolhapur',
        venueCity: 'Kolhapur',
        venueState: 'Maharashtra',
        venuePincode: '416001',
        parkingInfo: 'Dedicated valet and delegate parking available at Hotel Sayaji premises.',
        directions: 'Located at Kawala Naka on Old Pune-Bangalore Highway, Kolhapur. 5 mins from CBS, 10 mins from Railway Station, 15 mins from Kolhapur Airport (KLH).',
        venueContact: '0231 2555555',
        mapUrl: defaultMapUrl,
        startDate: '2026-10-02',
        endDate: '2026-10-04',
        contactEmail: 'admin@mapcon2026.org',
        contactPhone: '0231 2555555',
        primaryColor: maroon,
        secondaryColor: gold,
        accentColor: Color(0xFF2E6F95),
        backgroundColor: cream,
        settings: {},
        bannerUrl: defaultBanner,
      );

  static Color _parseColor(String? hex, Color fallback) {
    if (hex == null || !hex.startsWith('#')) return fallback;
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return fallback;
    }
  }

  factory ConferenceInfo.fromJson(Map<String, dynamic> json) {
    final venue = json['venue'] is Map ? json['venue'] as Map : {};
    final branding = json['branding'] is Map ? json['branding'] as Map : {};
    final settingsMap = json['settings'] is Map ? json['settings'] as Map : {};

    return ConferenceInfo(
      name: '${json['name'] ?? conferenceName}',
      shortName: '${json['shortName'] ?? conferenceShort}',
      welcomeMessage: '${json['welcomeMessage'] ?? 'Welcome to the Conference'}',
      description: '${json['description'] ?? ''}',
      aboutConference: '${json['aboutConference'] ?? ''}',
      venueName: '${venue['name'] ?? 'Dr. D.Y. Patil Vidyapeeth Campus'}',
      venueAddress: '${venue['address'] ?? 'Kasaba Bawada, Kolhapur'}',
      venueCity: '${venue['city'] ?? 'Kolhapur'}',
      venueState: '${venue['state'] ?? 'Maharashtra'}',
      venuePincode: '${venue['pincode'] ?? '416013'}',
      parkingInfo: '${venue['parkingInformation'] ?? 'Dedicated VIP & Delegate parking available near Gate No. 2 with valet assistance.'}',
      directions: '${venue['directions'] ?? 'Use the main Bawada campus entrance and follow conference signage.'}',
      venueContact: '${venue['contactNumber'] ?? '1800123456'}',
      mapUrl: (venue['googleMapsUrl'] != null && venue['googleMapsUrl'].toString().trim().isNotEmpty)
          ? venue['googleMapsUrl'].toString().trim()
          : defaultMapUrl,
      startDate: '${json['startDate'] ?? ''}',
      endDate: '${json['endDate'] ?? ''}',
      contactEmail: '${json['contactEmail'] ?? ''}',
      contactPhone: '${json['contactPhone'] ?? ''}',
      primaryColor: _parseColor(branding['primaryColor'], maroon),
      secondaryColor: _parseColor(branding['secondaryColor'], gold),
      accentColor: _parseColor(branding['accentColor'], const Color(0xFF2E6F95)),
      backgroundColor: _parseColor(branding['backgroundColor'], cream),
      settings: settingsMap.map((k, v) => MapEntry(k.toString(), v == true)),
      bannerUrl: branding['bannerUrl']?.toString(),
      logoUrl: branding['logoUrl']?.toString(),
      organizerLogoUrl: branding['organizerLogoUrl']?.toString(),
    );
  }
}

class ConferenceScope extends InheritedWidget {
  final ConferenceInfo info;

  const ConferenceScope({
    super.key,
    required this.info,
    required super.child,
  });

  static ConferenceInfo of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ConferenceScope>()?.info ?? ConferenceInfo.fallback();
  }

  @override
  bool updateShouldNotify(ConferenceScope oldWidget) => info != oldWidget.info;
}

class ConferenceApp extends StatefulWidget {
  const ConferenceApp({super.key});
  @override
  State<ConferenceApp> createState() => _ConferenceAppState();
}

class _ConferenceAppState extends State<ConferenceApp> with WidgetsBindingObserver {
  ConferenceInfo info = ConferenceInfo.fallback();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    RealtimeSyncService.instance.init();
    RealtimeSyncService.instance.syncNotifier.addListener(_loadConference);
    _loadConference();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      RealtimeSyncService.instance.triggerSync();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    RealtimeSyncService.instance.syncNotifier.removeListener(_loadConference);
    super.dispose();
  }

  Future<void> _loadConference() async {
    try {
      final data = await ApiService.conference();
      if (mounted) setState(() => info = ConferenceInfo.fromJson(data));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return ConferenceScope(
      info: info,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'DYPESCONF',
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: info.backgroundColor,
          colorScheme: ColorScheme.fromSeed(
            seedColor: info.primaryColor,
            primary: info.primaryColor,
            secondary: info.secondaryColor,
            surface: Colors.white,
          ),
          cardTheme: CardThemeData(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade200, width: 1),
            ),
          ),
          fontFamily: 'Roboto',
        ),
        home: const AuthGate(),
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool loading = true, logged = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final p = await SharedPreferences.getInstance();
    final token = p.getString('token');
    if (token == null || token.isEmpty) {
      if (mounted) setState(() { logged = false; loading = false; });
      return;
    }
    try {
      final res = await ApiService.get('/auth/me');
      if (res != null && res is Map && res['id'] != null) {
        await ConferenceService.refreshEnrolledConferences();
        if (mounted) setState(() { logged = true; loading = false; });
        return;
      }
    } catch (_) {
      await p.remove('token');
      await p.remove('name');
    }
    if (mounted) setState(() { logged = false; loading = false; });
  }

  @override
  Widget build(BuildContext c) => loading
      ? const Scaffold(body: Center(child: CircularProgressIndicator(color: maroon)))
      : logged
          ? const MainShell()
          : LoginScreen(onLogin: () => setState(() => logged = true));
}

class LoginScreen extends StatefulWidget {
  final VoidCallback onLogin;
  const LoginScreen({super.key, required this.onLogin});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final e = TextEditingController();
  final p = TextEditingController();
  bool busy = false, obscure = true;

  Future<void> login() async {
    setState(() => busy = true);
    try {
      final r = await ApiService.login(e.text.trim(), p.text);
      final sp = await SharedPreferences.getInstance();
      await sp.setString('token', r['token']);
      await sp.setString('name', r['user']['name']);

      final bool mustChange = r['user']?['mustChangePassword'] == true;
      if (mustChange && mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => const ForcedPasswordChangeDialog(),
        );
      }

      widget.onLogin();
    } catch (x) {
      if (mounted) {
        final cleanMsg = formatErrorMessage(x, 'Invalid email or password. Please try again.');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    cleanMsg,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext c) {
    final conference = ConferenceScope.of(c);
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              elevation: 4,
              shadowColor: Colors.black.withOpacity(0.08),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 96,
                        height: 96,
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/logo.png',
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.high,
                            errorBuilder: (_, __, ___) => Icon(
                              Icons.school,
                              size: 50,
                              color: conference.primaryColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'DYPESCONF',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        color: maroon,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'D. Y. Patil Education Society\nConference & Delegate Portal',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: muted,
                        fontSize: 13,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 28),
                    AutofillGroup(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: e,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autocorrect: false,
                            enableSuggestions: false,
                            autofillHints: const [AutofillHints.email, AutofillHints.username],
                            decoration: InputDecoration(
                              labelText: 'Email Address',
                              hintText: 'Enter your email',
                              prefixIcon: Icon(Icons.email_outlined, color: conference.primaryColor),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: p,
                            obscureText: obscure,
                            textInputAction: TextInputAction.done,
                            autocorrect: false,
                            enableSuggestions: false,
                            autofillHints: const [AutofillHints.password],
                            onSubmitted: (_) => busy ? null : login(),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              hintText: 'Enter your password',
                              prefixIcon: Icon(Icons.lock_outline, color: conference.primaryColor),
                              suffixIcon: IconButton(
                                onPressed: () => setState(() => obscure = !obscure),
                                icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
                              ),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: conference.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: busy ? null : login,
                      child: busy
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            )
                          : const Text(
                              'Sign In to Conference',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ForcedPasswordChangeDialog extends StatefulWidget {
  final bool isForced;
  const ForcedPasswordChangeDialog({super.key, this.isForced = true});

  @override
  State<ForcedPasswordChangeDialog> createState() => _ForcedPasswordChangeDialogState();
}

class _ForcedPasswordChangeDialogState extends State<ForcedPasswordChangeDialog> {
  final newPassCtrl = TextEditingController();
  final confirmPassCtrl = TextEditingController();
  bool obscureNew = true;
  bool obscureConfirm = true;
  bool busy = false;
  String? errorMsg;

  @override
  void dispose() {
    newPassCtrl.dispose();
    confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> submitNewPassword() async {
    final newPass = newPassCtrl.text.trim();
    final confirmPass = confirmPassCtrl.text.trim();

    if (newPass.length < 4) {
      setState(() => errorMsg = 'Password must be at least 4 characters long');
      return;
    }
    if (newPass != confirmPass) {
      setState(() => errorMsg = 'Passwords do not match');
      return;
    }

    setState(() {
      busy = true;
      errorMsg = null;
    });

    try {
      await ApiService.post('/auth/change-password', {'newPassword': newPass});
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (err) {
      if (mounted) {
        setState(() {
          errorMsg = err.toString().replaceAll('Exception: ', '');
          busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => !widget.isForced,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.lock_reset, color: maroon, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.isForced ? 'Change Default Password' : 'Change Password',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: slate),
              ),
            ),
            if (!widget.isForced)
              IconButton(
                icon: const Icon(Icons.close, color: muted, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.isForced
                    ? 'Your account was initialized with a default password (mobile number). Please set your personal password before continuing.'
                    : 'Enter your new password below to update your account login credentials.',
                style: const TextStyle(fontSize: 13, color: muted),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: newPassCtrl,
                obscureText: obscureNew,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  prefixIcon: const Icon(Icons.lock_outline, color: maroon),
                  suffixIcon: IconButton(
                    icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility, color: muted),
                    onPressed: () => setState(() => obscureNew = !obscureNew),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmPassCtrl,
                obscureText: obscureConfirm,
                decoration: InputDecoration(
                  labelText: 'Confirm New Password',
                  prefixIcon: const Icon(Icons.lock_outline, color: maroon),
                  suffixIcon: IconButton(
                    icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility, color: muted),
                    onPressed: () => setState(() => obscureConfirm = !obscureConfirm),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              if (errorMsg != null) ...[
                const SizedBox(height: 10),
                Text(errorMsg!, style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ],
          ),
        ),
        actions: [
          if (!widget.isForced)
            TextButton(
              onPressed: busy ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: muted, fontWeight: FontWeight.w600)),
            ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: maroon,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: busy ? null : submitNewPassword,
            child: busy
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(widget.isForced ? 'Update & Continue' : 'Update Password', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ),
        ],
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int i = 0;

  @override
  void initState() {
    super.initState();
    RealtimeSyncService.instance.calculateUnreadCount();
    RealtimeSyncService.instance.lastNotificationNotifier.addListener(_onLiveNotification);
  }

  @override
  void dispose() {
    RealtimeSyncService.instance.lastNotificationNotifier.removeListener(_onLiveNotification);
    super.dispose();
  }

  void _onLiveNotification() {
    final notif = RealtimeSyncService.instance.lastNotificationNotifier.value;
    if (notif == null || !mounted) return;

    final title = notif['title']?.toString() ?? '📢 Event Notification';
    final message = notif['message']?.toString() ?? 'New event update from organizers';

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFDC2626), maroon]),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.red.withOpacity(0.4), blurRadius: 6, offset: const Offset(0, 2)),
                ],
              ),
              child: const Icon(Icons.notifications_active, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5, color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    message,
                    style: const TextStyle(fontSize: 12, color: Color(0xFFE2E8F0)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'VIEW',
          textColor: gold,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AppShell(
                  child: Scaffold(
                    backgroundColor: Colors.white,
                    body: NoticesScreen(),
                  ),
                ),
              ),
            );
            RealtimeSyncService.instance.markAllAsRead();
          },
        ),
        backgroundColor: const Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  @override
  Widget build(BuildContext c) {
    final conference = ConferenceScope.of(c);
    final bool enableSchedule = conference.settings['enableSchedule'] != false;
    final bool enableNotices = conference.settings['enableNotices'] != false;
    final bool enableChat = conference.settings['enableChat'] == true;
    final bool enableGallery = conference.settings['enableGallery'] != false;

    final List<Widget> pages = [
      const HomeScreen(),
      if (enableSchedule) const ScheduleScreen(),
      if (enableChat) const ChatScreen(),
      if (enableNotices) const NoticesScreen(),
      if (enableGallery) const GalleryScreen(),
      const ProfileScreen(),
    ];

    final List<NavigationDestination> destinations = [
      const NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home, color: maroon),
        label: 'Home',
      ),
      if (enableSchedule)
        const NavigationDestination(
          icon: Icon(Icons.calendar_month_outlined),
          selectedIcon: Icon(Icons.calendar_month, color: maroon),
          label: 'Schedule',
        ),
      if (enableChat)
        const NavigationDestination(
          icon: Icon(Icons.chat_bubble_outline),
          selectedIcon: Icon(Icons.chat_bubble, color: maroon),
          label: 'Chat',
        ),
      if (enableNotices)
        NavigationDestination(
          icon: ValueListenableBuilder<int>(
            valueListenable: RealtimeSyncService.instance.unreadNotifCountNotifier,
            builder: (context, unreadCount, child) {
              return Badge(
                isLabelVisible: unreadCount > 0,
                label: Text(
                  '$unreadCount',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10, color: Colors.white),
                ),
                backgroundColor: const Color(0xFFDC2626),
                child: const Icon(Icons.notifications_none),
              );
            },
          ),
          selectedIcon: ValueListenableBuilder<int>(
            valueListenable: RealtimeSyncService.instance.unreadNotifCountNotifier,
            builder: (context, unreadCount, child) {
              return Badge(
                isLabelVisible: unreadCount > 0,
                label: Text(
                  '$unreadCount',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10, color: Colors.white),
                ),
                backgroundColor: const Color(0xFFDC2626),
                child: const Icon(Icons.notifications, color: maroon),
              );
            },
          ),
          label: 'Notices',
        ),
      if (enableGallery)
        const NavigationDestination(
          icon: Icon(Icons.photo_library_outlined),
          selectedIcon: Icon(Icons.photo_library, color: maroon),
          label: 'Gallery',
        ),
      const NavigationDestination(
        icon: Icon(Icons.person_outline),
        selectedIcon: Icon(Icons.person, color: maroon),
        label: 'Profile',
      ),
    ];

    final int safeIndex = (i >= 0 && i < pages.length) ? i : 0;

    void onTabSelected(int idx) {
      if (idx >= 0 && idx < destinations.length) {
        if (destinations[idx].label == 'Notices') {
          RealtimeSyncService.instance.markAllAsRead();
        }
      }
      setState(() => i = idx);
    }

    return AppShell(
      child: Scaffold(
        backgroundColor: Colors.white,
        body: IndexedStack(
          index: safeIndex,
          children: pages,
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: safeIndex,
          backgroundColor: Colors.white,
          indicatorColor: conference.primaryColor.withOpacity(0.14),
          elevation: 6,
          onDestinationSelected: onTabSelected,
          destinations: destinations,
        ),
      ),
    );
  }
}

class Header extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const Header({
    super.key,
    this.title = 'Home',
    this.trailing,
  });

  Future<void> _showConferencePickerModal(BuildContext context) async {
    if (ConferenceService.enrolledConferences.isEmpty) {
      await ConferenceService.refreshEnrolledConferences();
    }

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final enrolled = ConferenceService.enrolledConferences;
        final activeId = ConferenceService.activeConferenceId;

        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: maroon.withOpacity(0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.business_center, color: maroon, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Your Registered Conferences', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: slate)),
                        Text('Select a conference to view its schedule & data', style: TextStyle(fontSize: 12, color: muted)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (enrolled.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  alignment: Alignment.center,
                  child: const Text('No registered conferences found for your account.', style: TextStyle(color: muted)),
                )
              else
                ...enrolled.map((item) {
                  final confId = item['id'] is int ? item['id'] : (int.tryParse(item['id'].toString()) ?? 1);
                  final isSelected = confId == activeId;
                  final name = item['name'] ?? item['short_name'] ?? 'Conference #$confId';
                  final regNo = item['registration_no'] ?? '';
                  final category = item['category'] ?? 'Participant';

                  return Card(
                    elevation: isSelected ? 2 : 0,
                    color: isSelected ? maroon.withOpacity(0.06) : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: isSelected ? maroon : Colors.grey.shade200, width: isSelected ? 1.5 : 1),
                    ),
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      title: Text(name, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? maroon : slate)),
                      subtitle: Text(regNo.isNotEmpty ? 'Reg: $regNo • $category' : category, style: const TextStyle(fontSize: 12, color: muted)),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle, color: maroon)
                          : const Icon(Icons.arrow_forward_ios, size: 14, color: muted),
                      onTap: () async {
                        Navigator.pop(ctx);
                        await ConferenceService.switchConference(confId);
                        RealtimeSyncService.instance.triggerSync();
                      },
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext c) {
    final conference = ConferenceScope.of(c);
    final topInset = MediaQuery.of(c).padding.top;
    final enrolledCount = ConferenceService.enrolledConferences.length;

    return Container(
      padding: EdgeInsets.fromLTRB(16, topInset + 8, 16, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [conference.primaryColor, const Color(0xFF4A0E17)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          if (Navigator.canPop(c))
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => Navigator.maybePop(c),
              ),
            ),
          Container(
            width: 42,
            height: 42,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/images/logo.png',
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.school,
                  color: conference.primaryColor,
                  size: 24,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        conference.shortName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFF1F5F9),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => _showConferencePickerModal(c),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white38, width: 0.6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.swap_horiz, color: Colors.white, size: 10),
                            const SizedBox(width: 3),
                            Text(
                              enrolledCount > 1 ? 'Switch ($enrolledCount)' : 'Switch',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (trailing != null)
            trailing!
          else
            ValueListenableBuilder<int>(
              valueListenable: RealtimeSyncService.instance.unreadNotifCountNotifier,
              builder: (context, unreadCount, _) {
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white30, width: 0.8),
                  ),
                  child: IconButton(
                    icon: Badge.count(
                      count: unreadCount,
                      isLabelVisible: unreadCount > 0,
                      backgroundColor: const Color(0xFFEF4444),
                      textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white),
                      child: const Icon(Icons.notifications_outlined, color: Colors.white, size: 22),
                    ),
                    tooltip: 'Notices & Live Alerts',
                    onPressed: () {
                      if (title == 'Notices & Announcements') {
                        RealtimeSyncService.instance.markAllAsRead();
                      } else {
                        Navigator.push(
                          c,
                          MaterialPageRoute(
                            builder: (_) => const AppShell(
                              child: Scaffold(
                                backgroundColor: Colors.white,
                                body: NoticesScreen(),
                              ),
                            ),
                          ),
                        );
                      }
                    },
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class CardButton extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  final Widget? trailingBadge;
  final Color? iconColor;
  final Color? iconBgColor;

  const CardButton({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailingBadge,
    this.iconColor,
    this.iconBgColor,
  });

  @override
  Widget build(BuildContext c) {
    final conference = ConferenceScope.of(c);
    final effectiveColor = iconColor ?? conference.primaryColor;
    final effectiveBg = iconBgColor ?? conference.primaryColor.withOpacity(0.08);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: effectiveBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Icon(icon, color: effectiveColor, size: 24),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: slate,
                            ),
                          ),
                        ),
                        if (trailingBadge != null) trailingBadge!,
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(color: muted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF94A3B8)),
            ],
          ),
        ),
      ),
    );
  }
}
class MainMediaSlider extends StatefulWidget {
  const MainMediaSlider({super.key});

  @override
  State<MainMediaSlider> createState() => _MainMediaSliderState();
}

class _MainMediaSliderState extends State<MainMediaSlider> {
  List<dynamic> _slides = [];
  bool _loading = true;
  int _currentIndex = 0;
  final PageController _pageController = PageController();
  Timer? _autoPlayTimer;

  static final List<Map<String, dynamic>> _defaultShowcaseSlides = [
    {
      'title': 'D. Y. Patil Education Society (Deemed to be University) • Kolhapur Campus',
      'media_type': 'IMAGE',
      'media_url': 'https://images.unsplash.com/photo-1541339907198-e08756dedf3f?w=1200&auto=format&fit=crop&q=80',
      'badge': 'UNIVERSITY HIGHLIGHT',
      'icon': Icons.school,
    },
    {
      'title': 'MAPCON 2026 • 46th Annual State Conference at Hotel Sayaji, Kolhapur',
      'media_type': 'IMAGE',
      'media_url': 'https://images.unsplash.com/photo-1511578314322-379afb476865?w=1200&auto=format&fit=crop&q=80',
      'badge': 'CONFERENCE BANNER',
      'icon': Icons.event,
    },
    {
      'title': 'University Campus Tour & Institutional Excellence Clip',
      'media_type': 'VIDEO',
      'media_url': 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
      'badge': 'UNIVERSITY VIDEO',
      'icon': Icons.play_circle_fill,
    },
    {
      'title': 'Our Esteemed Industrial Partners, Diagnostic Leaders & Sponsors',
      'media_type': 'IMAGE',
      'media_url': 'https://images.unsplash.com/photo-1587825140708-dfaf72ae4b04?w=1200&auto=format&fit=crop&q=80',
      'badge': 'OFFICIAL SPONSORS',
      'icon': Icons.handshake,
    },
  ];

  @override
  void initState() {
    super.initState();
    RealtimeSyncService.instance.syncNotifier.addListener(_fetchSliders);
    _fetchSliders();
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    RealtimeSyncService.instance.syncNotifier.removeListener(_fetchSliders);
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoPlay(int count) {
    _autoPlayTimer?.cancel();
    if (count <= 1) return;
    _autoPlayTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (_pageController.hasClients) {
        final next = (_currentIndex + 1) % count;
        _pageController.animateToPage(
          next,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Future<void> _fetchSliders() async {
    try {
      final res = await ApiService.get('/sliders');
      if (res is List && res.isNotEmpty) {
        if (mounted) {
          setState(() {
            _slides = res;
            _loading = false;
          });
          _startAutoPlay(res.length);
        }
      } else {
        if (mounted) {
          setState(() {
            _slides = _defaultShowcaseSlides;
            _loading = false;
          });
          _startAutoPlay(_defaultShowcaseSlides.length);
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _slides = _defaultShowcaseSlides;
          _loading = false;
        });
        _startAutoPlay(_defaultShowcaseSlides.length);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final slidesList = _slides.isNotEmpty ? _slides : _defaultShowcaseSlides;
    final String imageBaseUrl = apiBaseUrl.replaceAll('/api', '');

    return Column(
      children: [
        SizedBox(
          height: 195,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (idx) => setState(() => _currentIndex = idx),
            itemCount: slidesList.length,
            itemBuilder: (context, index) {
              final item = slidesList[index];
              final String mediaType = item['media_type']?.toString().toUpperCase() ?? 'IMAGE';
              final String rawUrl = item['media_url']?.toString() ?? '';
              final String title = item['title']?.toString() ?? '';

              String badgeText = item['badge']?.toString() ?? '';
              IconData badgeIcon = Icons.campaign;

              if (mediaType == 'VIDEO') {
                badgeText = 'UNIVERSITY VIDEO';
                badgeIcon = Icons.videocam;
              } else if (title.toLowerCase().contains('sponsor') || title.toLowerCase().contains('partner')) {
                badgeText = 'OFFICIAL SPONSORS';
                badgeIcon = Icons.handshake;
              } else if (title.toLowerCase().contains('campus') || title.toLowerCase().contains('patil') || title.toLowerCase().contains('university')) {
                badgeText = 'UNIVERSITY HIGHLIGHT';
                badgeIcon = Icons.school;
              } else {
                badgeText = 'CONFERENCE BANNER';
                badgeIcon = Icons.event;
              }

              final String fullUrl = (rawUrl.startsWith('http://') || rawUrl.startsWith('https://'))
                  ? rawUrl
                  : '$imageBaseUrl${rawUrl.startsWith('/') ? '' : '/'}$rawUrl';

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: const Color(0xFF0F172A),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (mediaType == 'VIDEO') ...[
                      Container(
                        color: const Color(0xFF0F172A),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(colors: [maroon, Color(0xFFA91D22)]),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: maroon.withOpacity(0.4),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.play_arrow, color: Colors.white, size: 38),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Tap to Play Video Clip',
                                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () async {
                          final uri = Uri.parse(fullUrl);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        },
                      ),
                    ] else ...[
                      Image.network(
                        fullUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: const Color(0xFF1E293B),
                          child: const Center(
                            child: Icon(Icons.image_outlined, color: Colors.white54, size: 40),
                          ),
                        ),
                      ),
                    ],

                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                        decoration: BoxDecoration(
                          color: mediaType == 'VIDEO' ? const Color(0xFFDC2626) : maroon.withOpacity(0.92),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.3), width: 0.8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(badgeIcon, color: gold, size: 12),
                            const SizedBox(width: 5),
                            Text(
                              badgeText,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    if (title.isNotEmpty)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(14, 24, 14, 12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.transparent, Colors.black.withOpacity(0.88)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                          child: Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 13.5,
                              height: 1.25,
                              shadows: [
                                Shadow(color: Colors.black, blurRadius: 4),
                              ],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(slidesList.length, (idx) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: _currentIndex == idx ? 20 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: _currentIndex == idx ? maroon : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        ),
        const SizedBox(height: 14),
      ],
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _userProfile;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    RealtimeSyncService.instance.syncNotifier.addListener(_loadUserProfile);
  }

  @override
  void dispose() {
    RealtimeSyncService.instance.syncNotifier.removeListener(_loadUserProfile);
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    try {
      final res = await ApiService.get('/me/profile');
      if (res is Map && mounted) {
        final profileData = res['data'] is Map
            ? Map<String, dynamic>.from(res['data'] as Map)
            : Map<String, dynamic>.from(res);
        setState(() {
          _userProfile = profileData;
        });
      }
    } catch (_) {}
  }

  bool get _isHybridUser {
    if (_userProfile == null) return false;
    final category = (_userProfile?['category'] ?? '').toString().toLowerCase();
    final role = (_userProfile?['role'] ?? '').toString().toUpperCase();
    final modeOfTravel = (_userProfile?['mode_of_travel'] ?? '').toString().toLowerCase();

    // Admins and organizers can always view
    if (role == 'ADMIN' || role == 'ORGANIZER' || role == 'SUPERADMIN') return true;

    // Check if user is registered for Online / Hybrid mode
    if (category.contains('online') || category.contains('hybrid') || category.contains('virtual') || category.contains('remote')) {
      return true;
    }
    if (modeOfTravel.contains('online') || modeOfTravel.contains('hybrid') || modeOfTravel.contains('virtual') || modeOfTravel.contains('remote')) {
      return true;
    }
    if (role == 'ONLINE' || role == 'HYBRID') return true;

    return false;
  }

  void go(BuildContext context, Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AppShell(child: page),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final conference = ConferenceScope.of(context);

    return SafeArea(
      top: false,
      child: RefreshIndicator(
        color: maroon,
        onRefresh: () async {
          RealtimeSyncService.instance.triggerSync();
          await _loadUserProfile();
          await Future.delayed(const Duration(milliseconds: 600));
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Header(title: 'Overview'),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 90),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (conference.settings['enableSlider'] != false)
                    const MainMediaSlider(),
                  // Welcome Banner Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          conference.primaryColor.withOpacity(0.06),
                          const Color(0xFFFDFBF7),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: gold.withOpacity(0.3), width: 1.2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: conference.primaryColor,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'OFFICIAL CONVOCATION & MEET',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          conference.welcomeMessage,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: conference.primaryColor,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          conference.description,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: slate,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),

                  // Section Title
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'ESSENTIAL SERVICES',
                        style: TextStyle(
                          letterSpacing: 1.2,
                          color: muted,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Tap to explore',
                          style: TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (conference.settings['enableHybridStage'] != false)
                    CardButton(
                      icon: Icons.videocam_rounded,
                      iconColor: const Color(0xFF2563EB),
                      iconBgColor: const Color(0xFF2563EB).withOpacity(0.12),
                      title: 'Hybrid & Online Stage (Zoom)',
                      subtitle: 'Live video stream, Zoom webinars & sessions',
                      trailingBadge: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.6)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.fiber_manual_record, size: 8, color: Color(0xFF2563EB)),
                            SizedBox(width: 4),
                            Text(
                              'ZOOM LIVE',
                              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: Color(0xFF1E40AF)),
                            ),
                          ],
                        ),
                      ),
                      onTap: () => go(context, const VirtualStageScreen()),
                    ),
                  if (conference.settings['enableSchedule'] != false)
                    CardButton(
                      icon: Icons.calendar_month,
                      title: 'Event Schedule',
                      subtitle: 'Day-wise timeline, tracks & halls',
                      onTap: () => go(context, const ScheduleScreen()),
                    ),
                  if (conference.settings['enableSpeakers'] != false)
                    CardButton(
                      icon: Icons.groups,
                      title: 'Conference Speakers',
                      subtitle: 'Distinguished dignitaries & profiles',
                      onTap: () => go(context, const SpeakersScreen()),
                    ),
                  if (conference.settings['enableGallery'] != false)
                    CardButton(
                      icon: Icons.photo_library_rounded,
                      title: 'Photo Gallery',
                      subtitle: 'View conference photos & event moments',
                      onTap: () => go(context, const GalleryScreen()),
                    ),
                  if (conference.settings['enableVenueDirections'] != false)
                    CardButton(
                      icon: Icons.location_on,
                      title: 'Directions & Venue',
                      subtitle: 'Campus map, how to reach & hall guide',
                      onTap: () => go(context, const VenueDirectionsScreen()),
                    ),
                  if (conference.settings['enableAccommodation'] == true)
                    CardButton(
                      icon: Icons.hotel,
                      title: 'My Accommodation',
                      subtitle: 'Hotel, room allotment & check-in details',
                      onTap: () => go(context, const AccommodationScreen()),
                    ),
                  if (conference.settings['enableTransport'] == true)
                    CardButton(
                      icon: Icons.directions_car,
                      title: 'Transport & Cab',
                      subtitle: 'Pickup timing, vehicle & driver contact',
                      onTap: () => go(context, const TransportScreen()),
                    ),
                  if (conference.settings['enableDuties'] == true)
                    CardButton(
                      icon: Icons.assignment,
                      title: 'Duty Roster',
                      subtitle: 'Assigned committee & conference tasks',
                      onTap: () => go(context, const DutiesScreen()),
                    ),
                  if (conference.settings['enableQr'] == true)
                    CardButton(
                      icon: Icons.qr_code_2,
                      title: 'Digital Conference ID',
                      subtitle: 'QR badge for entry & session check-in',
                      onTap: () => go(context, const DigitalIdScreen()),
                    ),
                  if (conference.settings['enableCertificates'] != false)
                    CardButton(
                      icon: Icons.workspace_premium,
                      title: 'Certificate of Participation',
                      subtitle: 'View & download certified credentials',
                      onTap: () => go(context, const CertificateScreen()),
                    ),
                  if (conference.settings['enableTravelGuide'] != false)
                    CardButton(
                      icon: Icons.explore_rounded,
                      title: 'Travel & Nearest Tourist Places',
                      subtitle: 'Temples, forts, Kolhapuri food, lassi & local transit',
                      trailingBadge: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: gold.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: gold.withOpacity(0.6)),
                        ),
                        child: const Text(
                          'KOLHAPUR',
                          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: darkMaroon),
                        ),
                      ),
                      onTap: () => go(context, const TravelGuideScreen()),
                    ),
                  if (conference.settings['enableEmergency'] != false)
                    CardButton(
                      icon: Icons.emergency,
                      title: 'Emergency Help & Contacts',
                      subtitle: 'Help desk, medical unit & security',
                      onTap: () => go(context, const EmergencyScreen()),
                    ),
                  if (conference.settings['enableSponsors'] != false)
                    CardButton(
                      icon: Icons.handshake_rounded,
                      title: 'Our Sponsors & Partners',
                      subtitle: 'Industry leaders, diagnostic partners & stall directory',
                      trailingBadge: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: gold.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: gold.withOpacity(0.6)),
                        ),
                        child: const Text(
                          'EXHIBITION',
                          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: darkMaroon),
                        ),
                      ),
                      onTap: () => go(context, const SponsorsScreen()),
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
}

// ----------------------------------------------------
// OUR SPONSORS & PARTNERS HOME SECTION & SCREEN
// ----------------------------------------------------

const List<Map<String, dynamic>> defaultSponsors = [
  {
    'name': 'Roche Diagnostics',
    'tier': 'PLATINUM',
    'category': 'Title & Molecular Diagnostic Partner',
    'logo_url': 'https://images.unsplash.com/photo-1584308666744-24d5c474f2ae?w=400',
    'website_url': 'https://diagnostics.roche.com',
    'description': 'Global leader in in-vitro diagnostics and tissue-based cancer diagnostics.',
    'booth_number': 'Stall P-01 (Grand Dome)',
    'contact_email': 'support.india@roche.com',
    'contact_phone': '+91 22 6697 4900',
  },
  {
    'name': 'Siemens Healthineers',
    'tier': 'PLATINUM',
    'category': 'Diamond Diagnostic Imaging Partner',
    'logo_url': 'https://images.unsplash.com/photo-1516549655169-df83a0774514?w=400',
    'website_url': 'https://www.siemens-healthineers.com',
    'description': 'Pioneering breakthroughs in digital pathology, point-of-care and laboratory automation.',
    'booth_number': 'Stall P-02 (Grand Dome)',
    'contact_email': 'contact@siemens-healthineers.in',
    'contact_phone': '+91 22 3967 7000',
  },
  {
    'name': 'Sysmex India',
    'tier': 'GOLD',
    'category': 'Automated Hematology Partner',
    'logo_url': 'https://images.unsplash.com/photo-1579165466791-788226ab77b6?w=400',
    'website_url': 'https://www.sysmex.co.in',
    'description': 'Delivering high-precision hematology and flow cytometry diagnostic equipment across the globe.',
    'booth_number': 'Stall G-05 (Exhibition Hall A)',
    'contact_email': 'info@sysmex.co.in',
    'contact_phone': '+91 22 6112 0700',
  },
  {
    'name': 'Beckman Coulter',
    'tier': 'GOLD',
    'category': 'Clinical Diagnostics Partner',
    'logo_url': 'https://images.unsplash.com/photo-1532187863486-abf9dbad1b69?w=400',
    'website_url': 'https://www.beckmancoulter.com',
    'description': 'Advancing healthcare for every person with integrated immunoassay and biomedical analysis solutions.',
    'booth_number': 'Stall G-08 (Exhibition Hall A)',
    'contact_email': 'india.sales@beckman.com',
    'contact_phone': '+91 80 6701 5000',
  },
  {
    'name': 'Leica Biosystems',
    'tier': 'SILVER',
    'category': 'Histopathology & Slide Scanning Partner',
    'logo_url': 'https://images.unsplash.com/photo-1582719508461-905c673771fd?w=400',
    'website_url': 'https://www.leicabiosystems.com',
    'description': 'End-to-end workflow solutions from biopsy to diagnosis in anatomical pathology.',
    'booth_number': 'Stall S-12 (Hall B)',
    'contact_email': 'apac.support@leicabiosystems.com',
    'contact_phone': '+91 22 4192 3000',
  },
  {
    'name': 'Mindray Medical',
    'tier': 'SILVER',
    'category': 'Bio-Medical & Lab Solutions',
    'logo_url': 'https://images.unsplash.com/photo-1530497610245-94d3c16cda28?w=400',
    'website_url': 'https://www.mindray.com',
    'description': 'Innovative laboratory solutions and automated biochemistry analyzers.',
    'booth_number': 'Stall S-14 (Hall B)',
    'contact_email': 'service.in@mindray.com',
    'contact_phone': '+91 124 480 3000',
  },
  {
    'name': 'D.Y. Patil Education Society',
    'tier': 'PARTNER',
    'category': 'Academic & Knowledge Partner',
    'logo_url': 'https://images.unsplash.com/photo-1562774053-701939374585?w=400',
    'website_url': 'https://dypatilunikop.org',
    'description': 'Deemed to be University, Kolhapur. Promoting research excellence and medical education.',
    'booth_number': 'Stall AC-01 (Foyer)',
    'contact_email': 'info@dypatilunikop.org',
    'contact_phone': '+91 231 260 1235',
  },
  {
    'name': 'Sayaji Hotels Kolhapur',
    'tier': 'PARTNER',
    'category': 'Official Hospitality Partner',
    'logo_url': 'https://images.unsplash.com/photo-1566073771259-6a8506099945?w=400',
    'website_url': 'https://sayajihotels.com',
    'description': 'Luxury accommodation and 5-star venue host for MAPCON 2026.',
    'booth_number': 'Front Helpdesk',
    'contact_email': 'reservations.kolhapur@sayajihotels.com',
    'contact_phone': '+91 231 255 5555',
  },
];

Map<String, dynamic> _getTierBadgeStyle(String? tier) {
  final t = (tier ?? 'PARTNER').toUpperCase();
  switch (t) {
    case 'PLATINUM':
      return {
        'label': 'PLATINUM',
        'color': const Color(0xFF8C1119),
        'bgColor': const Color(0xFFFFFBEB),
        'borderColor': const Color(0xFFF59E0B),
        'badgeText': '🥇 PLATINUM SPONSOR',
        'gradient': const [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
      };
    case 'GOLD':
      return {
        'label': 'GOLD',
        'color': const Color(0xFFB45309),
        'bgColor': const Color(0xFFFEF3C7),
        'borderColor': const Color(0xFFF59E0B),
        'badgeText': '🥈 GOLD SPONSOR',
        'gradient': const [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
      };
    case 'SILVER':
      return {
        'label': 'SILVER',
        'color': const Color(0xFF334155),
        'bgColor': const Color(0xFFF1F5F9),
        'borderColor': const Color(0xFF94A3B8),
        'badgeText': '🥉 SILVER SPONSOR',
        'gradient': const [Color(0xFFF8FAFC), Color(0xFFE2E8F0)],
      };
    default:
      return {
        'label': 'PARTNER',
        'color': const Color(0xFF047857),
        'bgColor': const Color(0xFFECFDF5),
        'borderColor': const Color(0xFF10B981),
        'badgeText': '🤝 OFFICIAL PARTNER',
        'gradient': const [Color(0xFFECFDF5), Color(0xFFD1FAE5)],
      };
  }
}

class _HomeSponsorsSection extends StatelessWidget {
  final VoidCallback onViewAll;
  const _HomeSponsorsSection({required this.onViewAll});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: ApiService.get('/sponsors'),
      builder: (context, snapshot) {
        List<dynamic> list = defaultSponsors;
        if (snapshot.hasData && snapshot.data is List && (snapshot.data as List).isNotEmpty) {
          list = snapshot.data as List;
        }

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: gold.withOpacity(0.35), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: maroon.withOpacity(0.04),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: gold.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.stars_rounded, color: maroon, size: 20),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'OUR SPONSORS & PARTNERS',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: darkMaroon,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: onViewAll,
                    icon: const Icon(Icons.arrow_forward_rounded, size: 16, color: maroon),
                    label: const Text(
                      'View All',
                      style: TextStyle(color: maroon, fontWeight: FontWeight.w800, fontSize: 12),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Proudly supported by leading innovators in pathology and medical diagnostics.',
                style: TextStyle(fontSize: 12, color: muted, height: 1.3),
              ),
              const SizedBox(height: 14),

              // Horizontal list of top sponsors
              SizedBox(
                height: 148,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final item = list[index];
                    final name = item['name'] ?? 'Sponsor';
                    final tier = item['tier'] ?? 'PLATINUM';
                    final category = item['category'] ?? '';
                    final logoUrl = resolveMediaUrl(item['logo_url']);
                    final booth = item['booth_number'] ?? '';
                    final badgeStyle = _getTierBadgeStyle(tier);

                    return GestureDetector(
                      onTap: () {
                        _showSponsorDialog(context, item);
                      },
                      child: Container(
                        width: 175,
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFCFAF5),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: (badgeStyle['borderColor'] as Color).withOpacity(0.5), width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: badgeStyle['bgColor'] as Color,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: badgeStyle['borderColor'] as Color, width: 0.8),
                                  ),
                                  child: Text(
                                    tier.toString().toUpperCase(),
                                    style: TextStyle(
                                      color: badgeStyle['color'] as Color,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                const Icon(Icons.info_outline_rounded, color: muted, size: 15),
                              ],
                            ),
                            Center(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  logoUrl,
                                  height: 38,
                                  width: 80,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    height: 38,
                                    width: 80,
                                    color: Colors.grey.shade200,
                                    child: const Icon(Icons.business, color: maroon, size: 24),
                                  ),
                                ),
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                    color: slate,
                                  ),
                                ),
                                if (booth.isNotEmpty)
                                  Text(
                                    booth,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: maroon,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  )
                                else if (category.isNotEmpty)
                                  Text(
                                    category,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 10, color: muted),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

void _showSponsorDialog(BuildContext context, dynamic sponsor) {
  final name = sponsor['name'] ?? 'Sponsor Profile';
  final tier = sponsor['tier'] ?? 'PLATINUM';
  final category = sponsor['category'] ?? '';
  final logoUrl = resolveMediaUrl(sponsor['logo_url']);
  final description = sponsor['description'] ?? 'Proud partner supporting MAPCON 2026.';
  final booth = sponsor['booth_number'] ?? '';
  final website = sponsor['website_url'] ?? '';
  final email = sponsor['contact_email'] ?? '';
  final phone = sponsor['contact_phone'] ?? '';
  final badgeStyle = _getTierBadgeStyle(tier);

  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: badgeStyle['bgColor'] as Color,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: badgeStyle['borderColor'] as Color, width: 1.2),
                    ),
                    child: Text(
                      badgeStyle['badgeText'] as String,
                      style: TextStyle(
                        color: badgeStyle['color'] as Color,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: muted, size: 22),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      logoUrl,
                      height: 70,
                      width: 140,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 70,
                        width: 140,
                        color: maroon.withOpacity(0.08),
                        child: const Icon(Icons.business_rounded, color: maroon, size: 36),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: slate),
                ),
              ),
              if (category.isNotEmpty) ...[
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    category,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: maroon),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 14),
              if (booth.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFF59E0B)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.storefront_rounded, color: Color(0xFFB45309), size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Exhibition Booth: $booth',
                          style: const TextStyle(color: Color(0xFF78350F), fontWeight: FontWeight.w800, fontSize: 12.5),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Text(
                description,
                style: const TextStyle(fontSize: 13.5, color: slate, height: 1.45),
              ),
              const SizedBox(height: 18),
              if (email.isNotEmpty || phone.isNotEmpty) ...[
                const Text('Contact Information', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: muted)),
                const SizedBox(height: 6),
                if (email.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.email_outlined, size: 16, color: maroon),
                        const SizedBox(width: 8),
                        Expanded(child: Text(email, style: const TextStyle(fontSize: 12.5, color: slate, fontWeight: FontWeight.w600))),
                      ],
                    ),
                  ),
                if (phone.isNotEmpty)
                  Row(
                    children: [
                      const Icon(Icons.phone_outlined, size: 16, color: maroon),
                      const SizedBox(width: 8),
                      Expanded(child: Text(phone, style: const TextStyle(fontSize: 12.5, color: slate, fontWeight: FontWeight.w600))),
                    ],
                  ),
                const SizedBox(height: 16),
              ],
              if (website.isNotEmpty)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: maroon,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: const Text('Visit Official Website', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () {
                      launchUrl(Uri.parse(website), mode: LaunchMode.externalApplication);
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

// Full Dedicated Sponsors & Partners Screen
class SponsorsScreen extends StatefulWidget {
  const SponsorsScreen({super.key});

  @override
  State<SponsorsScreen> createState() => _SponsorsScreenState();
}

class _SponsorsScreenState extends State<SponsorsScreen> {
  String selectedTier = 'ALL';
  String searchQuery = '';
  final TextEditingController searchController = TextEditingController();

  Future<List<dynamic>> _loadSponsors() async {
    try {
      final res = await ApiService.get('/sponsors');
      if (res is List && res.isNotEmpty) {
        return res;
      }
    } catch (_) {}
    return defaultSponsors;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Scaffold(
        backgroundColor: cream,
        appBar: AppBar(
          title: const Text(
            'Our Sponsors & Partners',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
          ),
          backgroundColor: maroon,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: FutureBuilder<List<dynamic>>(
          future: _loadSponsors(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: maroon));
            }

            final sponsors = snapshot.data ?? defaultSponsors;

            final filtered = sponsors.where((s) {
              final tier = (s['tier'] ?? '').toString().toUpperCase();
              final matchesTier = selectedTier == 'ALL' || tier == selectedTier;
              final q = searchQuery.toLowerCase().trim();
              final name = (s['name'] ?? '').toString().toLowerCase();
              final category = (s['category'] ?? '').toString().toLowerCase();
              final booth = (s['booth_number'] ?? '').toString().toLowerCase();
              final matchesQuery = q.isEmpty || name.contains(q) || category.contains(q) || booth.contains(q);
              return matchesTier && matchesQuery;
            }).toList();

            return Column(
              children: [
                // Top Search and Tier Filter Bar
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextField(
                          controller: searchController,
                          decoration: InputDecoration(
                            hintText: 'Search sponsors, categories, stalls...',
                            hintStyle: const TextStyle(fontSize: 13, color: muted),
                            prefixIcon: const Icon(Icons.search, color: muted, size: 20),
                            suffixIcon: searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18, color: muted),
                                    onPressed: () {
                                      searchController.clear();
                                      setState(() => searchQuery = '');
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                          onChanged: (val) => setState(() => searchQuery = val),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterChip('ALL', 'All Partners (${sponsors.length})'),
                            _buildFilterChip('PLATINUM', '🥇 Platinum'),
                            _buildFilterChip('GOLD', '🥈 Gold'),
                            _buildFilterChip('SILVER', '🥉 Silver'),
                            _buildFilterChip('PARTNER', '🤝 Academic & Hospitality'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Sponsor Cards Grid / List
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.handshake_outlined, size: 54, color: muted),
                              const SizedBox(height: 12),
                              const Text(
                                'No sponsors match your filter',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: slate),
                              ),
                              const SizedBox(height: 6),
                              TextButton(
                                onPressed: () {
                                  searchController.clear();
                                  setState(() {
                                    selectedTier = 'ALL';
                                    searchQuery = '';
                                  });
                                },
                                child: const Text('Reset Filters', style: TextStyle(color: maroon, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final item = filtered[index];
                            final name = item['name'] ?? 'Sponsor';
                            final tier = (item['tier'] ?? 'PLATINUM').toString().toUpperCase();
                            final category = item['category'] ?? '';
                            final logoUrl = resolveMediaUrl(item['logo_url']);
                            final description = item['description'] ?? '';
                            final booth = item['booth_number'] ?? '';
                            final website = item['website_url'] ?? '';
                            final badgeStyle = _getTierBadgeStyle(tier);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: (badgeStyle['borderColor'] as Color).withOpacity(0.4),
                                  width: 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(18),
                                onTap: () => _showSponsorDialog(context, item),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(12),
                                            child: Container(
                                              height: 55,
                                              width: 75,
                                              color: const Color(0xFFF8FAFC),
                                              child: Image.network(
                                                logoUrl,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) => Container(
                                                  color: maroon.withOpacity(0.08),
                                                  child: const Icon(Icons.business, color: maroon, size: 28),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                      decoration: BoxDecoration(
                                                        color: badgeStyle['bgColor'] as Color,
                                                        borderRadius: BorderRadius.circular(12),
                                                        border: Border.all(color: badgeStyle['borderColor'] as Color, width: 0.9),
                                                      ),
                                                      child: Text(
                                                        tier,
                                                        style: TextStyle(
                                                          color: badgeStyle['color'] as Color,
                                                          fontSize: 9.5,
                                                          fontWeight: FontWeight.w900,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  name,
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w900,
                                                    color: slate,
                                                  ),
                                                ),
                                                if (category.isNotEmpty) ...[
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    category,
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w700,
                                                      color: maroon,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (description.isNotEmpty) ...[
                                        const SizedBox(height: 10),
                                        Text(
                                          description,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 12.5, color: slate, height: 1.35),
                                        ),
                                      ],
                                      const SizedBox(height: 12),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          if (booth.isNotEmpty)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFEF3C7),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.storefront, size: 14, color: Color(0xFFB45309)),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    booth,
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w800,
                                                      color: Color(0xFF78350F),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            )
                                          else
                                            const SizedBox(),
                                          Row(
                                            children: [
                                              if (website.isNotEmpty)
                                                InkWell(
                                                  onTap: () {
                                                    launchUrl(Uri.parse(website), mode: LaunchMode.externalApplication);
                                                  },
                                                  borderRadius: BorderRadius.circular(8),
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                                    decoration: BoxDecoration(
                                                      color: maroon.withOpacity(0.08),
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: const Row(
                                                      children: [
                                                        Icon(Icons.language, color: maroon, size: 14),
                                                        SizedBox(width: 4),
                                                        Text(
                                                          'Website',
                                                          style: TextStyle(
                                                            color: maroon,
                                                            fontSize: 11.5,
                                                            fontWeight: FontWeight.w800,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              const SizedBox(width: 8),
                                              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: muted),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildFilterChip(String tierKey, String label) {
    final isSelected = selectedTier == tierKey;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: maroon,
        backgroundColor: const Color(0xFFF1F5F9),
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : slate,
          fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
          fontSize: 11.5,
        ),
        checkmarkColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        onSelected: (_) {
          setState(() => selectedTier = tierKey);
        },
      ),
    );
  }
}


// ----------------------------------------------------
// VIRTUAL STAGE & HYBRID STREAM SCREEN (2 ZOOM LINKS)
// ----------------------------------------------------
class VirtualStageScreen extends StatefulWidget {
  const VirtualStageScreen({super.key});

  @override
  State<VirtualStageScreen> createState() => _VirtualStageScreenState();
}

class _VirtualStageScreenState extends State<VirtualStageScreen> {
  Map<String, dynamic>? _streamSettings;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    RealtimeSyncService.instance.syncNotifier.addListener(_loadData);
  }

  @override
  void dispose() {
    RealtimeSyncService.instance.syncNotifier.removeListener(_loadData);
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final stRes = await ApiService.get('/stream/settings');
      if (mounted) {
        setState(() {
          if (stRes is Map) _streamSettings = Map<String, dynamic>.from(stRes);
          _loading = false;
        });
        return;
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _joinZoom(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Zoom link directly. Please use Meeting ID & Passcode.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard!'),
        backgroundColor: const Color(0xFF16A34A),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final streamsList = (_streamSettings != null && _streamSettings!['streams'] is List && (_streamSettings!['streams'] as List).isNotEmpty)
        ? (_streamSettings!['streams'] as List)
        : null;

    final primaryColors = [
      const Color(0xFF2563EB),
      const Color(0xFF0891B2),
      const Color(0xFF7C3AED),
      const Color(0xFF059669),
      const Color(0xFFD97706),
    ];
    final accentColors = [
      const Color(0xFF60A5FA),
      const Color(0xFF22D3EE),
      const Color(0xFFA78BFA),
      const Color(0xFF34D399),
      const Color(0xFFFBBF24),
    ];

    // Fallback Stream 1
    final zoom1 = (_streamSettings?['zoom_link'] ?? 'https://zoom.us/j/84512948123?pwd=MAPCON2026HYBRID').toString().trim();
    final meetingId1 = (_streamSettings?['meeting_id'] ?? '845 1294 8123').toString().trim();
    final passcode1 = (_streamSettings?['passcode'] ?? 'MAPCON2026').toString().trim();
    final title1 = (_streamSettings?['stream_title'] ?? 'Hall A - Main Stage (Zoom)').toString().trim();
    final instructions1 = (_streamSettings?['stream_instructions'] ?? 'Keynotes, Plenary Sessions, and Presidential Orations.').toString().trim();
    final isLive1 = _streamSettings == null ? true : (_streamSettings?['is_live'] == 1 || _streamSettings?['is_live'] == true || _streamSettings?['is_live'] == '1');

    // Fallback Stream 2
    final zoom2 = (_streamSettings?['zoom_link_2'] ?? 'https://zoom.us/j/84512948124?pwd=MAPCON2026HALLB').toString().trim();
    final meetingId2 = (_streamSettings?['meeting_id_2'] ?? '845 1294 8124').toString().trim();
    final passcode2 = (_streamSettings?['passcode_2'] ?? 'MAPCON2026B').toString().trim();
    final title2 = (_streamSettings?['stream_title_2'] ?? 'Hall B - Scientific Hall (Zoom)').toString().trim();
    final instructions2 = (_streamSettings?['stream_instructions_2'] ?? 'Scientific Papers, Symposia, and Interactive Panel Discussions.').toString().trim();
    final isLive2 = _streamSettings == null ? true : (_streamSettings?['is_live_2'] == 1 || _streamSettings?['is_live_2'] == true || _streamSettings?['is_live_2'] == '1');

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Zoom Live Stages', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17)),
            Text('Direct Conference Stream Links', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: () {
              setState(() => _loading = true);
              _loadData();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                children: [
                  // Information banner
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline_rounded, color: Color(0xFF60A5FA), size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Tap on any hall link below to join live sessions directly on Zoom.',
                            style: TextStyle(color: Color(0xFFE2E8F0), fontSize: 12.5, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (streamsList != null) ...[
                    for (int i = 0; i < streamsList.length; i++) ...[
                      _buildZoomCard(
                        hallLabel: (streamsList[i]['title'] != null && streamsList[i]['title'].toString().toUpperCase().contains('HALL'))
                            ? streamsList[i]['title'].toString().split('-').first.trim().toUpperCase()
                            : 'STREAM ${i + 1}',
                        title: (streamsList[i]['title'] ?? 'Zoom Stage ${i + 1}').toString().trim(),
                        instructions: (streamsList[i]['instructions'] ?? '').toString().trim(),
                        meetingId: (streamsList[i]['meeting_id'] ?? '').toString().trim(),
                        passcode: (streamsList[i]['passcode'] ?? '').toString().trim(),
                        zoomUrl: (streamsList[i]['zoom_link'] ?? '').toString().trim(),
                        isLive: streamsList[i]['is_live'] == 1 || streamsList[i]['is_live'] == true || streamsList[i]['is_live'] == '1',
                        primaryColor: primaryColors[i % primaryColors.length],
                        accentColor: accentColors[i % accentColors.length],
                      ),
                      const SizedBox(height: 18),
                    ],
                  ] else ...[
                    // Fallback STREAM CARD 1 (HALL A)
                    _buildZoomCard(
                      hallLabel: 'HALL A',
                      title: title1.isNotEmpty ? title1 : 'Hall A - Main Stage (Zoom)',
                      instructions: instructions1,
                      meetingId: meetingId1,
                      passcode: passcode1,
                      zoomUrl: zoom1,
                      isLive: isLive1,
                      primaryColor: primaryColors[0],
                      accentColor: accentColors[0],
                    ),

                    const SizedBox(height: 18),

                    // Fallback STREAM CARD 2 (HALL B)
                    _buildZoomCard(
                      hallLabel: 'HALL B',
                      title: title2.isNotEmpty ? title2 : 'Hall B - Scientific Hall (Zoom)',
                      instructions: instructions2,
                      meetingId: meetingId2,
                      passcode: passcode2,
                      zoomUrl: zoom2,
                      isLive: isLive2,
                      primaryColor: primaryColors[1],
                      accentColor: accentColors[1],
                    ),

                    const SizedBox(height: 20),
                  ],

                  // Guidelines Box
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B).withOpacity(0.8),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Row(
                          children: [
                            Icon(Icons.tips_and_updates_rounded, color: Color(0xFFFBBF24), size: 18),
                            SizedBox(width: 8),
                            Text('Delegate Guidelines:', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 13.5)),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text('• Keep your microphone muted during presentations.', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                        SizedBox(height: 4),
                        Text('• Post your queries in the Zoom Q&A box for the speaker.', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                        SizedBox(height: 4),
                        Text('• You can copy Meeting ID & Passcode if joining manually from the Zoom app.', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  Widget _buildZoomCard({
    required String hallLabel,
    required String title,
    required String instructions,
    required String meetingId,
    required String passcode,
    required String zoomUrl,
    required bool isLive,
    required Color primaryColor,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1E293B),
            primaryColor.withOpacity(0.12),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isLive ? primaryColor : const Color(0xFF334155),
          width: isLive ? 2.0 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(isLive ? 0.25 : 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top badges
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: primaryColor.withOpacity(0.8)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.videocam_rounded, color: accentColor, size: 15),
                    const SizedBox(width: 6),
                    Text(
                      hallLabel,
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              if (isLive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFDC2626)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.fiber_manual_record, color: Color(0xFFDC2626), size: 8),
                      SizedBox(width: 4),
                      Text(
                        'LIVE STREAM',
                        style: TextStyle(color: Color(0xFFEF4444), fontSize: 10.5, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'ONLINE',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Title & instructions
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
          ),
          if (instructions.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              instructions,
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5, height: 1.35),
            ),
          ],
          const SizedBox(height: 14),

          // Meeting credentials box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withOpacity(0.7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Meeting ID:', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600)),
                    Text(
                      meetingId,
                      style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 13, fontWeight: FontWeight.w900, fontFamily: 'monospace'),
                    ),
                  ],
                ),
                const Divider(height: 14, color: Color(0xFF334155)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Passcode:', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600)),
                    Text(
                      passcode,
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900, fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Action Buttons
          Row(
            children: [
              Expanded(
                flex: 3,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.video_camera_front_rounded, size: 20),
                  label: Text(
                    'Join $hallLabel on Zoom',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5),
                  ),
                  onPressed: () => _joinZoom(zoomUrl),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () {
                  final text = '$title\nZoom: $zoomUrl\nMeeting ID: $meetingId\nPasscode: $passcode';
                  _copyToClipboard(text, '$hallLabel Details');
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 46,
                  width: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFF334155).withOpacity(0.7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF475569)),
                  ),
                  child: const Icon(Icons.copy_rounded, color: Color(0xFFE2E8F0), size: 18),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}



// ----------------------------------------------------
// REDESIGNED EVENT SCHEDULE SCREEN
// ----------------------------------------------------
class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});
  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  String selectedDay = 'ALL';
  String selectedCategory = 'ALL';
  String searchQuery = '';
  final TextEditingController searchController = TextEditingController();
  final Set<int> bookmarkedSessions = {};

  @override
  void initState() {
    super.initState();
    RealtimeSyncService.instance.syncNotifier.addListener(_onSync);
  }

  void _onSync() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    RealtimeSyncService.instance.syncNotifier.removeListener(_onSync);
    searchController.dispose();
    super.dispose();
  }

  Future<List<dynamic>> load() async {
    final result = await ApiService.get('/sessions');
    return result is List ? result : <dynamic>[];
  }

  Color _getCategoryColor(String? category) {
    final cat = (category ?? '').toLowerCase();
    if (cat.contains('ceremony') || cat.contains('inaugur')) {
      return maroon;
    } else if (cat.contains('keynote') || cat.contains('lead')) {
      return const Color(0xFFD97706);
    } else if (cat.contains('orientation')) {
      return const Color(0xFF2563EB);
    } else if (cat.contains('panel') || cat.contains('discuss')) {
      return const Color(0xFF7C3AED);
    } else if (cat.contains('valedictory')) {
      return const Color(0xFF059669);
    }
    return const Color(0xFF475569);
  }

  void _showSessionDetails(BuildContext context, dynamic session) {
    final title = session['title'] ?? 'Session Details';
    final dateStr = formatSessionDate(session['session_date']);
    final timeStr = formatTimeRange(session['start_time'], session['end_time']);
    final speakerName = session['speaker_name'] ?? 'Guest Speaker';
    final hallName = session['hall_name'] ?? 'Conference Hall';
    final category = session['category'] ?? 'General';
    final photoUrl = resolveSpeakerPhoto(session['speaker_photo']);
    final catColor = _getCategoryColor(category);
    final zoomLink = (session['zoom_link'] ?? 'https://zoom.us/j/84512948123?pwd=MAPCON2026HYBRID').toString().trim();
    final meetingId = (session['meeting_id'] ?? '845 1294 8123').toString().trim();
    final passcode = (session['passcode'] ?? 'MAPCON2026').toString().trim();
    final isLive = session['is_live'] == 1 || session['is_live'] == true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: catColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: catColor.withOpacity(0.4)),
                  ),
                  child: Text(
                    category.toUpperCase(),
                    style: TextStyle(
                      color: catColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                if (isLive) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.fiber_manual_record, size: 8, color: Colors.white),
                        SizedBox(width: 4),
                        Text('LIVE STREAM', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
                ],
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: slate,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 18, color: maroon),
                      const SizedBox(width: 10),
                      Text(dateStr, style: const TextStyle(fontWeight: FontWeight.w700, color: slate)),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.access_time_rounded, size: 18, color: maroon),
                      const SizedBox(width: 10),
                      Text(timeStr, style: const TextStyle(fontWeight: FontWeight.w700, color: slate)),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 18, color: maroon),
                      const SizedBox(width: 10),
                      Text(hallName, style: const TextStyle(fontWeight: FontWeight.w700, color: slate)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Zoom Online Stream Box
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.videocam_rounded, color: Colors.white, size: 16),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'HYBRID & ONLINE LIVE STREAM (ZOOM)',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF1E40AF),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Meeting ID: $meetingId', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: slate)),
                      Text('Passcode: $passcode', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: muted)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(40),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: const Text('Join Live Session on Zoom', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                    onPressed: () async {
                      final uri = Uri.parse(zoomLink);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),
            const Text(
              'Distinguished Speaker',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: muted, letterSpacing: 1),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundImage: NetworkImage(photoUrl),
                  backgroundColor: maroon.withOpacity(0.1),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        speakerName,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: slate),
                      ),
                      Text(
                        category,
                        style: const TextStyle(fontSize: 13, color: muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: maroon,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.alarm_add_rounded, size: 18),
                    label: const Text('Set Session Reminder', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Reminder set for $title'),
                          backgroundColor: maroon,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        children: [
          const Header(title: 'Event Schedule'),

          // Search Input
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: searchController,
              onChanged: (v) => setState(() => searchQuery = v.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search by topic, speaker or hall...',
                hintStyle: const TextStyle(fontSize: 13.5, color: muted),
                prefixIcon: const Icon(Icons.search, size: 20, color: muted),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          searchController.clear();
                          setState(() => searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Schedule List
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: load(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: maroon),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 12),
                        const Text('Unable to load schedule', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: () => setState(() {}),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                final rawData = snapshot.data ?? [];
                if (rawData.isEmpty) {
                  return const Center(
                    child: Text('No sessions available', style: TextStyle(color: muted)),
                  );
                }

                // Extract Days and Categories for Filter Tabs
                final dayOptions = <String>{'ALL'};
                final catOptions = <String>{'ALL'};

                for (final item in rawData) {
                  final rawDate = item['session_date']?.toString() ?? '';
                  if (rawDate.isNotEmpty) dayOptions.add(rawDate);
                  final cat = item['category']?.toString() ?? '';
                  if (cat.isNotEmpty) catOptions.add(cat);
                }

                // Filter items
                final filtered = rawData.where((x) {
                  final title = (x['title'] ?? '').toString().toLowerCase();
                  final speaker = (x['speaker_name'] ?? '').toString().toLowerCase();
                  final hall = (x['hall_name'] ?? '').toString().toLowerCase();
                  final category = (x['category'] ?? '').toString();
                  final date = (x['session_date'] ?? '').toString();

                  // Search filter
                  if (searchQuery.isNotEmpty) {
                    final match = title.contains(searchQuery) ||
                        speaker.contains(searchQuery) ||
                        hall.contains(searchQuery) ||
                        category.toLowerCase().contains(searchQuery);
                    if (!match) return false;
                  }

                  // Day filter
                  if (selectedDay != 'ALL' && date != selectedDay) {
                    return false;
                  }

                  // Category filter
                  if (selectedCategory != 'ALL' && category != selectedCategory) {
                    return false;
                  }

                  return true;
                }).toList();

                return Column(
                  children: [
                    // Day Selector Filter Tabs
                    if (dayOptions.length > 2)
                      Container(
                        height: 42,
                        color: Colors.white,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          children: dayOptions.map((d) {
                            final isSel = selectedDay == d;
                            final label = d == 'ALL' ? 'All Days' : formatShortDate(d);
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(label),
                                selected: isSel,
                                selectedColor: maroon,
                                backgroundColor: const Color(0xFFF1F5F9),
                                labelStyle: TextStyle(
                                  color: isSel ? Colors.white : slate,
                                  fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                                  fontSize: 12,
                                ),
                                onSelected: (_) => setState(() => selectedDay = d),
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                    const Divider(height: 1, color: Color(0xFFE2E8F0)),

                    // Sessions List
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.event_busy, size: 54, color: Colors.grey.shade400),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'No matching sessions found',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: slate),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text('Try clearing your search or filters', style: TextStyle(color: muted)),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 14, 16, 80),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final x = filtered[index];
                                final id = x['id'] is int ? x['id'] as int : index;
                                final title = x['title'] ?? 'Conference Session';
                                final dateFormatted = formatSessionDate(x['session_date']);
                                final timeFormatted = formatTimeRange(x['start_time'], x['end_time']);
                                final speakerName = x['speaker_name'] ?? 'Speaker to be announced';
                                final hallName = x['hall_name'] ?? 'Main Auditorium';
                                final category = x['category'] ?? 'Session';
                                final photoUrl = resolveSpeakerPhoto(x['speaker_photo']);
                                final isBookmarked = bookmarkedSessions.contains(id);
                                final catColor = _getCategoryColor(category);

                                return Card(
                                  elevation: 0,
                                  margin: const EdgeInsets.only(bottom: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                    side: BorderSide(color: Colors.grey.shade200, width: 1.2),
                                  ),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(18),
                                    onTap: () => _showSessionDetails(context, x),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Top Row: Category Chip & Time Tag
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                                                decoration: BoxDecoration(
                                                  color: catColor.withOpacity(0.12),
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(color: catColor.withOpacity(0.35)),
                                                ),
                                                child: Text(
                                                  category.toUpperCase(),
                                                  style: TextStyle(
                                                    color: catColor,
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.w900,
                                                    letterSpacing: 0.4,
                                                  ),
                                                ),
                                              ),
                                              if ((x['zoom_link'] ?? '').toString().isNotEmpty || x['is_live'] == 1 || x['is_live'] == true) ...[
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                                                  decoration: BoxDecoration(
                                                    color: ((x['is_live'] == 1 || x['is_live'] == true) ? const Color(0xFFDC2626) : const Color(0xFF2563EB)).withOpacity(0.12),
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(color: ((x['is_live'] == 1 || x['is_live'] == true) ? const Color(0xFFDC2626) : const Color(0xFF2563EB)).withOpacity(0.4)),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon((x['is_live'] == 1 || x['is_live'] == true) ? Icons.fiber_manual_record : Icons.videocam_rounded, size: 10, color: (x['is_live'] == 1 || x['is_live'] == true) ? const Color(0xFFDC2626) : const Color(0xFF2563EB)),
                                                      const SizedBox(width: 3.5),
                                                      Text(
                                                        (x['is_live'] == 1 || x['is_live'] == true) ? 'LIVE' : 'ZOOM',
                                                        style: TextStyle(
                                                          color: (x['is_live'] == 1 || x['is_live'] == true) ? const Color(0xFFDC2626) : const Color(0xFF2563EB),
                                                          fontSize: 9.5,
                                                          fontWeight: FontWeight.w900,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                              const Spacer(),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFF1F5F9),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Row(
                                                  children: [
                                                    const Icon(Icons.access_time, size: 13, color: muted),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      timeFormatted,
                                                      style: const TextStyle(
                                                        color: slate,
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w700,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),

                                          // Session Title
                                          Text(
                                            title,
                                            style: const TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.w900,
                                              color: slate,
                                              height: 1.25,
                                            ),
                                          ),
                                          const SizedBox(height: 6),

                                          // Date line
                                          Row(
                                            children: [
                                              const Icon(Icons.calendar_month_outlined, size: 14, color: muted),
                                              const SizedBox(width: 5),
                                              Text(
                                                dateFormatted,
                                                style: const TextStyle(
                                                  color: muted,
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 14),

                                          // Divider
                                          const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                          const SizedBox(height: 12),

                                          // Bottom Row: Speaker, Hall & Bookmark
                                          Row(
                                            children: [
                                              Container(
                                                width: 38,
                                                height: 38,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  border: Border.all(color: maroon.withOpacity(0.3), width: 1.5),
                                                ),
                                                child: ClipOval(
                                                  child: Image.network(
                                                    photoUrl,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (_, __, ___) => Container(
                                                      color: maroon.withOpacity(0.1),
                                                      child: const Icon(Icons.person, size: 22, color: maroon),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      speakerName,
                                                      style: const TextStyle(
                                                        fontSize: 13.5,
                                                        fontWeight: FontWeight.w800,
                                                        color: slate,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                    Row(
                                                      children: [
                                                        const Icon(Icons.location_on_outlined, size: 12, color: maroon),
                                                        const SizedBox(width: 2),
                                                        Expanded(
                                                          child: Text(
                                                            hallName,
                                                            style: const TextStyle(
                                                              fontSize: 12,
                                                              fontWeight: FontWeight.w600,
                                                              color: muted,
                                                            ),
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              IconButton(
                                                icon: Icon(
                                                  isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                                                  color: isBookmarked ? gold : muted,
                                                  size: 22,
                                                ),
                                                onPressed: () {
                                                  setState(() {
                                                    if (isBookmarked) {
                                                      bookmarkedSessions.remove(id);
                                                    } else {
                                                      bookmarkedSessions.add(id);
                                                    }
                                                  });
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        isBookmarked
                                                            ? 'Removed from saved sessions'
                                                            : 'Saved to my schedule',
                                                      ),
                                                      duration: const Duration(seconds: 1),
                                                      backgroundColor: maroon,
                                                    ),
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------
// SPEAKERS SCREEN
// ----------------------------------------------------
class SpeakersScreen extends StatefulWidget {
  const SpeakersScreen({super.key});

  @override
  State<SpeakersScreen> createState() => _SpeakersScreenState();
}

class _SpeakersScreenState extends State<SpeakersScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    RealtimeSyncService.instance.syncNotifier.addListener(_onSync);
  }

  void _onSync() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _searchController.dispose();
    RealtimeSyncService.instance.syncNotifier.removeListener(_onSync);
    super.dispose();
  }

  void _launchWhatsApp(String phone, String name) async {
    String cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.length == 10) cleanPhone = '91$cleanPhone';
    if (cleanPhone.isEmpty) return;
    final msg = Uri.encodeComponent('Namaste $name! 🙏 Connecting regarding the conference session.');
    final url = Uri.parse('https://wa.me/$cleanPhone?text=$msg');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final conference = ConferenceScope.of(context);
    final primary = conference.primaryColor;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Conference Speakers', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19)),
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Search & Header Banner
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search speaker name, designation, topic...',
                hintStyle: TextStyle(fontSize: 13.5, color: Colors.grey.shade500),
                prefixIcon: Icon(Icons.search_rounded, color: primary, size: 22),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Speakers List
          Expanded(
            child: RefreshIndicator(
              color: primary,
              onRefresh: () async {
                setState(() {});
                await Future.delayed(const Duration(milliseconds: 500));
              },
              child: FutureBuilder(
                future: ApiService.get('/speakers'),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator(color: primary));
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline_rounded, size: 48, color: Colors.red.shade300),
                          const SizedBox(height: 10),
                          const Text('Unable to load speakers', style: TextStyle(fontWeight: FontWeight.w700, color: slate)),
                          const SizedBox(height: 6),
                          TextButton(onPressed: () => setState(() {}), child: const Text('Try Again')),
                        ],
                      ),
                    );
                  }

                  final list = snapshot.data is List ? snapshot.data as List : [];
                  final filtered = list.where((s) {
                    if (_searchQuery.isEmpty) return true;
                    final name = (s['name'] ?? '').toString().toLowerCase();
                    final desig = (s['designation'] ?? '').toString().toLowerCase();
                    final org = (s['organization'] ?? '').toString().toLowerCase();
                    final bio = (s['bio'] ?? '').toString().toLowerCase();
                    return name.contains(_searchQuery) ||
                        desig.contains(_searchQuery) ||
                        org.contains(_searchQuery) ||
                        bio.contains(_searchQuery);
                  }).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: primary.withOpacity(0.08),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.record_voice_over_rounded, size: 48, color: primary),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            _searchQuery.isNotEmpty ? 'No matching speakers found' : 'No speakers announced yet',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: slate),
                          ),
                          if (_searchQuery.isNotEmpty)
                            TextButton(
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                              child: const Text('Clear Search'),
                            ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final s = filtered[index];
                      final photoUrl = resolveSpeakerPhoto(s['photo']);
                      final name = s['name'] ?? 'Guest Speaker';
                      final designation = s['designation'] ?? 'Keynote Speaker';
                      final organization = s['organization'] ?? 'Conference Dignitary';
                      final bio = (s['bio'] ?? '').toString().trim();
                      final email = (s['email'] ?? '').toString().trim();
                      final phone = (s['phone'] ?? '').toString().trim();
                      final isKeynote = designation.toLowerCase().contains('keynote') ||
                          designation.toLowerCase().contains('president') ||
                          designation.toLowerCase().contains('chair') ||
                          index == 0;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isKeynote ? primary.withOpacity(0.25) : const Color(0xFFE2E8F0),
                            width: isKeynote ? 1.4 : 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isKeynote
                                  ? primary.withOpacity(0.08)
                                  : Colors.black.withOpacity(0.04),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Top Accent Banner for Keynote/Featured
                              if (isKeynote)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [primary, primary.withOpacity(0.85)],
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    ),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                                      SizedBox(width: 6),
                                      Text(
                                        'DISTINGUISHED KEYNOTE SPEAKER',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              Padding(
                                padding: const EdgeInsets.all(18),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Main Row: Avatar + Info
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Profile Avatar with Gradient Ring & Badge
                                        Stack(
                                          clipBehavior: Clip.none,
                                          children: [
                                            Container(
                                              width: 82,
                                              height: 82,
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(22),
                                                gradient: LinearGradient(
                                                  colors: [primary, Colors.amber.shade700],
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: primary.withOpacity(0.2),
                                                    blurRadius: 10,
                                                    offset: const Offset(0, 4),
                                                  ),
                                                ],
                                              ),
                                              padding: const EdgeInsets.all(2.5),
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(20),
                                                child: Image.network(
                                                  photoUrl,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) => Container(
                                                    color: const Color(0xFFF1F5F9),
                                                    child: Center(
                                                      child: Text(
                                                        name.isNotEmpty ? name[0].toUpperCase() : 'S',
                                                        style: TextStyle(
                                                          fontSize: 32,
                                                          fontWeight: FontWeight.w900,
                                                          color: primary,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            // Verified Icon Badge
                                            Positioned(
                                              bottom: -4,
                                              right: -4,
                                              child: Container(
                                                padding: const EdgeInsets.all(3.5),
                                                decoration: BoxDecoration(
                                                  color: Colors.amber.shade600,
                                                  shape: BoxShape.circle,
                                                  border: Border.all(color: Colors.white, width: 2),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black.withOpacity(0.12),
                                                      blurRadius: 4,
                                                    ),
                                                  ],
                                                ),
                                                child: const Icon(
                                                  Icons.mic_rounded,
                                                  size: 13,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(width: 16),

                                        // Speaker Details
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                name,
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w900,
                                                  color: Color(0xFF0F172A),
                                                  height: 1.2,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                                                decoration: BoxDecoration(
                                                  color: primary.withOpacity(0.09),
                                                  borderRadius: BorderRadius.circular(20),
                                                  border: Border.all(color: primary.withOpacity(0.2)),
                                                ),
                                                child: Text(
                                                  designation,
                                                  style: TextStyle(
                                                    color: primary,
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 11.5,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Row(
                                                children: [
                                                  Icon(Icons.account_balance_outlined, size: 14, color: Colors.grey.shade600),
                                                  const SizedBox(width: 5),
                                                  Expanded(
                                                    child: Text(
                                                      organization,
                                                      style: TextStyle(
                                                        fontSize: 12.5,
                                                        fontWeight: FontWeight.w600,
                                                        color: Colors.grey.shade700,
                                                      ),
                                                      maxLines: 2,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),

                                    // Bio Box if available
                                    if (bio.isNotEmpty) ...[
                                      const SizedBox(height: 14),
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF8FAFC),
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(color: const Color(0xFFE2E8F0)),
                                        ),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Container(
                                              margin: const EdgeInsets.only(top: 2, right: 8),
                                              padding: const EdgeInsets.all(3),
                                              decoration: BoxDecoration(
                                                color: primary.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Icon(Icons.format_quote_rounded, size: 14, color: primary),
                                            ),
                                            Expanded(
                                              child: Text(
                                                bio,
                                                style: const TextStyle(
                                                  fontSize: 12.5,
                                                  color: Color(0xFF334155),
                                                  height: 1.45,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],

                                    // Contact & Connect Action Pills
                                    if (email.isNotEmpty || phone.isNotEmpty) ...[
                                      const SizedBox(height: 14),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          if (email.isNotEmpty)
                                            Material(
                                              color: Colors.transparent,
                                              child: InkWell(
                                                onTap: () => launchUrl(Uri.parse('mailto:$email')),
                                                borderRadius: BorderRadius.circular(20),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                  decoration: BoxDecoration(
                                                    color: primary.withOpacity(0.06),
                                                    borderRadius: BorderRadius.circular(20),
                                                    border: Border.all(color: primary.withOpacity(0.25)),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.email_outlined, size: 14, color: primary),
                                                      const SizedBox(width: 5),
                                                      Text(
                                                        email,
                                                        style: TextStyle(
                                                          color: primary,
                                                          fontSize: 11.5,
                                                          fontWeight: FontWeight.w700,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          if (phone.isNotEmpty)
                                            Material(
                                              color: Colors.transparent,
                                              child: InkWell(
                                                onTap: () => launchUrl(Uri.parse('tel:$phone')),
                                                borderRadius: BorderRadius.circular(20),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFECFDF5),
                                                    borderRadius: BorderRadius.circular(20),
                                                    border: Border.all(color: const Color(0xFFA7F3D0)),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      const Icon(Icons.phone_outlined, size: 14, color: Color(0xFF059669)),
                                                      const SizedBox(width: 5),
                                                      Text(
                                                        phone,
                                                        style: const TextStyle(
                                                          color: Color(0xFF065F46),
                                                          fontSize: 11.5,
                                                          fontWeight: FontWeight.w700,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          if (phone.isNotEmpty)
                                            Material(
                                              color: Colors.transparent,
                                              child: InkWell(
                                                onTap: () => _launchWhatsApp(phone, name),
                                                borderRadius: BorderRadius.circular(20),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFF0FDF4),
                                                    borderRadius: BorderRadius.circular(20),
                                                    border: Border.all(color: const Color(0xFF86EFAC)),
                                                  ),
                                                  child: const Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.chat_bubble_outline_rounded, size: 14, color: Color(0xFF16A34A)),
                                                      SizedBox(width: 5),
                                                      Text(
                                                        'WhatsApp',
                                                        style: TextStyle(
                                                          color: Color(0xFF15803D),
                                                          fontSize: 11.5,
                                                          fontWeight: FontWeight.w700,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------

// ----------------------------------------------------
// NOTICES SCREEN
// ----------------------------------------------------
class NoticesScreen extends StatefulWidget {
  const NoticesScreen({super.key});

  @override
  State<NoticesScreen> createState() => _NoticesScreenState();
}

class _NoticesScreenState extends State<NoticesScreen> {
  String _selectedCategory = 'ALL';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  Set<String> _unseenOnArrival = {};
  bool _evaluatedUnseen = false;

  @override
  void initState() {
    super.initState();
    RealtimeSyncService.instance.syncNotifier.addListener(_onSync);
  }

  void _onSync() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _searchController.dispose();
    RealtimeSyncService.instance.syncNotifier.removeListener(_onSync);
    super.dispose();
  }

  Color _getNoticeColor(String? type, bool isUrgent) {
    if (isUrgent) return const Color(0xFFE11D48);
    final t = (type ?? '').toUpperCase();
    if (t.contains('SCHEDULE') || t.contains('SESSION') || t.contains('TIME')) {
      return const Color(0xFF2563EB);
    } else if (t.contains('TRANSPORT') || t.contains('TRAVEL') || t.contains('VEHICLE')) {
      return const Color(0xFF0D9488);
    } else if (t.contains('VENUE') || t.contains('HALL') || t.contains('HOTEL')) {
      return const Color(0xFFD97706);
    } else if (t.contains('REGISTRATION') || t.contains('CERTIFICATE')) {
      return const Color(0xFF059669);
    }
    return maroon;
  }

  IconData _getNoticeIcon(String? type, bool isUrgent) {
    if (isUrgent) return Icons.warning_amber_rounded;
    final t = (type ?? '').toUpperCase();
    if (t.contains('SCHEDULE') || t.contains('SESSION')) {
      return Icons.event_note_rounded;
    } else if (t.contains('TRANSPORT') || t.contains('TRAVEL')) {
      return Icons.directions_car_rounded;
    } else if (t.contains('VENUE') || t.contains('HALL') || t.contains('HOTEL')) {
      return Icons.location_on_rounded;
    } else if (t.contains('REGISTRATION') || t.contains('CERTIFICATE')) {
      return Icons.verified_user_rounded;
    }
    return Icons.campaign_rounded;
  }

  void _showNoticeDetailModal(BuildContext context, Map<String, dynamic> item, Color color, IconData icon, bool isUrgent) {
    final title = item['title']?.toString() ?? 'Notice';
    final message = item['message']?.toString() ?? '';
    final type = item['type']?.toString().toUpperCase() ?? 'GENERAL';
    final dateStr = formatSessionDate(item['created_at']);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: color.withOpacity(0.3)),
                        ),
                        child: Text(
                          isUrgent ? '🚨 URGENT' : type,
                          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900),
                        ),
                      ),
                      if (dateStr.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(dateStr, style: const TextStyle(fontSize: 11.5, color: muted)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: slate),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: const TextStyle(fontSize: 14.5, color: Color(0xFF334155), height: 1.55),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: color,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final conference = ConferenceScope.of(context);

    return SafeArea(
      top: false,
      child: Column(
        children: [
          const Header(title: 'Notices & Announcements'),
          Expanded(
            child: RefreshIndicator(
              color: conference.primaryColor,
              onRefresh: () async {
                setState(() {
                  _evaluatedUnseen = false;
                });
                await RealtimeSyncService.instance.calculateUnreadCount();
                await Future.delayed(const Duration(milliseconds: 300));
              },
              child: FutureBuilder(
                future: ApiService.get('/notices'),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator(color: conference.primaryColor));
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                          const SizedBox(height: 12),
                          const Text('Unable to load notices', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () => setState(() {}),
                            style: ElevatedButton.styleFrom(backgroundColor: conference.primaryColor),
                            child: const Text('Retry', style: TextStyle(color: Colors.white)),
                          )
                        ],
                      ),
                    );
                  }

                  final allData = snapshot.data is List ? snapshot.data as List : <dynamic>[];

                  // Capture unseen notices for highlight on first render, then mark as seen
                  if (!_evaluatedUnseen && allData.isNotEmpty) {
                    _evaluatedUnseen = true;
                    final seenIds = RealtimeSyncService.instance.seenIdsNotifier.value;
                    _unseenOnArrival = allData
                        .where((item) => !seenIds.contains(item['id']?.toString() ?? ''))
                        .map((item) => item['id']?.toString() ?? '')
                        .toSet();

                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      RealtimeSyncService.instance.markNoticesAsSeen(allData);
                    });
                  }

                  // Apply Filter & Search
                  final filteredData = allData.where((item) {
                    final type = (item['type']?.toString() ?? 'GENERAL').toUpperCase();
                    final isUrgent = item['priority'] == 'URGENT' || type == 'URGENT';
                    
                    if (_selectedCategory == 'URGENT' && !isUrgent) return false;
                    if (_selectedCategory == 'SCHEDULE' && !type.contains('SCHEDULE') && !type.contains('SESSION')) return false;
                    if (_selectedCategory == 'VENUE' && !type.contains('VENUE') && !type.contains('HALL')) return false;
                    if (_selectedCategory == 'TRANSPORT' && !type.contains('TRANSPORT') && !type.contains('TRAVEL')) return false;
                    if (_selectedCategory == 'GENERAL' && (isUrgent || type.contains('SCHEDULE') || type.contains('VENUE') || type.contains('TRANSPORT'))) return false;

                    if (_searchQuery.isNotEmpty) {
                      final q = _searchQuery.toLowerCase();
                      final title = (item['title']?.toString() ?? '').toLowerCase();
                      final message = (item['message']?.toString() ?? '').toLowerCase();
                      if (!title.contains(q) && !message.contains(q)) return false;
                    }
                    return true;
                  }).toList();

                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                    children: [
                      // Search Bar
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey.shade200, width: 1),
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (v) => setState(() => _searchQuery = v.trim()),
                          decoration: InputDecoration(
                            hintText: 'Search notices & updates...',
                            hintStyle: const TextStyle(fontSize: 13, color: muted),
                            prefixIcon: const Icon(Icons.search, size: 20, color: muted),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18, color: muted),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),

                      // Category Filter Chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Row(
                          children: [
                            _buildFilterChip('ALL', 'All (${allData.length})', conference.primaryColor),
                            const SizedBox(width: 8),
                            _buildFilterChip('URGENT', '🚨 Urgent', const Color(0xFFE11D48)),
                            const SizedBox(width: 8),
                            _buildFilterChip('SCHEDULE', '📅 Schedule', const Color(0xFF2563EB)),
                            const SizedBox(width: 8),
                            _buildFilterChip('VENUE', '📍 Venue', const Color(0xFFD97706)),
                            const SizedBox(width: 8),
                            _buildFilterChip('TRANSPORT', '🚗 Transport', const Color(0xFF0D9488)),
                            const SizedBox(width: 8),
                            _buildFilterChip('GENERAL', '📢 General', conference.primaryColor),
                          ],
                        ),
                      ),

                      // Header Row
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12, left: 2, right: 2),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: conference.primaryColor.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${filteredData.length} Announcements',
                                style: TextStyle(
                                  color: conference.primaryColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (_unseenOnArrival.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDC2626),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${_unseenOnArrival.length} New',
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900),
                                ),
                              ),
                            ],
                            const Spacer(),
                            TextButton.icon(
                              icon: Icon(Icons.done_all, size: 16, color: conference.primaryColor),
                              label: Text(
                                'Mark all read',
                                style: TextStyle(color: conference.primaryColor, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              onPressed: () {
                                RealtimeSyncService.instance.markAllAsRead();
                                setState(() {
                                  _unseenOnArrival.clear();
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('All notices marked as read'),
                                    duration: const Duration(seconds: 1),
                                    backgroundColor: conference.primaryColor,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),

                      if (filteredData.isEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 60),
                          alignment: Alignment.center,
                          child: Column(
                            children: [
                              Icon(Icons.notifications_none_rounded, size: 56, color: Colors.grey.shade400),
                              const SizedBox(height: 14),
                              const Text(
                                'No Announcements Found',
                                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: slate),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Check back later for live conference updates',
                                style: TextStyle(color: muted, fontSize: 13),
                              ),
                            ],
                          ),
                        )
                      else
                        ...filteredData.map((item) {
                          final isUrgent = item['priority'] == 'URGENT' || (item['type']?.toString().toUpperCase() == 'URGENT');
                          final noticeType = item['type']?.toString().toUpperCase() ?? 'GENERAL';
                          final noticeColor = _getNoticeColor(noticeType, isUrgent);
                          final noticeIcon = _getNoticeIcon(noticeType, isUrgent);
                          final createdAtStr = formatSessionDate(item['created_at']);
                          final isNew = _unseenOnArrival.contains(item['id']?.toString() ?? '');

                          return GestureDetector(
                            onTap: () => _showNoticeDetailModal(context, Map<String, dynamic>.from(item), noticeColor, noticeIcon, isUrgent),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: isNew ? noticeColor.withOpacity(0.04) : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isNew
                                      ? noticeColor.withOpacity(0.4)
                                      : isUrgent
                                          ? const Color(0xFFFCA5A5)
                                          : Colors.grey.shade200,
                                  width: isNew || isUrgent ? 1.4 : 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border(
                                      left: BorderSide(
                                        color: isUrgent ? const Color(0xFFDC2626) : noticeColor,
                                        width: 4.5,
                                      ),
                                    ),
                                  ),
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: noticeColor.withOpacity(0.12),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              noticeIcon,
                                              color: noticeColor,
                                              size: 19,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '${item['title'] ?? 'Announcement'}',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w900,
                                                    fontSize: 15.5,
                                                    color: slate,
                                                    height: 1.2,
                                                  ),
                                                ),
                                                if (createdAtStr.isNotEmpty) ...[
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    createdAtStr,
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      color: muted,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (isNew)
                                                Container(
                                                  margin: const EdgeInsets.only(right: 6),
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                                                  decoration: BoxDecoration(
                                                    gradient: const LinearGradient(
                                                      colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                                                    ),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: const Text(
                                                    'NEW',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 9,
                                                      fontWeight: FontWeight.w900,
                                                      letterSpacing: 0.5,
                                                    ),
                                                  ),
                                                ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: noticeColor.withOpacity(0.12),
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(color: noticeColor.withOpacity(0.3)),
                                                ),
                                                child: Text(
                                                  isUrgent ? 'URGENT' : noticeType,
                                                  style: TextStyle(
                                                    color: noticeColor,
                                                    fontSize: 9.5,
                                                    fontWeight: FontWeight.w900,
                                                    letterSpacing: 0.3,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        '${item['message'] ?? ''}',
                                        style: const TextStyle(fontSize: 13.5, color: Color(0xFF334155), height: 1.45),
                                        maxLines: 4,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label, Color color) {
    final isSelected = _selectedCategory == key;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: color.withOpacity(0.25), blurRadius: 6, offset: const Offset(0, 2))]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------
// GALLERY SCREEN (AI FACE RECOGNITION + PHOTOS)
// ----------------------------------------------------
class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ImagePicker _picker = ImagePicker();
  bool _isMatching = false;
  List<dynamic> _matchedPhotos = [];
  String _activeAlbum = 'ALL';
  int _refreshKey = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadInitialMatchedPhotos();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialMatchedPhotos() async {
    try {
      final res = await ApiService.get('/gallery/my-photos');
      List<dynamic> list = [];
      if (res is Map) {
        if (res['data'] is Map && res['data']['matches'] is List) {
          list = res['data']['matches'] as List;
        } else if (res['matches'] is List) {
          list = res['matches'] as List;
        } else if (res['data'] is List) {
          list = res['data'] as List;
        }
      } else if (res is List) {
        list = res;
      }
      if (mounted && list.isNotEmpty) {
        setState(() => _matchedPhotos = list);
      }
    } catch (_) {}
  }

  Future<void> _scanFaceAndFindPhotos(ImageSource source) async {
    try {
      String? base64Image;

      // Use live webcam video capture on web when user taps Take Selfie
      if (source == ImageSource.camera && kIsWeb) {
        final capturedDataUrl = await captureWebcamSelfie(context);
        if (capturedDataUrl == null || capturedDataUrl.isEmpty) {
          return; // User cancelled or closed webcam
        }
        base64Image = capturedDataUrl;
      } else {
        final XFile? photo = await _picker.pickImage(
          source: source,
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 85,
        );

        if (photo == null) return;

        final bytes = await photo.readAsBytes();
        base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      }

      setState(() {
        _isMatching = true;
      });

      final res = await ApiService.post('/gallery/match-selfie', {
        'conferenceId': ConferenceService.activeConferenceId,
        'selfie': base64Image,
      });

      List<dynamic> matched = [];
      if (res is Map) {
        if (res['data'] is Map && res['data']['matches'] is List) {
          matched = res['data']['matches'] as List;
        } else if (res['matches'] is List) {
          matched = res['matches'] as List;
        } else if (res['data'] is List) {
          matched = res['data'] as List;
        }
      } else if (res is List) {
        matched = res;
      }

      setState(() {
        _matchedPhotos = matched;
        _isMatching = false;
      });

      if (mounted) {
        if (matched.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('AI Face Recognition found ${matched.length} photos of you!'),
              backgroundColor: maroon,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No matching photos found in the conference gallery.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isMatching = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(formatErrorMessage(e, 'Could not complete AI face match. Please try another photo.')),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  void _openPhotoViewer(BuildContext context, dynamic photo, {bool isMatched = false}) {
    final photoUrl = resolveMediaUrl(photo['url']);
    final caption = photo['caption'] ?? 'Conference Moment';
    final album = photo['album'] ?? 'General';
    final confidence = isMatched ? (photo['confidencePercent'] ?? '95% Match') : null;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.92),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 3.5,
                child: Image.network(
                  photoUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Container(
                    height: 250,
                    color: Colors.grey.shade800,
                    child: const Center(child: Icon(Icons.broken_image, color: Colors.white, size: 48)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: maroon,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          album,
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (confidence != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.shade700,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.face_retouching_natural, color: Colors.white, size: 13),
                              const SizedBox(width: 4),
                              Text(
                                '$confidence',
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    caption,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: slate),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: maroon,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.download_rounded, size: 20),
                    label: const Text('Download High-Res Photo', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () {
                      launchUrl(Uri.parse(photoUrl), mode: LaunchMode.externalApplication);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('AI Photo Gallery', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: maroon,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: gold,
          unselectedLabelColor: Colors.white70,
          indicatorColor: gold,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
          tabs: const [
            Tab(
              icon: Icon(Icons.face_retouching_natural),
              text: 'Find My Photos',
            ),
            Tab(
              icon: Icon(Icons.photo_library_outlined),
              text: 'All Photos',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAiSelfieTab(),
          _buildAllPhotosTab(),
        ],
      ),
    );
  }

  Widget _buildAiSelfieTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF8C1119), Color(0xFF5B0A0F)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: maroon.withOpacity(0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.face_retouching_natural, color: gold, size: 28),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI Face Recognition Search',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17),
                        ),
                        Text(
                          'Take a quick selfie to find all your conference photos',
                          style: TextStyle(color: Color(0xFFF1E5D1), fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (_isMatching)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      children: [
                        CircularProgressIndicator(color: gold),
                        SizedBox(height: 10),
                        Text(
                          'Scanning conference photos with AI...',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: gold,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.camera_alt, size: 18),
                        label: const Text('Take Selfie', style: TextStyle(fontWeight: FontWeight.w800)),
                        onPressed: () => _scanFaceAndFindPhotos(ImageSource.camera),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white70),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.photo_library, size: 18),
                        label: const Text('Choose Photo', style: TextStyle(fontWeight: FontWeight.w800)),
                        onPressed: () => _scanFaceAndFindPhotos(ImageSource.gallery),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Your Matched Photos (${_matchedPhotos.length})',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: slate),
            ),
            if (_matchedPhotos.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Text(
                  'AI Verified',
                  style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (_matchedPhotos.isEmpty && !_isMatching)
          Container(
            padding: const EdgeInsets.all(32),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Icon(Icons.face_unlock_outlined, size: 52, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                const Text(
                  'No matched photos found yet',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: slate),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Tap "Take Selfie" above to let AI scan all conference pictures for your face.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: muted),
                ),
              ],
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.85,
            ),
            itemCount: _matchedPhotos.length,
            itemBuilder: (context, index) {
              final item = _matchedPhotos[index];
              final url = resolveMediaUrl(item['url']);
              final caption = item['caption'] ?? 'Conference moment';
              final confidence = item['confidencePercent'] ?? '94% Match';

              return GestureDetector(
                onTap: () => _openPhotoViewer(context, item, isMatched: true),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Image.network(
                          url,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.broken_image, color: Colors.grey),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: confidence.contains('Exact') 
                                ? const Color(0xFF047857) 
                                : const Color(0xFF1E293B).withOpacity(0.85),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: confidence.contains('Exact') ? Colors.greenAccent : gold.withOpacity(0.7),
                              width: 1.2,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                confidence.contains('Exact') ? Icons.check_circle : Icons.auto_awesome,
                                color: confidence.contains('Exact') ? Colors.greenAccent : gold,
                                size: 12,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                confidence,
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                          child: Text(
                            caption,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildAllPhotosTab() {
    return RefreshIndicator(
      color: maroon,
      onRefresh: () async {
        setState(() => _refreshKey++);
      },
      child: FutureBuilder(
        key: ValueKey(_refreshKey),
        future: ApiService.get('/gallery'),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: maroon));
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.photo_library_outlined, size: 48, color: muted),
                    const SizedBox(height: 12),
                    const Text('Unable to load conference gallery', style: TextStyle(fontWeight: FontWeight.bold, color: slate)),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: maroon, foregroundColor: Colors.white),
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Retry'),
                      onPressed: () => setState(() => _refreshKey++),
                    ),
                  ],
                ),
              ),
            );
          }

          final photos = snapshot.data is List ? (snapshot.data as List) : [];
          if (photos.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.photo_library_outlined, size: 64, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    const Text(
                      'No Conference Photos Yet',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: slate),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Photos uploaded by event organizers will appear here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: muted),
                    ),
                  ],
                ),
              ),
            );
          }

          final distinctAlbums = {'ALL', ...photos.map((p) => (p['album'] ?? 'General').toString())}.toList();
          final filtered = _activeAlbum == 'ALL'
              ? photos
              : photos.where((p) => (p['album'] ?? 'General') == _activeAlbum).toList();

          return Column(
            children: [
              Container(
                height: 48,
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: distinctAlbums.length,
                  itemBuilder: (context, idx) {
                    final album = distinctAlbums[idx];
                    final isSelected = _activeAlbum == album;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(album),
                        selected: isSelected,
                        selectedColor: maroon,
                        backgroundColor: const Color(0xFFF1F5F9),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : slate,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          fontSize: 12,
                        ),
                        onSelected: (_) => setState(() => _activeAlbum = album),
                      ),
                    );
                  },
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.9,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    final url = resolveMediaUrl(item['url']);
                    final caption = item['caption'] ?? 'Conference moment';
                    final album = item['album'] ?? 'General';

                    return GestureDetector(
                      onTap: () => _openPhotoViewer(context, item, isMatched: false),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: Image.network(
                                url,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: Colors.grey.shade200,
                                  child: const Icon(Icons.broken_image, color: Colors.grey),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.65),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  album,
                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                ),
                                child: Text(
                                  caption,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ----------------------------------------------------
// CHAT & CONVERSATION SCREEN
// ----------------------------------------------------
class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext c) => SafeArea(
        top: false,
        child: Column(
          children: [
            const Header(title: 'Messages & Support'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  CardButton(
                    icon: Icons.contact_support,
                    iconColor: maroon,
                    title: 'Need Help?',
                    subtitle: 'Conference Help Desk & Support • Active now at Hotel Sayaji',
                    onTap: () => Navigator.push(
                      c,
                      MaterialPageRoute(
                        builder: (_) => const AppShell(child: ConversationScreen()),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  CardButton(
                    icon: Icons.support_agent,
                    iconColor: maroon,
                    title: 'Delegate Help Desk & Transport Control',
                    subtitle: 'Lobby Counter #1 • Dial 0231 2555555',
                    onTap: () => Navigator.push(
                      c,
                      MaterialPageRoute(
                        builder: (_) => const AppShell(child: ConversationScreen()),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Center(
                    child: Text(
                      'Live Conference Helpdesk & Support Active',
                      style: TextStyle(color: muted, fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class ConversationScreen extends StatefulWidget {
  const ConversationScreen({super.key});
  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<dynamic> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    try {
      final res = await ApiService.get('/chat/messages');
      if (mounted) {
        setState(() {
          if (res is Map && res['messages'] is List) {
            _messages = List.from(res['messages']);
          }
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (_messages.isEmpty) {
            _messages = [
              {
                'body': 'Welcome to MAPCON 2026! How can I assist you with sessions, accommodation, photo gallery, or certificates today?',
                'is_me': false,
                'created_at': DateTime.now().toIso8601String(),
              }
            ];
          }
        });
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage([String? presetText]) async {
    final text = (presetText ?? _controller.text).trim();
    if (text.isEmpty || _isSending) return;

    if (presetText == null) {
      _controller.clear();
    }

    setState(() {
      _isSending = true;
      _messages.add({
        'body': text,
        'is_me': true,
        'created_at': DateTime.now().toIso8601String(),
      });
    });
    _scrollToBottom();

    try {
      final res = await ApiService.post('/chat/messages', {
        'body': text,
        'conferenceId': 1,
      });

      if (mounted) {
        setState(() {
          _isSending = false;
          if (res is Map && res['messages'] is List) {
            _messages = List.from(res['messages']);
          }
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSending = false;
          _messages.add({
            'body': 'Thank you! Your note has been received by the MAPCON Helpdesk.',
            'is_me': false,
            'created_at': DateTime.now().toIso8601String(),
          });
        });
        _scrollToBottom();
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: const CircleAvatar(
                  radius: 16,
                  backgroundColor: gold,
                  child: Icon(Icons.help_outline_rounded, color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Need Help?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5)),
                    Text('Conference Help Desk • Active Support', style: TextStyle(fontSize: 11, color: Colors.white70)),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: maroon,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: Column(
          children: [
            // Suggestion Chips
            Container(
              height: 46,
              color: const Color(0xFFF8FAFC),
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                children: [
                  _SuggestionChip('📅 Schedule', () => _sendMessage('What is the schedule for today?')),
                  _SuggestionChip('🏨 Hotel Sayaji', () => _sendMessage('Tell me about Hotel Sayaji and room info')),
                  _SuggestionChip('📸 Photo Gallery', () => _sendMessage('Where can I see the conference photo gallery?')),
                  _SuggestionChip('📜 Certificate', () => _sendMessage('How do I download my certificate?')),
                  _SuggestionChip('📍 Venue Map', () => _sendMessage('Where is the conference venue?')),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),

            // Messages List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: maroon))
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length + (_isSending ? 1 : 0),
                      itemBuilder: (c, i) {
                        if (i == _messages.length && _isSending) {
                          return Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: maroon),
                                  ),
                                  SizedBox(width: 8),
                                  Text('Liaison is typing...', style: TextStyle(color: muted, fontSize: 13)),
                                ],
                              ),
                            ),
                          );
                        }

                        final msg = _messages[i];
                        final isMe = msg['is_me'] == true || msg['is_me'] == 1;
                        final body = msg['body'] ?? '';

                        return Align(
                          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: isMe ? maroon : Colors.white,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(16),
                                topRight: const Radius.circular(16),
                                bottomLeft: Radius.circular(isMe ? 16 : 4),
                                bottomRight: Radius.circular(isMe ? 4 : 16),
                              ),
                              border: isMe ? null : Border.all(color: Colors.grey.shade200),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                              children: [
                                Text(
                                  body,
                                  style: TextStyle(
                                    color: isMe ? Colors.white : slate,
                                    fontSize: 14,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // Input Bar
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: 'Ask a question or type a message...',
                        hintStyle: const TextStyle(color: muted, fontSize: 14),
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: maroon,
                    radius: 22,
                    child: IconButton(
                      onPressed: () => _sendMessage(),
                      icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _SuggestionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _SuggestionChip(this.label, this.onTap);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: slate)),
        backgroundColor: Colors.white,
        side: BorderSide(color: Colors.grey.shade300),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onPressed: onTap,
      ),
    );
  }
}

// ----------------------------------------------------
// PROFILE SCREEN
// ----------------------------------------------------
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isUpdatingPhoto = false;
  int _refreshKey = 0;

  @override
  void initState() {
    super.initState();
    RealtimeSyncService.instance.syncNotifier.addListener(_onSyncUpdate);
  }

  @override
  void dispose() {
    RealtimeSyncService.instance.syncNotifier.removeListener(_onSyncUpdate);
    super.dispose();
  }

  void _onSyncUpdate() {
    if (mounted) {
      setState(() => _refreshKey++);
    }
  }

  Future<dynamic> load() async {
    final res = await ApiService.get('/me/profile');
    if (res is Map && res['data'] is Map) {
      return Map<String, dynamic>.from(res['data'] as Map);
    }
    if (res is Map) {
      return Map<String, dynamic>.from(res);
    }
    return {};
  }

  String _formatPhotoUrl(dynamic raw) {
    if (raw == null) return '';
    final s = raw.toString().trim();
    if (s.isEmpty) return '';
    if (s.startsWith('http://') || s.startsWith('https://') || s.startsWith('data:image')) {
      return s;
    }
    final base = apiBaseUrl.replaceAll('/api', '');
    return s.startsWith('/') ? '$base$s' : '$base/$s';
  }

  Future<void> _changePhoto(ImageSource source) async {
    try {
      String? base64Image;

      if (source == ImageSource.camera && kIsWeb) {
        final captured = await captureWebcamSelfie(context);
        if (captured == null || captured.isEmpty) return;
        base64Image = captured;
      } else {
        final XFile? file = await _picker.pickImage(
          source: source,
          maxWidth: 800,
          maxHeight: 800,
          imageQuality: 85,
        );
        if (file == null) return;
        final bytes = await file.readAsBytes();
        base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      }

      setState(() => _isUpdatingPhoto = true);

      await ApiService.post('/me/photo', {
        'file': {
          'name': 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg',
          'dataUrl': base64Image,
        },
      });

      if (mounted) {
        setState(() {
          _isUpdatingPhoto = false;
          _refreshKey++;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile photo updated successfully!'), backgroundColor: maroon),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUpdatingPhoto = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(formatErrorMessage(e, 'Failed to update photo. Please try again.')),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Change Profile Photo',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: slate),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: maroon.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.camera_alt, color: maroon),
                ),
                title: const Text('Take Selfie with Camera', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _changePhoto(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: gold.withOpacity(0.15), shape: BoxShape.circle),
                  child: const Icon(Icons.photo_library, color: Colors.orange),
                ),
                title: const Text('Choose from Gallery / Files', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _changePhoto(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditProfileDialog(Map<dynamic, dynamic> current) {
    final nameCtrl = TextEditingController(text: current['name']?.toString() ?? '');
    final phoneCtrl = TextEditingController(text: current['phone']?.toString() ?? '');
    final designationCtrl = TextEditingController(text: current['designation']?.toString() ?? '');
    final universityCtrl = TextEditingController(text: current['university']?.toString() ?? '');
    final bloodGroupCtrl = TextEditingController(text: current['blood_group']?.toString() ?? '');
    final emergencyCtrl = TextEditingController(text: current['emergency_contact']?.toString() ?? '');
    final travelModeCtrl = TextEditingController(text: current['mode_of_travel']?.toString() ?? '');
    final flightCtrl = TextEditingController(text: current['flight_number']?.toString() ?? '');

    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Edit Delegate Profile',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: slate),
                    ),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: const Icon(Icons.person_outline, color: maroon),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Mobile Number',
                    prefixIcon: const Icon(Icons.phone_outlined, color: maroon),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: designationCtrl,
                  decoration: InputDecoration(
                    labelText: 'Designation',
                    prefixIcon: const Icon(Icons.work_outline, color: maroon),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: universityCtrl,
                  decoration: InputDecoration(
                    labelText: 'University / Institute',
                    prefixIcon: const Icon(Icons.account_balance_outlined, color: maroon),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bloodGroupCtrl,
                  decoration: InputDecoration(
                    labelText: 'Blood Group (e.g. O+, B+, A+)',
                    prefixIcon: const Icon(Icons.bloodtype_outlined, color: maroon),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emergencyCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Emergency Contact Phone',
                    prefixIcon: const Icon(Icons.contact_emergency_outlined, color: maroon),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: travelModeCtrl,
                  decoration: InputDecoration(
                    labelText: 'Travel Mode (e.g. Flight, Train, Car)',
                    prefixIcon: const Icon(Icons.flight_takeoff_outlined, color: maroon),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: flightCtrl,
                  decoration: InputDecoration(
                    labelText: 'Flight / Train Number',
                    prefixIcon: const Icon(Icons.directions_transit_outlined, color: maroon),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: maroon,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: isSaving
                        ? null
                        : () async {
                            setModalState(() => isSaving = true);
                            try {
                              await ApiService.put('/me/profile', {
                                'name': nameCtrl.text.trim(),
                                'phone': phoneCtrl.text.trim(),
                                'designation': designationCtrl.text.trim(),
                                'university': universityCtrl.text.trim(),
                                'blood_group': bloodGroupCtrl.text.trim(),
                                'emergency_contact': emergencyCtrl.text.trim(),
                                'mode_of_travel': travelModeCtrl.text.trim(),
                                'flight_number': flightCtrl.text.trim(),
                              });
                              if (mounted) {
                                Navigator.pop(ctx);
                                setState(() => _refreshKey++);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Profile updated successfully!'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            } catch (e) {
                              setModalState(() => isSaving = false);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(formatErrorMessage(e, 'Failed to update profile. Please try again.')),
                                    backgroundColor: Colors.red.shade700,
                                  ),
                                );
                              }
                            }
                          },
                    child: isSaving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Save Profile Changes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> logout() async {
    final p = await SharedPreferences.getInstance();
    await p.clear();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthGate()),
        (_) => false,
      );
    }
  }

  void _showChangePasswordDialog() {
    showDialog(
      context: context,
      builder: (ctx) => const ForcedPasswordChangeDialog(isForced: false),
    );
  }

  @override
  Widget build(BuildContext c) => SafeArea(
        top: false,
        child: Column(
          children: [
            const Header(title: 'My Delegate Profile'),
            Expanded(
              child: FutureBuilder(
                key: ValueKey(_refreshKey),
                future: load(),
                builder: (c, s) {
                  if (s.connectionState == ConnectionState.waiting && !_isUpdatingPhoto) {
                    return const Center(child: CircularProgressIndicator(color: maroon));
                  }
                  if (s.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.account_circle_outlined, size: 56, color: maroon),
                            const SizedBox(height: 12),
                            const Text(
                              'Delegate Profile',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: slate),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              s.error.toString().contains('401')
                                  ? 'Your session has expired. Please sign in again.'
                                  : 'Unable to load profile. Please check your connection.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 13, color: muted),
                            ),
                            const SizedBox(height: 18),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.refresh, size: 18),
                                  label: const Text('Retry'),
                                  onPressed: () => setState(() => _refreshKey++),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(backgroundColor: maroon, foregroundColor: Colors.white),
                                  icon: const Icon(Icons.login, size: 18),
                                  label: const Text('Sign In'),
                                  onPressed: logout,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  final x = s.data is Map ? s.data as Map : {};
                  final photoUrl = _formatPhotoUrl(x['photo']);

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 90),
                    children: [
                      Center(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: maroon, width: 3.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: maroon.withOpacity(0.2),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: CircleAvatar(
                                radius: 52,
                                backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                                backgroundColor: maroon.withOpacity(0.08),
                                child: photoUrl.isEmpty
                                    ? const Icon(Icons.person, size: 56, color: maroon)
                                    : null,
                              ),
                            ),
                            if (_isUpdatingPhoto)
                              Positioned.fill(
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.black45,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Center(
                                    child: CircularProgressIndicator(color: gold, strokeWidth: 3),
                                  ),
                                ),
                              ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: _showPhotoOptions,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: maroon,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2.5),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        x['name']?.toString() ?? 'Conference Delegate',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: slate),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        x['email']?.toString() ?? '',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: muted, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: maroon.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: maroon.withOpacity(0.2)),
                          ),
                          child: Text(
                            (x['role']?.toString() ?? 'DELEGATE').toUpperCase(),
                            style: const TextStyle(color: maroon, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: maroon,
                            side: const BorderSide(color: maroon, width: 1.2),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          label: const Text('Edit Profile Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          onPressed: () => _showEditProfileDialog(x),
                        ),
                      ),
                      const SizedBox(height: 18),
                      InfoSection(
                        title: 'BASIC INFORMATION',
                        items: {
                          'Role': x['role'],
                          'Mobile No': x['phone'],
                          'University': x['university'],
                          'Designation': x['designation'],
                          'Blood Group': x['blood_group'],
                          'Emergency Contact': x['emergency_contact'],
                          'Registration No': x['registration_no'],
                        },
                      ),
                      InfoSection(
                        title: 'ACCOMMODATION',
                        items: {
                          'Hotel': x['hotel_name'],
                          'Room': x['room_number'],
                          'Liaison': x['liaison_name'],
                          'Liaison Phone': x['liaison_phone'],
                        },
                      ),
                      InfoSection(
                        title: 'TRAVEL DETAILS',
                        items: {
                          'Mode of Travel': x['mode_of_travel'],
                          'Flight/Train No': x['flight_number'],
                          'Arrival Date': formatSessionDate(x['arrival_date']),
                          'Arrival Time': formatSingleTime(x['arrival_time']),
                          'Departure Date': formatSessionDate(x['departure_date']),
                          'Departure Time': formatSingleTime(x['departure_time']),
                        },
                      ),
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: maroon,
                          side: const BorderSide(color: maroon, width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _showChangePasswordDialog,
                        icon: const Icon(Icons.lock_reset, color: maroon),
                        label: const Text('Reset / Change Password', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red.shade700,
                          side: BorderSide(color: Colors.red.shade200),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: logout,
                        icon: const Icon(Icons.logout),
                        label: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      );
}

class InfoSection extends StatelessWidget {
  final String title;
  final Map<String, dynamic> items;

  const InfoSection({
    super.key,
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            letterSpacing: 1.2,
            color: muted,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Column(
            children: items.entries.map((entry) {
              return ListTile(
                dense: true,
                title: Text(entry.key, style: const TextStyle(fontSize: 13, color: muted, fontWeight: FontWeight.w600)),
                trailing: SizedBox(
                  width: 190,
                  child: Text(
                    '${entry.value ?? '—'}',
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800, color: slate, fontSize: 13.5),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 18),
      ],
    );
  }
}

// ----------------------------------------------------
// VENUE & DIRECTIONS SCREEN
// ----------------------------------------------------
class VenueDirectionsScreen extends StatelessWidget {
  const VenueDirectionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final conference = ConferenceScope.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            const Header(title: 'Venue & Directions'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                children: [
                  // 1. Venue Hero Card
                  Card(
                    elevation: 0,
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: Colors.grey.shade200, width: 1.2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Stack(
                          children: [
                            Image.network(
                              'https://images.unsplash.com/photo-1566073771259-6a8506099945?w=1200',
                              height: 190,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                height: 190,
                                color: conference.primaryColor.withOpacity(0.15),
                                child: Icon(Icons.location_city, size: 60, color: conference.primaryColor),
                              ),
                            ),
                            Positioned(
                              top: 12,
                              right: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.75),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: gold.withOpacity(0.8)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.verified, color: gold, size: 13),
                                    SizedBox(width: 4),
                                    Text(
                                      'Official Conference Venue',
                                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                conference.venueName,
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: slate),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.location_on, size: 18, color: maroon),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      '${conference.venueAddress}, ${conference.venueCity}, ${conference.venueState} - ${conference.venuePincode}',
                                      style: const TextStyle(fontSize: 13.5, color: slate, fontWeight: FontWeight.w600, height: 1.35),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: FilledButton.icon(
                                      style: FilledButton.styleFrom(
                                        backgroundColor: conference.primaryColor,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      icon: const Icon(Icons.directions, size: 18),
                                      label: const Text('Open in Google Maps', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      onPressed: () {
                                        final url = conference.mapUrl.trim().isNotEmpty ? conference.mapUrl.trim() : defaultMapUrl;
                                        launchUrl(
                                          Uri.parse(url),
                                          mode: LaunchMode.externalApplication,
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: slate,
                                      side: BorderSide(color: Colors.grey.shade300),
                                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    icon: const Icon(Icons.call, size: 18, color: Colors.green),
                                    label: const Text('Helpdesk', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    onPressed: () => launchUrl(Uri.parse('tel:${conference.venueContact}')),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  if (conference.directions.trim().isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Text(
                      'VENUE DIRECTIONS',
                      style: TextStyle(letterSpacing: 1.2, color: muted, fontWeight: FontWeight.w900, fontSize: 12.5),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.alt_route, color: Color(0xFF1D4ED8), size: 20),
                              const SizedBox(width: 8),
                              const Text(
                                'Directions & How to Reach',
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF1E3A8A)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            conference.directions,
                            style: const TextStyle(fontSize: 13.5, color: Color(0xFF1E40AF), height: 1.45),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------
// OTHER SCREENS
// ----------------------------------------------------
class AccommodationScreen extends StatelessWidget {
  const AccommodationScreen({super.key});
  @override
  Widget build(BuildContext c) => DetailApiPage(
        title: 'Your Accommodation',
        path: '/me/accommodation',
        icon: Icons.hotel,
        empty: 'No room assigned yet',
        fields: const ['hotel_name', 'room_number', 'room_type', 'address', 'check_in', 'check_out'],
      );
}

class TransportScreen extends StatelessWidget {
  const TransportScreen({super.key});
  @override
  Widget build(BuildContext c) => ListApiPage(
        title: 'Transport Details',
        path: '/me/transport',
        icon: Icons.directions_car,
        fields: const ['pickup_location', 'drop_location', 'pickup_time', 'vehicle_number', 'vehicle_type', 'driver_name', 'driver_phone', 'status'],
      );
}

class DutiesScreen extends StatelessWidget {
  const DutiesScreen({super.key});
  @override
  Widget build(BuildContext c) => ListApiPage(
        title: 'Duty Roster',
        path: '/me/duties',
        icon: Icons.assignment,
        fields: const ['title', 'location', 'duty_date', 'start_time', 'end_time', 'supervisor', 'status'],
      );
}


class DigitalIdScreen extends StatelessWidget {
  const DigitalIdScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final conference = ConferenceScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Digital Conference ID', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: maroon,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: FutureBuilder(
              future: ApiService.get('/me/registration'),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: maroon));
                }

                if (snapshot.hasError) {
                  return const Center(child: Text('Unable to load ID'));
                }

                final data = snapshot.data is Map ? snapshot.data as Map : <dynamic, dynamic>{};
                final qrData = data['qr_token'] ?? data['registration_no'] ?? 'DPU-AIU-DELEGATE-2026';

                return Card(
                  elevation: 6,
                  shadowColor: Colors.black.withOpacity(0.12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                    side: BorderSide(color: gold.withOpacity(0.4), width: 1.5),
                  ),
                  child: Column(
                    children: [
                      // Badge Header
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [maroon, darkMaroon],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: ClipOval(
                                child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    conference.shortName,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
                                  ),
                                  const Text(
                                    'OFFICIAL DELEGATE PASS',
                                    style: TextStyle(color: Color(0xFFFDE68A), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Badge Body
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Text(
                              '${data['participant_name'] ?? data['name'] ?? 'Dr. Rakesh Kumar Sharma'}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: slate),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${data['university'] ?? 'D. Y. Patil Vidyapeeth'}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: muted, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                              decoration: BoxDecoration(
                                color: gold.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: gold),
                              ),
                              child: Text(
                                '${data['category'] ?? 'DELEGATE'}',
                                style: const TextStyle(color: darkMaroon, fontWeight: FontWeight.w900, fontSize: 11.5, letterSpacing: 0.5),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: QrImageView(
                                data: qrData.toString(),
                                size: 180,
                                eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: maroon),
                                dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: slate),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Registration ID: ${data['registration_no'] ?? 'DPU-2026-001'}',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: slate),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class CertificateScreen extends StatefulWidget {
  const CertificateScreen({super.key});

  @override
  State<CertificateScreen> createState() => _CertificateScreenState();
}

class _CertificateScreenState extends State<CertificateScreen> {
  // Map of 17 question ratings (Key: 'q1'..'q17', Value: 1=Poor, 2=Fair, 3=Good, 4=Excellent)
  final Map<String, int> _ratings = {};
  
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _mmcController = TextEditingController();
  final TextEditingController _suggestionsController = TextEditingController();

  bool _isSubmitting = false;
  bool _isLoading = true;
  Map<String, dynamic>? _certData;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mmcController.dispose();
    _suggestionsController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final res = await ApiService.get('/me/certificate');
      if (res is Map && mounted) {
        setState(() {
          _certData = Map<String, dynamic>.from(res);
          final p = _certData?['participant'];
          if (p is Map) {
            _nameController.text = p['name'] ?? p['participant_name'] ?? '';
            _mmcController.text = p['mmc_reg_no'] ?? p['mmc_number'] ?? '';
          }
          _isLoading = false;
        });
        return;
      }
    } catch (_) {}
    if (mounted) {
      setState(() {
        _certData = _certData ?? {};
        _isLoading = false;
      });
    }
  }

  Future<void> _submitFeedbackAndGenerate() async {
    final missing = <int>[];
    for (int i = 1; i <= 17; i++) {
      if (!_ratings.containsKey('q$i') || _ratings['q$i'] == null || _ratings['q$i'] == 0) {
        missing.add(i);
      }
    }

    if (missing.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠️ Please answer all 17 evaluation questions before submitting (Missing: Q${missing.join(", Q")}).'),
          backgroundColor: const Color(0xFFDC2626),
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final payload = {
      'delegateName': _nameController.text.trim(),
      'mmcNumber': _mmcController.text.trim(),
      'topicClearRelevant': _ratings['q1'],
      'contentAcademicDepth': _ratings['q2'],
      'speakerClarity': _ratings['q3'],
      'slidesClearUnderstandable': _ratings['q4'],
      'relevanceClinicalPractice': _ratings['q5'],
      'contentUpToDate': _ratings['q6'],
      'sessionWithinTime': _ratings['q7'],
      'discussionTimeProvided': _ratings['q8'],
      'questionsAddressedSatisfactorily': _ratings['q9'],
      'preConfInfoTimely': _ratings['q10'],
      'digitalCommunicationAccess': _ratings['q11'],
      'registrationSmoothEfficient': _ratings['q12'],
      'sessionsOnTime': _ratings['q13'],
      'venueComfortableOrganized': _ratings['q14'],
      'audiovisualFacilitiesSatisfactory': _ratings['q15'],
      'foodBeverageSatisfactory': _ratings['q16'],
      'committeeSupportHelpful': _ratings['q17'],
      'q1': _ratings['q1'],
      'q2': _ratings['q2'],
      'q3': _ratings['q3'],
      'q4': _ratings['q4'],
      'q5': _ratings['q5'],
      'q6': _ratings['q6'],
      'q7': _ratings['q7'],
      'q8': _ratings['q8'],
      'q9': _ratings['q9'],
      'q10': _ratings['q10'],
      'q11': _ratings['q11'],
      'q12': _ratings['q12'],
      'q13': _ratings['q13'],
      'q14': _ratings['q14'],
      'q15': _ratings['q15'],
      'q16': _ratings['q16'],
      'q17': _ratings['q17'],
      'suggestions': _suggestionsController.text.trim(),
      'comment': _suggestionsController.text.trim(),
    };

    try {
      dynamic res;
      try {
        res = await ApiService.post('/me/feedback-and-certificate', payload);
      } catch (_) {
        res = await ApiService.post('/me/feedback', payload);
      }

      await _loadInitialData();

      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Feedback recorded! Your verified Certificate of Participation is now ready for download.'),
            backgroundColor: Color(0xFF1E3A8A),
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Submission failed: ${e.toString().replaceAll("Exception: ", "")}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _certData == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text('MAPCON-2026 Feedback Form', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 17)),
          backgroundColor: const Color(0xFF1E3A8A),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(child: CircularProgressIndicator(color: Color(0xFF1E3A8A))),
      );
    }

    final data = _certData ?? {};
    final bool hasFeedback = data['hasFeedback'] == true || data['feedback_submitted'] == true;
    final cert = data['certificate'] is Map
        ? data['certificate'] as Map
        : (data.containsKey('certificate_url') ? data : null);
    final certUrl = cert?['certificate_url']?.toString();
    final fullImageUrl = certUrl != null ? resolveMediaUrl(certUrl) : null;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(
          (!hasFeedback || cert == null || fullImageUrl == null) ? 'Delegate Feedback Form' : 'Verified E-Certificate',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 17),
        ),
        backgroundColor: const Color(0xFF1E3A8A),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: (!hasFeedback || cert == null || fullImageUrl == null)
          ? _buildFeedbackUnlockView(data['participant'])
          : _buildUnlockedCertificateView(cert, fullImageUrl),
    );
  }

  Widget _buildFeedbackUnlockView(dynamic participant) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      children: [
        // Paper Form Shell
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Conference & Form Header
              const Text(
                '47th Annual Conference of Maharashtra Chapter',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1E3A8A),
                ),
              ),
              const SizedBox(height: 3),
              const Text(
                'MAPCON-2026 held on 2/3/4 October- 2026',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E3A8A),
                ),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  'FEEDBACK FORM',
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1E3A8A),
                    decoration: TextDecoration.underline,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Delegate Info Fields
              _buildDelegateInfoRow('Delegate Name:', _nameController, 'Dr. / Delegate Name'),
              const SizedBox(height: 10),
              _buildDelegateInfoRow('MMC Registration / State Registration:', _mmcController, 'MMC-12345 / State Reg No'),
              const SizedBox(height: 14),

              // Rating Scale Legend
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: const Text(
                  'Rating Scale:  1 = Poor  |  2 = Fair  |  3 = Good  |  4 = Excellent',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E3A8A),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // SECTION A: SCIENTIFIC PROGRAM
              const Text(
                'Section A: Scientific Program',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 10),

              _buildEvaluationTable(
                categories: [
                  _EvaluationCategory(
                    title: '1. TOPIC EVALUATION',
                    questions: [
                      _EvaluationQuestion('q1', 'Was the topic clear and relevant to the session objectives?'),
                      _EvaluationQuestion('q2', 'Was the content covered with appropriate academic/clinical depth?'),
                    ],
                  ),
                  _EvaluationCategory(
                    title: '2. SPEAKER EVALUATION',
                    questions: [
                      _EvaluationQuestion('q3', 'Did the speaker explain the topic clearly?'),
                    ],
                  ),
                  _EvaluationCategory(
                    title: '3. PRESENTATION QUALITY',
                    questions: [
                      _EvaluationQuestion('q4', 'Were the slides clear and easy to understand?'),
                    ],
                  ),
                  _EvaluationCategory(
                    title: '4. RELEVANCE AND APPLICABLITY',
                    questions: [
                      _EvaluationQuestion('q5', 'Was the content relevant to clinical practice and professional work?'),
                      _EvaluationQuestion('q6', 'Was the content up to date with current practices and advancements?'),
                    ],
                  ),
                  _EvaluationCategory(
                    title: '5. TIME TAKEN AND PACING',
                    questions: [
                      _EvaluationQuestion('q7', 'Was the session conducted within the scheduled time?'),
                    ],
                  ),
                  _EvaluationCategory(
                    title: '6. Q&A SESSION AND INTERACTION',
                    questions: [
                      _EvaluationQuestion('q8', 'Was sufficient time provided for discussion and questions?'),
                      _EvaluationQuestion('q9', 'Were audience questions addressed satisfactorily?'),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // SECTION B: OVERALL CONFERENCE FEEDBACK FORM
              const Text(
                'Section B: Overall Conference Feedback Form',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                  decoration: TextDecoration.underline,
                ),
              ),
              const SizedBox(height: 10),

              _buildEvaluationTable(
                categories: [
                  _EvaluationCategory(
                    title: '1. LOGISTICS & EVENT ADMINISTRATION',
                    questions: [
                      _EvaluationQuestion('q10', 'Was the pre-conference information clear and timely?'),
                      _EvaluationQuestion('q11', 'Was the digital communication easy to access and use?'),
                      _EvaluationQuestion('q12', 'Was the registration process smooth and efficient?'),
                      _EvaluationQuestion('q13', 'Were the sessions and activities conducted on time?'),
                    ],
                  ),
                  _EvaluationCategory(
                    title: '2. VENUE, INFRASTRUCTURE & HOSPITALITY',
                    questions: [
                      _EvaluationQuestion('q14', 'Was the venue comfortable and well organized?'),
                      _EvaluationQuestion('q15', 'Were the audio-visual facilities satisfactory?'),
                      _EvaluationQuestion('q16', 'Was the food and beverage service satisfactory?'),
                      _EvaluationQuestion('q17', 'Was the support from the organizing committee helpful?'),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 22),

              // General Feedback & Recommendations
              const Text(
                'General Feedback & Recommendations if any:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E3A8A),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _suggestionsController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Enter your suggestions, appreciation, or recommendations...',
                  hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF1E3A8A), width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Note & Sign-off
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('⚠️ ', style: TextStyle(fontSize: 14)),
                    Expanded(
                      child: Text(
                        'Note: Submission of the post-conference feedback form is a prerequisite for receiving the e-certificate.',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF991B1B),
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              const Text(
                'Thank you for your valuable presence and support in making MAPCON 2026 a memorable success.\n\n'
                'MAPCON 2026 Organizing Committee\n'
                'Department of Pathology, D. Y. Patil Medical College, Kolhapur',
                style: TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF475569),
                  height: 1.45,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 24),

              // Submit Button
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 4,
                ),
                icon: _isSubmitting
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.verified_rounded, color: Color(0xFFFDE047), size: 22),
                label: Text(
                  _isSubmitting ? 'Submitting & Unlocking Certificate...' : 'Submit Feedback & Unlock Certificate',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                ),
                onPressed: _isSubmitting ? null : _submitFeedbackAndGenerate,
              ),
            ],
          ),
        ),
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildDelegateInfoRow(String label, TextEditingController controller, String placeholder) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1E3A8A),
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF1E3A8A), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEvaluationTable({required List<_EvaluationCategory> categories}) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF1A365D), width: 1.2),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Table Header
          Container(
            color: const Color(0xFF1A365D),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: const Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Text(
                    'Evaluation Domain',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    '1\nPoor',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold, height: 1.1),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    '2\nFair',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold, height: 1.1),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    '3\nGood',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold, height: 1.1),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    '4\nExcellent',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold, height: 1.1),
                  ),
                ),
              ],
            ),
          ),

          // Categories & Rows
          for (final cat in categories) ...[
            // Category Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              color: const Color(0xFFF1F5F9),
              child: Text(
                cat.title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                  letterSpacing: 0.3,
                ),
              ),
            ),
            const Divider(height: 1, color: Color(0xFFCBD5E1)),

            // Questions in Category
            for (int qIdx = 0; qIdx < cat.questions.length; qIdx++) ...[
              _buildQuestionRow(cat.questions[qIdx]),
              if (qIdx < cat.questions.length - 1)
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
            ],
            const Divider(height: 1, color: Color(0xFFCBD5E1)),
          ],
        ],
      ),
    );
  }

  Widget _buildQuestionRow(_EvaluationQuestion q) {
    final selectedRating = _ratings[q.id] ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      color: selectedRating > 0 ? const Color(0xFFF8FAFC) : Colors.white,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Question Text
          Expanded(
            flex: 5,
            child: Text(
              q.text,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
                height: 1.3,
              ),
            ),
          ),

          // Checkbox Column 1 (Poor)
          Expanded(
            flex: 1,
            child: _buildCheckboxRatingCell(q.id, 1, selectedRating == 1),
          ),

          // Checkbox Column 2 (Fair)
          Expanded(
            flex: 1,
            child: _buildCheckboxRatingCell(q.id, 2, selectedRating == 2),
          ),

          // Checkbox Column 3 (Good)
          Expanded(
            flex: 1,
            child: _buildCheckboxRatingCell(q.id, 3, selectedRating == 3),
          ),

          // Checkbox Column 4 (Excellent)
          Expanded(
            flex: 1,
            child: _buildCheckboxRatingCell(q.id, 4, selectedRating == 4),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckboxRatingCell(String questionId, int value, bool isSelected) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() {
          _ratings[questionId] = value;
        });
      },
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF1E3A8A) : Colors.white,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: isSelected ? const Color(0xFF1E3A8A) : const Color(0xFF64748B),
              width: 1.6,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF1E3A8A).withOpacity(0.25),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    )
                  ]
                : null,
          ),
          child: isSelected
              ? const Icon(
                  Icons.check_rounded,
                  size: 16,
                  color: Colors.white,
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildUnlockedCertificateView(Map cert, String fullImageUrl) {
    final certificateNo = cert['certificate_no']?.toString() ?? '—';
    final issuedAt = cert['issued_at']?.toString() ?? '—';

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFECFDF5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF10B981), width: 1.2),
          ),
          child: const Row(
            children: [
              Icon(Icons.verified_rounded, color: Color(0xFF047857), size: 24),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Certificate Verified & Issued', style: TextStyle(color: Color(0xFF065F46), fontWeight: FontWeight.w900, fontSize: 13.5)),
                    Text('Feedback submitted. Ready for download.', style: TextStyle(color: Color(0xFF047857), fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Card(
          elevation: 6,
          shadowColor: maroon.withOpacity(0.2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: gold, width: 1.5)),
          clipBehavior: Clip.antiAlias,
          child: Image.network(
            fullImageUrl,
            fit: BoxFit.contain,
            errorBuilder: (context, _, __) => Container(height: 250, color: Colors.grey.shade100, child: const Icon(Icons.error_outline, size: 40, color: Colors.red)),
          ),
        ),
        const SizedBox(height: 20),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: Colors.grey.shade200, width: 1.2)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                ListTile(
                  leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: maroon.withOpacity(0.08), shape: BoxShape.circle), child: const Icon(Icons.workspace_premium, color: maroon, size: 22)),
                  title: const Text('CERTIFICATE NUMBER', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: muted)),
                  subtitle: Text(certificateNo, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5, color: slate)),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: maroon.withOpacity(0.08), shape: BoxShape.circle), child: const Icon(Icons.calendar_month, color: maroon, size: 22)),
                  title: const Text('DATE OF ISSUANCE', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: muted)),
                  subtitle: Text(issuedAt.contains('T') || issuedAt.contains('-') ? formatSessionDate(issuedAt) : issuedAt, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: slate)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: maroon,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          icon: const Icon(Icons.download_rounded, size: 22, color: gold),
          label: const Text('Download High-Res Certificate', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
          onPressed: () async {
            final uri = Uri.parse(fullImageUrl);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            } else {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open download link')));
            }
          },
        ),
      ],
    );
  }
}

class _EvaluationCategory {
  final String title;
  final List<_EvaluationQuestion> questions;
  const _EvaluationCategory({required this.title, required this.questions});
}

class _EvaluationQuestion {
  final String id;
  final String text;
  const _EvaluationQuestion(this.id, this.text);
}

class EmergencyScreen extends StatelessWidget {
  const EmergencyScreen({super.key});

  @override
  Widget build(BuildContext c) {
    final conference = ConferenceScope.of(c);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency & Help Contacts', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: maroon,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          CardButton(
            icon: Icons.support_agent,
            title: 'Conference Help Desk',
            subtitle: '1800123456 • 24x7 Assistance',
            onTap: () => launchUrl(Uri.parse('tel:1800123456')),
          ),
          CardButton(
            icon: Icons.local_hospital,
            title: 'Medical Emergency & Ambulance',
            subtitle: 'Call 108 • On-campus medical unit',
            onTap: () => launchUrl(Uri.parse('tel:108')),
          ),
        ],
      ),
    );
  }
}

class DetailApiPage extends StatelessWidget {
  final String title;
  final String path;
  final String empty;
  final IconData icon;
  final List<String> fields;

  const DetailApiPage({
    super.key,
    required this.title,
    required this.path,
    required this.icon,
    required this.empty,
    required this.fields,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: maroon,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder(
        future: ApiService.get(path),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: maroon));
          }

          if (snapshot.hasError) {
            return const Center(child: Text('Unable to load details'));
          }

          final data = snapshot.data is Map ? snapshot.data as Map : <dynamic, dynamic>{};
          if (data.isEmpty) {
            return Center(
              child: Text(empty, style: const TextStyle(color: muted, fontSize: 16)),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(color: Colors.grey.shade200, width: 1.2),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: fields.map((field) {
                      dynamic rawVal = data[field];
                      String displayVal = rawVal?.toString() ?? '—';
                      if (field.contains('time')) displayVal = formatSingleTime(rawVal);
                      if (field.contains('date')) displayVal = formatSessionDate(rawVal);

                      return ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: maroon.withOpacity(0.08),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icon, color: maroon, size: 20),
                        ),
                        title: Text(
                          field.replaceAll('_', ' ').toUpperCase(),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: muted),
                        ),
                        subtitle: Text(
                          displayVal,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: slate),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class ListApiPage extends StatelessWidget {
  final String title, path;
  final IconData icon;
  final List<String> fields;

  const ListApiPage({
    super.key,
    required this.title,
    required this.path,
    required this.icon,
    required this.fields,
  });

  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: maroon,
          foregroundColor: Colors.white,
        ),
        body: FutureBuilder(
          future: ApiService.get(path),
          builder: (c, s) {
            if (s.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: maroon));
            }
            if (s.hasError) {
              return const Center(child: Text('Unable to load details'));
            }
            final d = s.data is List ? s.data as List : [];
            if (d.isEmpty) {
              return const Center(child: Text('No records found', style: TextStyle(color: muted)));
            }

            return ListView.builder(
              padding: const EdgeInsets.all(18),
              itemCount: d.length,
              itemBuilder: (c, i) => Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(color: Colors.grey.shade200, width: 1.2),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: fields.map((f) {
                      dynamic rawVal = d[i][f];
                      String displayVal = rawVal?.toString() ?? '—';
                      if (f.contains('time')) displayVal = formatSingleTime(rawVal);
                      if (f.contains('date')) displayVal = formatSessionDate(rawVal);

                      return ListTile(
                        dense: true,
                        leading: Icon(icon, color: maroon, size: 20),
                        title: Text(
                          f.replaceAll('_', ' ').toUpperCase(),
                          style: const TextStyle(fontSize: 11.5, color: muted, fontWeight: FontWeight.bold),
                        ),
                        trailing: SizedBox(
                          width: 190,
                          child: Text(
                            displayVal,
                            textAlign: TextAlign.right,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800, color: slate, fontSize: 13),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            );
          },
        ),
      );
}

// ====================================================
// TRAVEL, LOCAL EXCURSIONS & TOURIST GUIDE (KOLHAPUR)
// ====================================================

class TravelGuideScreen extends StatefulWidget {
  const TravelGuideScreen({super.key});

  @override
  State<TravelGuideScreen> createState() => _TravelGuideScreenState();
}

class _TravelGuideScreenState extends State<TravelGuideScreen> {
  String _selectedCategory = 'ALL';
  String _searchQuery = '';

  static const List<Map<String, dynamic>> _places = [
    // ---------------- SIGHTSEEING & ATTRACTIONS ----------------
    {
      'name': 'Shree Mahalaxmi Temple',
      'category': 'SIGHTSEEING',
      'tag': 'Hindu Temple',
      'rating': '4.8',
      'status': 'Open',
      'distance': '~2.5 km from Sayaji Hotel',
      'travel_time': '10–12 min drive',
      'transport': 'Auto-rickshaw/taxi (~₹50–₹150), shared KMT bus, or two-wheeler rental.',
      'speciality': 'One of Kolhapur\'s most revered temples dedicated to Goddess Mahalaxmi; excellent Dravidian temple architecture and vibrant daily aarti. High footfall during Navaratri and weekends.',
      'maps_query': 'Shree Mahalaxmi Temple Kolhapur',
      'icon': Icons.temple_hindu_rounded,
      'color': Color(0xFF8C1119),
    },
    {
      'name': 'Rankala Lake',
      'category': 'SIGHTSEEING',
      'tag': 'Tourist Attraction',
      'rating': '4.5',
      'status': 'Open',
      'distance': '~3 km from Sayaji Hotel',
      'travel_time': '10–15 min drive',
      'transport': 'Autos/taxis, local buses (KMT) or bicycle rentals.',
      'speciality': 'Scenic urban lake with walking paths, boating, evening lights, street snacks, and sunset views over the water—great for leisure evenings.',
      'maps_query': 'Rankala Lake Kolhapur',
      'icon': Icons.water_rounded,
      'color': Color(0xFF2E6F95),
    },
    {
      'name': 'New Palace (Shri Chhatrapati Shahu Museum)',
      'category': 'SIGHTSEEING',
      'tag': 'Historical Landmark',
      'rating': '4.5',
      'status': 'Open',
      'distance': '~4 km from Sayaji Hotel',
      'travel_time': '12–15 min drive',
      'transport': 'Auto / Taxi / City Bus',
      'speciality': 'Grand heritage palace with a museum housing royal armour, weapons, paintings, taxidermy, and personal belongings of Kolhapur royalty.',
      'maps_query': 'New Palace Museum Kolhapur',
      'icon': Icons.castle_rounded,
      'color': Color(0xFFC8A45A),
    },
    {
      'name': 'Khasbag Maidan',
      'category': 'SIGHTSEEING',
      'tag': 'Wrestling Ground (Kushti)',
      'rating': '4.5',
      'status': 'Open',
      'distance': '~4 km from Sayaji Hotel',
      'travel_time': '12–15 min drive',
      'transport': 'Short auto/taxi trip, local bus',
      'speciality': 'One of India\'s largest traditional wrestling grounds and cultural landmark where historic Kushti (wrestling) events and training take place.',
      'maps_query': 'Khasbag Maidan Kolhapur',
      'icon': Icons.sports_kabaddi_rounded,
      'color': Color(0xFFD97706),
    },
    {
      'name': 'Mirajkar Tikti Dudh Katta',
      'category': 'SIGHTSEEING',
      'tag': 'Cultural Chill-Spot',
      'rating': '4.6',
      'status': 'Open',
      'distance': '~2.5–3 km from Sayaji Hotel',
      'travel_time': '8–10 min drive',
      'transport': 'Auto/rickshaw',
      'speciality': 'Local favourite evening chill-spot dairy café with regional milk refreshments, basundi, flavoured milk and lively city banter.',
      'maps_query': 'Mirajkar Tikti Kolhapur',
      'icon': Icons.local_cafe_rounded,
      'color': Color(0xFF059669),
    },
    {
      'name': 'Panhala Fort (Must Visit)',
      'category': 'SIGHTSEEING',
      'tag': 'Historic Hill Fort',
      'rating': '4.9',
      'status': 'Must Visit',
      'distance': '~20–22 km from Sayaji Hotel',
      'travel_time': '35–45 minutes by car',
      'transport': 'Private car / self-drive (best option), Taxi (~₹800–₹1500 approx round trip), MSRTC bus from Kolhapur CBS, or scenic bike ride.',
      'speciality': 'Historic hill fort associated with Chhatrapati Shivaji Maharaj. Features cool hill-station climate, Sajja Kothi, Andhar Bavadi, Teen Darwaza, and panoramic Sahyadri views. Best time: Morning or late afternoon.',
      'maps_query': 'Panhala Fort Kolhapur',
      'icon': Icons.fort_rounded,
      'color': Color(0xFF8C1119),
    },
    {
      'name': 'Bahubali (Kumbhojgiri) Temple',
      'category': 'SIGHTSEEING',
      'tag': 'Jain Pilgrimage',
      'rating': '4.7',
      'status': 'Open',
      'distance': '~27–30 km from Sayaji Hotel',
      'travel_time': '45–60 minutes by car',
      'transport': 'Private car / self-drive (best), Taxi (~₹1200–₹2000 round trip), MSRTC bus towards Kumbhoj, or scenic bike ride.',
      'speciality': 'Sacred Jain pilgrimage site located on a hill at Kumbhoj. Features a massive 28-foot statue of Lord Bahubali, peaceful spiritual atmosphere, and 400+ steps to the top. Best visited early morning or evening.',
      'maps_query': 'Bahubali Kumbhoj Temple',
      'icon': Icons.account_balance_rounded,
      'color': Color(0xFF4B5563),
    },
    {
      'name': 'Kopeshwar Temple (Khidrapur)',
      'category': 'SIGHTSEEING',
      'tag': 'Architectural Marvel',
      'rating': '4.8',
      'status': 'Open',
      'distance': '~60–65 km from Sayaji Hotel',
      'travel_time': '1.5–2 hours by car',
      'transport': 'Private car / taxi (best option for comfort), MSRTC bus towards Shirol / Khidrapur, or long scenic rural bike trip.',
      'speciality': 'Ancient Kopeshwar Temple dedicated to Lord Shiva with stunning Hemadpanthi architecture, intricately carved stone pillars, unique circular Swarg Mandap structure without roof, situated near the Krishna River.',
      'maps_query': 'Kopeshwar Temple Khidrapur',
      'icon': Icons.temple_buddhist_rounded,
      'color': Color(0xFF8C1119),
    },
    {
      'name': 'Gaganbawada',
      'category': 'SIGHTSEEING',
      'tag': 'Scenic Hill Station',
      'rating': '4.7',
      'status': 'Open',
      'distance': '~55 km from Sayaji Hotel',
      'travel_time': '1.5 hours by car',
      'transport': 'Taxi (~₹1500–₹2500 round trip), private car/bike ride; limited MSRTC buses available.',
      'speciality': 'Scenic hill station known for lush green valleys, misty weather, breathtaking viewpoints, sunset vistas, nearby waterfalls, and the historic Gaganbawada Fort.',
      'maps_query': 'Gaganbawada Kolhapur',
      'icon': Icons.landscape_rounded,
      'color': Color(0xFF047857),
    },

    // ---------------- ICONIC KOLHAPURI CUISINE ----------------
    {
      'name': 'PHADTARE MISAL CENTER',
      'category': 'FOOD',
      'tag': 'Iconic Kolhapuri Misal',
      'rating': '4.8',
      'status': 'Breakfast / Lunch',
      'distance': '~2.0–2.5 km from Sayaji Hotel',
      'travel_time': '6–8 min drive',
      'transport': 'Auto / Taxi (Shivaji Udyam Nagar / Mangalwar Peth)',
      'speciality': 'Classic Kolhapuri misal spot with fiery local flavours, crunchy farsan, rassa and soft pav served with authentic chutneys.',
      'maps_query': 'Phadtare Misal Center Kolhapur',
      'icon': Icons.local_fire_department_rounded,
      'color': Color(0xFFDC2626),
    },
    {
      'name': 'DEHAATI',
      'category': 'FOOD',
      'tag': 'Authentic Kolhapuri Thali',
      'rating': '4.8',
      'status': 'Lunch / Dinner',
      'distance': '~0.5 km from Sayaji Hotel',
      'travel_time': '2–5 min walk / drive',
      'transport': 'Walking distance from Hotel Sayaji (Tararani Chowk on Old Pune-Bangalore Hwy)',
      'speciality': 'World-famous authentic Kolhapuri Mutton & Chicken Thalis served with freshly prepared Tambda & Pandhra Rassa, Sukka, and Bhakri.',
      'maps_query': 'Dehaati Restaurant Kolhapur',
      'icon': Icons.restaurant_rounded,
      'color': Color(0xFF8C1119),
    },
    {
      'name': 'Patlacha Wada',
      'category': 'FOOD',
      'tag': 'Traditional Non-Veg Thali',
      'rating': '4.7',
      'status': 'Lunch / Dinner',
      'distance': '~3.5 km from Sayaji Hotel',
      'travel_time': '10 min drive',
      'transport': 'Auto / Taxi',
      'speciality': 'Famous for authentic Kolhapuri thalis with Tambda Rassa, Pandhra Rassa, Mutton Sukka and rural royal ambiance.',
      'maps_query': 'Patlacha Wada Kolhapur',
      'icon': Icons.restaurant_rounded,
      'color': Color(0xFFB45309),
    },
    {
      'name': 'The Thalis Kolhapuri Thali',
      'category': 'FOOD',
      'tag': 'Speciality Non-Veg',
      'rating': '4.6',
      'status': 'Lunch / Dinner',
      'distance': '~3.0 km from Sayaji Hotel',
      'travel_time': '8–10 min drive',
      'transport': 'Auto / Taxi',
      'speciality': 'Fantastic non-veg thalis with rich Kolhapuri spices, authentic gravies, and succulent chicken and mutton preparations.',
      'maps_query': 'The Thalis Kolhapuri Thali Kolhapur',
      'icon': Icons.dinner_dining_rounded,
      'color': Color(0xFF991B1B),
    },
    {
      'name': 'Hotel Parakh',
      'category': 'FOOD',
      'tag': 'Heritage Dining',
      'rating': '4.7',
      'status': 'Lunch / Dinner',
      'distance': '~2.8 km from Sayaji Hotel',
      'travel_time': '8 min drive',
      'transport': 'Auto / Taxi',
      'speciality': 'Classic heritage Kolhapuri restaurant famous for legendary Pandhra Rassa, aromatic curries, and traditional hospitality loved by locals.',
      'maps_query': 'Hotel Parakh Kolhapur',
      'icon': Icons.restaurant_menu_rounded,
      'color': Color(0xFF7C2D12),
    },
    {
      'name': 'Bawada Misal',
      'category': 'FOOD',
      'tag': 'Breakfast & Street Food',
      'rating': '4.6',
      'status': 'Morning / Lunch',
      'distance': '~4.5 km from Sayaji Hotel',
      'travel_time': '12 min drive',
      'transport': 'Auto / Taxi / City Bus',
      'speciality': 'A must-visit for Kolhapuri Misal Pav with unique local flavours and spicy kat, serving foodies since decades.',
      'maps_query': 'Bawada Misal Kolhapur',
      'icon': Icons.soup_kitchen_rounded,
      'color': Color(0xFFEA580C),
    },
    {
      'name': 'Basalt | Pure Veg Fine Dine',
      'category': 'FOOD',
      'tag': 'Pure Vegetarian Fine Dine',
      'rating': '4.7',
      'status': 'Lunch / Dinner',
      'distance': '~2.5 km from Sayaji Hotel',
      'travel_time': '7 min drive',
      'transport': 'Auto / Taxi',
      'speciality': 'Upscale pure-vegetarian fine dining restaurant with premium ambiance, multi-cuisine offerings, and curated Maharashtrian specialties.',
      'maps_query': 'Basalt Veg Restaurant Kolhapur',
      'icon': Icons.eco_rounded,
      'color': Color(0xFF047857),
    },
    {
      'name': 'Bansuri Pure Veg Restaurant',
      'category': 'FOOD',
      'tag': 'Vegetarian Thalis',
      'rating': '4.5',
      'status': 'Lunch / Dinner',
      'distance': '~2.0 km from Sayaji Hotel',
      'travel_time': '6 min drive',
      'transport': 'Auto / Taxi',
      'speciality': 'Great for family veg dining including royal veg thalis, paneer delicacies, and traditional Maharashtrian preparations.',
      'maps_query': 'Bansuri Pure Veg Restaurant Kolhapur',
      'icon': Icons.local_florist_rounded,
      'color': Color(0xFF10B981),
    },
    {
      'name': 'Moon Tree Cafe & Lounge',
      'category': 'FOOD',
      'tag': 'Cafe & Fusion Dining',
      'rating': '4.6',
      'status': 'All Day',
      'distance': '~3.2 km from Sayaji Hotel',
      'travel_time': '10 min drive',
      'transport': 'Auto / Taxi',
      'speciality': 'Charming café serving continental fusion food, specialty coffees, wood-fired pizzas, and artisan desserts.',
      'maps_query': 'Moon Tree Cafe Kolhapur',
      'icon': Icons.coffee_rounded,
      'color': Color(0xFF4B5563),
    },
    {
      'name': 'Sharawati - Taste of Karavali',
      'category': 'FOOD',
      'tag': 'Coastal & Seafood',
      'rating': '4.6',
      'status': 'Lunch / Dinner',
      'distance': '~3.0 km from Sayaji Hotel',
      'travel_time': '8–10 min drive',
      'transport': 'Auto / Taxi',
      'speciality': 'Renowned for authentic coastal seafood, fish thalis, neer dosa, and regional Karavali delicacies.',
      'maps_query': 'Sharawati Restaurant Kolhapur',
      'icon': Icons.set_meal_rounded,
      'color': Color(0xFF0284C7),
    },

    // ---------------- COLD DRINKS & LASSI ----------------
    {
      'name': 'Imperial Cold Drink House',
      'category': 'DESSERT',
      'tag': 'Ice Cream & Mastani',
      'rating': '4.8',
      'status': 'Cold Drinks & Desserts',
      'distance': '~2.0–2.8 km from Sayaji Hotel (Rajarampuri)',
      'travel_time': '7–10 min drive',
      'transport': 'Auto / Taxi towards Rajarampuri',
      'speciality': 'One of Kolhapur\'s legendary ice-cream & cold-drink parlours famous for rich mango mastani, sundaes, milkshakes, and classic falooda.',
      'maps_query': 'Imperial Cold Drink House Rajarampuri Kolhapur',
      'icon': Icons.icecream_rounded,
      'color': Color(0xFFD97706),
    },
    {
      'name': 'Sugandha Cold Drink House',
      'category': 'DESSERT',
      'tag': 'Iconic Lassi & Kulfi',
      'rating': '4.8',
      'status': 'Cold Drinks & Desserts',
      'distance': '~1.8–2.2 km from Sayaji Hotel',
      'travel_time': '6–8 min drive',
      'transport': 'Auto / Taxi (Mangalwar Peth / Babujamal)',
      'speciality': 'Celebrated for thick malai lassi, cold drinks & refreshing kulfis — the quintessential sweet stop after a spicy Kolhapuri meal.',
      'maps_query': 'Sugandha Cold Drink House Kolhapur',
      'icon': Icons.local_drink_rounded,
      'color': Color(0xFF2E6F95),
    },
    {
      'name': 'Solanki Cold Drink House',
      'category': 'DESSERT',
      'tag': 'Falooda & Mastani',
      'rating': '4.6',
      'status': 'Cold Drinks & Desserts',
      'distance': '~2.5 km from Sayaji Hotel',
      'travel_time': '7 min drive',
      'transport': 'Auto / Taxi (Rajarampuri)',
      'speciality': 'Popular destination for traditional cold drinks, thick shakes, royal falooda, and artisanal ice creams.',
      'maps_query': 'Solanki Cold Drink House Kolhapur',
      'icon': Icons.emoji_food_beverage_rounded,
      'color': Color(0xFF8C1119),
    },

    // ---------------- TRANSIT & TRAVEL TIPS ----------------
    {
      'name': 'Kolhapur Railway Station (CSMT)',
      'category': 'TRANSIT',
      'tag': 'Railway Hub',
      'rating': '4.5',
      'status': '24/7 Transit',
      'distance': '~3.2 km from Sayaji Hotel',
      'travel_time': '10 min drive',
      'transport': 'Prepaid Autos, Taxis & City Buses',
      'speciality': 'Chhatrapati Shahu Maharaj Terminus connecting direct trains to Pune, Mumbai, Bengaluru, Hyderabad, and major Indian cities.',
      'maps_query': 'Kolhapur Railway Station',
      'icon': Icons.train_rounded,
      'color': Color(0xFF1E293B),
    },
    {
      'name': 'Central Bus Stand (CBS Kolhapur)',
      'category': 'TRANSIT',
      'tag': 'MSRTC Bus Terminal',
      'rating': '4.4',
      'status': '24/7 Transit',
      'distance': '~2.0 km from Sayaji Hotel',
      'travel_time': '5–7 min drive',
      'transport': 'Walking / Auto (~₹30–₹50)',
      'speciality': 'Primary intercity transport depot for MSRTC Shivneri, Shivshahi, and private sleeper buses across Maharashtra, Goa, and Karnataka.',
      'maps_query': 'Central Bus Stand CBS Kolhapur',
      'icon': Icons.directions_bus_rounded,
      'color': Color(0xFF0F766E),
    },
    {
      'name': 'Kolhapur Airport (KLH - Ujalaiwadi)',
      'category': 'TRANSIT',
      'tag': 'Airport Terminal',
      'rating': '4.6',
      'status': 'Domestic Flights',
      'distance': '~8.5–9.0 km from Sayaji Hotel',
      'travel_time': '15–20 min drive',
      'transport': 'Taxis, Ola/Uber & Airport Autos',
      'speciality': 'Direct domestic flight connectivity to Mumbai, Bengaluru, Hyderabad, and Tirupati. Fast airport transfer via NH-48.',
      'maps_query': 'Kolhapur Airport Ujalaiwadi',
      'icon': Icons.flight_takeoff_rounded,
      'color': Color(0xFF2E6F95),
    },
  ];

  @override
  Widget build(BuildContext context) {
    final filtered = _places.where((p) {
      final matchesCat = _selectedCategory == 'ALL' || p['category'] == _selectedCategory;
      final matchesQ = _searchQuery.isEmpty ||
          p['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p['tag'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p['speciality'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCat && matchesQ;
    }).toList();

    return SafeArea(
      top: false,
      child: Scaffold(
        backgroundColor: const Color(0xFFFCFAF5),
        appBar: AppBar(
          title: const Text(
            'Kolhapur Travel & Tourist Guide',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17),
          ),
          backgroundColor: maroon,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.open_in_browser_rounded, color: Colors.white, size: 22),
              tooltip: 'Official Travel Portal',
              onPressed: () => launchUrl(
                Uri.parse('https://www.mapcon2026kop.com/travel.php'),
                mode: LaunchMode.externalApplication,
              ),
            ),
          ],
        ),
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Banner Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                decoration: const BoxDecoration(
                  color: maroon,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: gold.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: gold, width: 1),
                          ),
                          child: const Text(
                            '📍 BASE: HOTEL SAYAJI, KOLHAPUR',
                            style: TextStyle(color: gold, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.6),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Explore Historic Kolhapur',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Temples, hill forts, traditional wrestling, iconic Kolhapuri Misal, Tambda-Pandhra Rassa & royal heritage.',
                      style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.85), height: 1.3),
                    ),
                    const SizedBox(height: 14),

                    // Search Box inside Banner
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: TextField(
                        onChanged: (val) => setState(() => _searchQuery = val),
                        decoration: InputDecoration(
                          hintText: 'Search places, temples, food, lassi...',
                          hintStyle: TextStyle(fontSize: 13.5, color: Colors.grey.shade500),
                          prefixIcon: const Icon(Icons.search, color: maroon, size: 22),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () => setState(() => _searchQuery = ''),
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Filter Category Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _buildChip('ALL', '✨ All Highlights (${_places.length})'),
                    _buildChip('SIGHTSEEING', '🏰 Tourist Places (9)'),
                    _buildChip('FOOD', '🍛 Kolhapuri Food (10)'),
                    _buildChip('DESSERT', '🍦 Lassi & Cold Drinks (3)'),
                    _buildChip('TRANSIT', '🚍 Travel & Transit (3)'),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Kolhapuri Cuisine Quick Tip Card
              if (_selectedCategory == 'ALL' || _selectedCategory == 'FOOD')
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFF8F0), Color(0xFFFFFDF8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFDBA74), width: 1.2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEA580C),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.tips_and_updates_rounded, color: Colors.white, size: 18),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Must-Try Kolhapuri Food Specialties',
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5, color: Color(0xFF9A3412)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '• Kolhapuri Misal Pav: Fiery, spiced sprouted bean curry served with soft pav.\n'
                        '• Tambda & Pandhra Rassa: Signature red chili broth and soothing coconut-milk white broth.\n'
                        '• Traditional Jowar/Bajra Bhakri with authentic Sukka mutton/chicken.\n'
                        '• Refreshing Sugandha or Imperial Mango Mastani & Malai Lassi after spicy meals.',
                        style: TextStyle(fontSize: 12.5, color: Colors.brown.shade800, height: 1.4),
                      ),
                    ],
                  ),
                ),

              // Places List
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 90),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final place = filtered[index];
                  final Color placeColor = place['color'] as Color? ?? maroon;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.grey.shade200, width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header: Icon + Title + Rating Badge
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: placeColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(place['icon'] as IconData? ?? Icons.location_on, color: placeColor, size: 24),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            place['name'],
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 16,
                                              color: slate,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFEF3C7),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: const Color(0xFFF59E0B)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.star_rounded, color: Color(0xFFD97706), size: 14),
                                              const SizedBox(width: 3),
                                              Text(
                                                place['rating'],
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 11.5,
                                                  color: Color(0xFF92400E),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      place['tag'],
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: placeColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const Divider(height: 22, thickness: 0.8),

                          // Distance & Transport Details
                          Row(
                            children: [
                              const Icon(Icons.near_me_rounded, color: maroon, size: 15),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Distance: ${place['distance']}',
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: slate),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.directions_car_filled_rounded, color: Color(0xFF2E6F95), size: 15),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  place['transport'],
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),

                          // Speciality Description
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('✨ ', style: TextStyle(fontSize: 12)),
                                Expanded(
                                  child: Text(
                                    place['speciality'],
                                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF334155), height: 1.35),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Map Navigation Button
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.map_rounded, size: 16),
                              label: const Text('Open in Google Maps'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: maroon,
                                side: const BorderSide(color: maroon, width: 1.2),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () {
                                final query = Uri.encodeComponent(place['maps_query']);
                                launchUrl(
                                  Uri.parse('https://www.google.com/maps/search/?api=1&query=$query'),
                                  mode: LaunchMode.externalApplication,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              if (filtered.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      children: [
                        Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        const Text(
                          'No places found matching your search.',
                          style: TextStyle(fontWeight: FontWeight.w700, color: muted, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChip(String category, String label) {
    final isSelected = _selectedCategory == category;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : slate,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
        selected: isSelected,
        selectedColor: maroon,
        backgroundColor: Colors.white,
        side: BorderSide(color: isSelected ? maroon : Colors.grey.shade300, width: 1.2),
        elevation: isSelected ? 2 : 0,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        onSelected: (_) => setState(() => _selectedCategory = category),
      ),
    );
  }
}
