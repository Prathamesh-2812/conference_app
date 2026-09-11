import 'package:flutter/material.dart';
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
      mapUrl: '${venue['googleMapsUrl'] ?? defaultMapUrl}',
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(x.toString()),
            backgroundColor: Colors.red.shade700,
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
  final pages = const [
    HomeScreen(),
    ScheduleScreen(),
    ChatScreen(),
    NoticesScreen(),
    GalleryScreen(),
    ProfileScreen()
  ];

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
            setState(() => i = 3);
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

  void _onTabSelected(int idx) {
    if (idx == 3) {
      RealtimeSyncService.instance.markAllAsRead();
    }
    setState(() => i = idx);
  }

  @override
  Widget build(BuildContext c) {
    final conference = ConferenceScope.of(c);
    return AppShell(
      child: Scaffold(
        backgroundColor: Colors.white,
        body: IndexedStack(
          index: i,
          children: pages,
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: i,
          backgroundColor: Colors.white,
          indicatorColor: conference.primaryColor.withOpacity(0.14),
          elevation: 6,
          onDestinationSelected: _onTabSelected,
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home, color: maroon),
              label: 'Home',
            ),
            const NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month, color: maroon),
              label: 'Schedule',
            ),
            const NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline),
              selectedIcon: Icon(Icons.chat_bubble, color: maroon),
              label: 'Chat',
            ),
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
          ],
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

  const CardButton({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailingBadge,
  });

  @override
  Widget build(BuildContext c) {
    final conference = ConferenceScope.of(c);
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
                  color: conference.primaryColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: conference.primaryColor, size: 24),
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

                  CardButton(
                    icon: Icons.videocam_rounded,
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
                  CardButton(
                    icon: Icons.calendar_month,
                    title: 'Event Schedule',
                    subtitle: 'Day-wise timeline, tracks & halls',
                    onTap: () => go(context, const ScheduleScreen()),
                  ),
                  CardButton(
                    icon: Icons.groups,
                    title: 'Conference Speakers',
                    subtitle: 'Distinguished dignitaries & profiles',
                    onTap: () => go(context, const SpeakersScreen()),
                  ),
                  CardButton(
                    icon: Icons.photo_library_rounded,
                    title: 'Photo Gallery',
                    subtitle: 'View conference photos & event moments',
                    onTap: () => go(context, const GalleryScreen()),
                  ),
                  CardButton(
                    icon: Icons.location_on,
                    title: 'Directions & Venue',
                    subtitle: 'Campus map, how to reach & hall guide',
                    onTap: () => go(context, const VenueDirectionsScreen()),
                  ),
                  CardButton(
                    icon: Icons.hotel,
                    title: 'My Accommodation',
                    subtitle: 'Hotel, room allotment & check-in details',
                    onTap: () => go(context, const AccommodationScreen()),
                  ),
                  CardButton(
                    icon: Icons.directions_car,
                    title: 'Transport & Cab',
                    subtitle: 'Pickup timing, vehicle & driver contact',
                    onTap: () => go(context, const TransportScreen()),
                  ),
                  CardButton(
                    icon: Icons.assignment,
                    title: 'Duty Roster',
                    subtitle: 'Assigned committee & conference tasks',
                    onTap: () => go(context, const DutiesScreen()),
                  ),
                  if (conference.settings['enableRegistration'] != false)
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
                  CardButton(
                    icon: Icons.emergency,
                    title: 'Emergency Help & Contacts',
                    subtitle: 'Help desk, medical unit & security',
                    onTap: () => go(context, const EmergencyScreen()),
                  ),
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
// VIRTUAL STAGE & HYBRID STREAM SCREEN (ZOOM INTEGRATION)
// ----------------------------------------------------
class VirtualStageScreen extends StatefulWidget {
  const VirtualStageScreen({super.key});

  @override
  State<VirtualStageScreen> createState() => _VirtualStageScreenState();
}

class _VirtualStageScreenState extends State<VirtualStageScreen> {
  List<dynamic> _sessions = [];
  bool _loading = true;
  String _selectedFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    try {
      final res = await ApiService.get('/sessions');
      if (res is List && mounted) {
        setState(() {
          _sessions = res;
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

  @override
  Widget build(BuildContext context) {
    final liveSessions = _sessions.where((s) => s['is_live'] == 1 || s['is_live'] == true).toList();
    final streamedSessions = _sessions.where((s) {
      final zoom = (s['zoom_link'] ?? '').toString().trim();
      final isLive = s['is_live'] == 1 || s['is_live'] == true;
      return zoom.isNotEmpty || isLive;
    }).toList();

    final displayed = _selectedFilter == 'LIVE'
        ? liveSessions
        : (_selectedFilter == 'STREAMED' ? streamedSessions : _sessions);

    return Scaffold(
      backgroundColor: cream,
      appBar: AppBar(
        title: const Text(
          'Hybrid & Online Live Stage',
          style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 17),
        ),
        backgroundColor: maroon,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: () {
              setState(() => _loading = true);
              _loadSessions();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: maroon))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Top Live Broadcast Banner Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 16, offset: const Offset(0, 6)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.videocam_rounded, color: Colors.white, size: 14),
                                SizedBox(width: 5),
                                Text(
                                  'ZOOM LIVE STAGE',
                                  style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w900, letterSpacing: 0.8),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDC2626),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.fiber_manual_record, size: 8, color: Colors.white),
                                SizedBox(width: 4),
                                Text(
                                  'ONLINE ACCESS',
                                  style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w900),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'MAPCON 2026 Virtual Stage',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.3),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Live broadcast for Hybrid & Online registered delegates with interactive audio, video & Q&A.',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.4),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF334155).withOpacity(0.6),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF475569)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Default Meeting ID:', style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12.5, fontWeight: FontWeight.w600)),
                                Text('845 1294 8123', style: TextStyle(color: gold, fontSize: 13, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
                              ],
                            ),
                            const Divider(height: 16, color: Color(0xFF475569)),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Default Passcode:', style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12.5, fontWeight: FontWeight.w600)),
                                const Text('MAPCON2026', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(46),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.video_call_rounded, size: 22),
                        label: const Text('Join Main Conference Zoom Room', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                        onPressed: () => _joinZoom('https://zoom.us/j/84512948123?pwd=MAPCON2026HYBRID'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Filters
                Row(
                  children: [
                    _buildTabChip('ALL', 'All Sessions (${_sessions.length})'),
                    if (streamedSessions.isNotEmpty)
                      _buildTabChip('STREAMED', '📹 Streams (${streamedSessions.length})'),
                    if (liveSessions.isNotEmpty)
                      _buildTabChip('LIVE', '🔴 Live (${liveSessions.length})'),
                  ],
                ),
                const SizedBox(height: 14),

                // Sessions List
                if (displayed.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(40),
                    alignment: Alignment.center,
                    child: const Column(
                      children: [
                        Icon(Icons.tv_off_rounded, size: 48, color: muted),
                        SizedBox(height: 12),
                        Text('No active streams found in this category', style: TextStyle(color: slate, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  )
                else
                  ...displayed.map((s) {
                    final title = s['title'] ?? 'Scientific Session';
                    final speaker = s['speaker_name'] ?? 'Keynote Faculty';
                    final hall = s['hall_name'] ?? 'Main Auditorium';
                    final timeStr = formatTimeRange(s['start_time'], s['end_time']);
                    final zoomUrl = (s['zoom_link'] ?? 'https://zoom.us/j/84512948123?pwd=MAPCON2026HYBRID').toString().trim();
                    final meetingId = (s['meeting_id'] ?? '845 1294 8123').toString().trim();
                    final passcode = (s['passcode'] ?? 'MAPCON2026').toString().trim();
                    final isLive = s['is_live'] == 1 || s['is_live'] == true;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isLive ? const Color(0xFFDC2626) : Colors.grey.shade200,
                          width: isLive ? 1.5 : 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isLive ? const Color(0xFFDC2626).withOpacity(0.08) : Colors.black.withOpacity(0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (isLive)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDC2626),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.fiber_manual_record, size: 8, color: Colors.white),
                                      SizedBox(width: 4),
                                      Text('LIVE NOW', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
                                    ],
                                  ),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2563EB).withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text('HYBRID STREAM', style: TextStyle(color: Color(0xFF2563EB), fontSize: 10, fontWeight: FontWeight.w900)),
                                ),
                              const Spacer(),
                              Text(timeStr, style: const TextStyle(color: slate, fontSize: 12, fontWeight: FontWeight.w700)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            title,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: slate),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '👨‍🏫 $speaker • 📍 $hall',
                            style: const TextStyle(fontSize: 12.5, color: muted, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('ID: $meetingId', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: slate)),
                                Text('Passcode: $passcode', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: muted)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isLive ? const Color(0xFFDC2626) : const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(40),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 0,
                            ),
                            icon: const Icon(Icons.open_in_new_rounded, size: 16),
                            label: Text(
                              isLive ? '🔴 Join Live Stream on Zoom' : '🌐 Connect via Zoom Link',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                            ),
                            onPressed: () => _joinZoom(zoomUrl),
                          ),
                        ],
                      ),
                    );
                  }),

                const SizedBox(height: 10),
                // Virtual Guidelines Box
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('💡 Hybrid & Online Delegate Guidelines:', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1E40AF), fontSize: 13)),
                      SizedBox(height: 6),
                      Text('• Please keep your microphone muted during scientific presentations.', style: TextStyle(fontSize: 12, color: Color(0xFF1E3A8A))),
                      SizedBox(height: 3),
                      Text('• Use the Zoom Q&A box or chat to post your queries to the speakers.', style: TextStyle(fontSize: 12, color: Color(0xFF1E3A8A))),
                      SizedBox(height: 3),
                      Text('• Complete the Feedback Form in the app at the conclusion of sessions to unlock your verified Certificate of Participation.', style: TextStyle(fontSize: 12, color: Color(0xFF1E3A8A))),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
    );
  }

  Widget _buildTabChip(String key, String label) {
    final isSelected = _selectedFilter == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: maroon,
        backgroundColor: Colors.white,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : slate,
          fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
          fontSize: 12,
        ),
        checkmarkColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        onSelected: (_) => setState(() => _selectedFilter = key),
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final conference = ConferenceScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Conference Speakers', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: conference.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: RefreshIndicator(
          color: maroon,
          onRefresh: () async {
            setState(() {});
            await Future.delayed(const Duration(milliseconds: 500));
          },
          child: FutureBuilder(
            future: ApiService.get('/speakers'),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: maroon));
              }

              if (snapshot.hasError) {
                return const Center(child: Text('Unable to load speakers'));
              }

              final list = snapshot.data is List ? snapshot.data as List : [];
              if (list.isEmpty) {
                return const Center(child: Text('No speakers announced yet'));
              }

              return ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                itemCount: list.length,
                itemBuilder: (context, index) {
                  final s = list[index];
                  final photoUrl = resolveSpeakerPhoto(s['photo']);

                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: BorderSide(color: Colors.grey.shade200, width: 1.2),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 78,
                              height: 78,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: conference.primaryColor, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.08),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: Image.network(
                                  photoUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: conference.primaryColor.withOpacity(0.1),
                                    child: Icon(Icons.person, size: 40, color: conference.primaryColor),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${s['name'] ?? ''}',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: conference.primaryColor,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: conference.primaryColor.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '${s['designation'] ?? 'Dignitary'}',
                                      style: TextStyle(
                                        color: conference.primaryColor,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 11.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    '${s['organization'] ?? 'Conference Guest'}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (s['bio'] != null && s['bio'].toString().isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Text(
                              '${s['bio']}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: slate,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                        if ((s['email'] != null && s['email'].toString().isNotEmpty) ||
                            (s['phone'] != null && s['phone'].toString().isNotEmpty)) ...[
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 10,
                            runSpacing: 8,
                            children: [
                              if (s['email'] != null && s['email'].toString().isNotEmpty)
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.email_outlined, size: 16),
                                  label: Text('${s['email']}'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: conference.primaryColor,
                                    side: BorderSide(color: Colors.grey.shade300),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                  onPressed: () => launchUrl(Uri.parse('mailto:${s['email']}')),
                                ),
                              if (s['phone'] != null && s['phone'].toString().isNotEmpty)
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.phone_outlined, size: 16, color: Colors.green),
                                  label: Text('${s['phone']}'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: slate,
                                    side: BorderSide(color: Colors.grey.shade300),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                  onPressed: () => launchUrl(Uri.parse('tel:${s['phone']}')),
                                ),
                            ],
                          ),
                        ],
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
    );
  }
}

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
// PHOTO GALLERY SCREEN
// ----------------------------------------------------
class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  String _activeAlbum = 'ALL';
  int _refreshKey = 0;

  void _openPhotoViewer(BuildContext context, dynamic photo) {
    final photoUrl = resolveMediaUrl(photo['url']);
    final caption = photo['caption'] ?? 'Conference Moment';
    final album = photo['album'] ?? 'General';

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
    return SafeArea(
      top: false,
      child: Column(
        children: [
          const Header(title: 'Photo Gallery'),
          Expanded(
            child: RefreshIndicator(
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
                              'Photos uploaded by the event organizers will appear here.',
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
                              onTap: () => _openPhotoViewer(context, item),
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
            ),
          ),
        ],
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
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [maroon.withOpacity(0.08), gold.withOpacity(0.12)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: gold.withOpacity(0.4)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(color: maroon, shape: BoxShape.circle),
                          child: const Icon(Icons.auto_awesome, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'MAPCON 2026 Live Assistant',
                                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: slate),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Instant help for schedule, hotel, food & certificates',
                                style: TextStyle(fontSize: 12, color: muted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  CardButton(
                    icon: Icons.person_pin,
                    title: 'Dr. Pallavi Kiran Shinde',
                    subtitle: 'Conference Liaison Faculty • Active now at Hotel Sayaji',
                    onTap: () => Navigator.push(
                      c,
                      MaterialPageRoute(
                        builder: (_) => const AppShell(child: ConversationScreen()),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  CardButton(
                    icon: Icons.support_agent_rounded,
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
                      'Live 24/7 Conference Helpdesk & AI Assistance Active',
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
            'body': 'Thank you! Your note has been received by Dr. Pallavi Kiran Shinde & the MAPCON Helpdesk.',
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
                  child: Icon(Icons.person, color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Dr. Pallavi Kiran Shinde', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5)),
                    Text('Conference Liaison • Online', style: TextStyle(fontSize: 11, color: Colors.white70)),
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

  Future<dynamic> load() => ApiService.get('/me/profile');

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
          SnackBar(content: Text('Failed to update photo: $e'), backgroundColor: Colors.red),
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
                                  SnackBar(content: Text('Failed to update: $e'), backgroundColor: Colors.red),
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
                  // 1. Campus Hero Card
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
                              'https://images.unsplash.com/photo-1541339907198-e08756dedf3f?w=1200',
                              height: 180,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                height: 180,
                                color: conference.primaryColor.withOpacity(0.15),
                                child: Icon(Icons.account_balance, size: 60, color: conference.primaryColor),
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
                                      'Official Host Campus',
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
                                      onPressed: () => launchUrl(
                                        Uri.parse(conference.mapUrl),
                                        mode: LaunchMode.externalApplication,
                                      ),
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
                  const SizedBox(height: 18),

                  // 2. Travel & How to Reach (Directions)
                  const Text(
                    'HOW TO REACH THE VENUE',
                    style: TextStyle(letterSpacing: 1.2, color: muted, fontWeight: FontWeight.w900, fontSize: 12.5),
                  ),
                  const SizedBox(height: 10),

                  _buildTravelCard(
                    icon: Icons.flight_takeoff,
                    title: 'By Air (Airport)',
                    primary: 'Kolhapur Airport (KLH) • 9 km | Pune Airport (PNQ) • 230 km',
                    details: 'Prepaid taxis, Ola & Uber are available outside the arrival gate. Direct university delegate pickup available upon prior request.',
                    accentColor: const Color(0xFF2563EB),
                  ),
                  _buildTravelCard(
                    icon: Icons.train,
                    title: 'By Railway (CSMT Terminus / Pune Jn)',
                    primary: 'Kolhapur CSMT Railway Station • 4.5 km',
                    details: 'Frequent express and superfast trains connect from Mumbai, Pune, Bangalore & Delhi. Direct 10-min auto/taxi ride to Kasaba Bawada campus.',
                    accentColor: const Color(0xFFD97706),
                  ),
                  _buildTravelCard(
                    icon: Icons.directions_bus,
                    title: 'By Road & Bus (NH-48)',
                    primary: 'Central Bus Stand (CBS) • 4 km | NH-48 Highway',
                    details: 'State transport & private luxury AC sleeper buses run 24x7. Smooth 4-lane highway connectivity directly to the university campus gates.',
                    accentColor: const Color(0xFF059669),
                  ),
                  const SizedBox(height: 18),

                  // 3. Entry & Parking Information
                  const Text(
                    'CAMPUS ENTRY & PARKING',
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
                            const Icon(Icons.local_parking, color: Color(0xFF1D4ED8), size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'Parking Assistance',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF1E3A8A)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          conference.parkingInfo,
                          style: const TextStyle(fontSize: 13, color: Color(0xFF1E40AF), height: 1.4),
                        ),
                        const Divider(height: 20, color: Color(0xFFBFDBFE)),
                        Row(
                          children: [
                            const Icon(Icons.alt_route, color: Color(0xFF1D4ED8), size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'Entrance Directions',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF1E3A8A)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          conference.directions,
                          style: const TextStyle(fontSize: 13, color: Color(0xFF1E40AF), height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // 4. Conference Halls Inside Campus
                  const Text(
                    'KEY CAMPUS HALLS & LOCATIONS',
                    style: TextStyle(letterSpacing: 1.2, color: muted, fontWeight: FontWeight.w900, fontSize: 12.5),
                  ),
                  const SizedBox(height: 10),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: const Column(
                      children: [
                        _HallTile(
                          icon: Icons.account_balance,
                          title: 'Main Convocation Auditorium',
                          location: 'Ground Floor, Central Block',
                          desc: 'Inaugural ceremony, Keynote sessions & Valedictory meet',
                        ),
                        Divider(height: 1),
                        _HallTile(
                          icon: Icons.meeting_room,
                          title: 'Senate Hall & Council Chambers',
                          location: '1st Floor, Administrative Wing',
                          desc: 'Vice Chancellors\' Panel Discussions & Closed-door meetings',
                        ),
                        Divider(height: 1),
                        _HallTile(
                          icon: Icons.restaurant,
                          title: 'Conference Banquet & Dining Hall',
                          location: 'North Lawn & Dining Pavilion',
                          desc: 'Breakfast, Delegate Lunch, High-Tea & Networking Dinners',
                        ),
                        Divider(height: 1),
                        _HallTile(
                          icon: Icons.badge,
                          title: 'Central Registration & Help Desk',
                          location: 'Main Auditorium Foyer',
                          desc: 'Delegate ID badges, Kit distribution & Spot Assistance',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // 5. Emergency Desk
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.emergency, color: Colors.red.shade700, size: 24),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Venue Emergency Control Desk',
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: slate),
                              ),
                              SizedBox(height: 2),
                              Text(
                                '24x7 Security & Medical on Campus',
                                style: TextStyle(fontSize: 12, color: muted),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => launchUrl(Uri.parse('tel:1800123456')),
                          child: const Text('Call 24x7', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTravelCard({
    required IconData icon,
    required String title,
    required String primary,
    required String details,
    required Color accentColor,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accentColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: slate),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    primary,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: accentColor),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    details,
                    style: const TextStyle(fontSize: 12.5, color: muted, height: 1.35),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HallTile extends StatelessWidget {
  final IconData icon;
  final String title, location, desc;

  const _HallTile({
    required this.icon,
    required this.title,
    required this.location,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: maroon.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: maroon, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: slate),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.location_pin, size: 12, color: maroon),
                    const SizedBox(width: 3),
                    Text(
                      location,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: maroon),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  desc,
                  style: const TextStyle(fontSize: 12, color: muted),
                ),
              ],
            ),
          ),
        ],
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
  // 1. Choice of Speakers
  String? _choiceOfSpeakers;
  // 2. Did the CME and Conference provide a thorough exploration of the topic?
  String? _thoroughExploration;
  // 3. Quality of Presentation
  String? _qualityOfPresentation;
  // 4. Usefulness of Topic
  String? _usefulnessOfTopic;
  // 5. Evaluation of the programme as a whole
  String? _programmeEvaluation;
  // 6. Was there adequate time for discussion?
  String? _adequateDiscussionTime;
  // 7. Were the topics selected cover important aspects of the specialty?
  String? _topicsCoveredSpecialty;
  // 8. How would you rate the improvement of your understanding based on this session? (1-5)
  int _understandingImprovement = 0;
  // 9. Rate the arrangements made by the organizers : (1-5)
  int _arrangementsRating = 0;
  // 10. Registration : (1-5)
  int _registrationRating = 0;
  // 11. Overall conduct of the CME & Conference: (1-5)
  int _overallConductRating = 0;
  // 12. Audiovisuals of the sessions : (1-5)
  int _audiovisualsRating = 0;
  // 13. Food Arrangements : (1-5)
  int _foodArrangementsRating = 0;
  // 14. Suggestions (if any)
  final TextEditingController _suggestionsController = TextEditingController();

  bool _isSubmitting = false;
  bool _isLoading = true;
  Map<String, dynamic>? _certData;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final res = await ApiService.get('/me/certificate');
      if (res is Map && mounted) {
        setState(() {
          _certData = Map<String, dynamic>.from(res);
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
    if (_choiceOfSpeakers == null ||
        _thoroughExploration == null ||
        _qualityOfPresentation == null ||
        _usefulnessOfTopic == null ||
        _programmeEvaluation == null ||
        _adequateDiscussionTime == null ||
        _topicsCoveredSpecialty == null ||
        _understandingImprovement == 0 ||
        _arrangementsRating == 0 ||
        _registrationRating == 0 ||
        _overallConductRating == 0 ||
        _audiovisualsRating == 0 ||
        _foodArrangementsRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Please fill out all evaluation questions and ratings before submitting.'),
          backgroundColor: Color(0xFFDC2626),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final payload = {
      'choiceOfSpeakers': _choiceOfSpeakers,
      'thoroughExploration': _thoroughExploration,
      'presentationQuality': _qualityOfPresentation,
      'topicUsefulness': _usefulnessOfTopic,
      'suggestions': _suggestionsController.text.trim(),
      'programmeEvaluation': _programmeEvaluation,
      'adequateDiscussionTime': _adequateDiscussionTime,
      'topicsCoveredSpecialty': _topicsCoveredSpecialty,
      'understandingImprovement': _understandingImprovement,
      'arrangementsRating': _arrangementsRating,
      'registrationRating': _registrationRating,
      'overallConductRating': _overallConductRating,
      'audiovisualsRating': _audiovisualsRating,
      'foodArrangementsRating': _foodArrangementsRating,
      'rating': _overallConductRating,
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
            backgroundColor: maroon,
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
        backgroundColor: cream,
        appBar: AppBar(
          title: const Text('CME & Conference Evaluation', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 17)),
          backgroundColor: maroon,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(child: CircularProgressIndicator(color: maroon)),
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
      backgroundColor: cream,
      appBar: AppBar(
        title: Text(
          (!hasFeedback || cert == null || fullImageUrl == null) ? 'Delegate Feedback Form' : 'Verified E-Certificate',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 17),
        ),
        backgroundColor: maroon,
        elevation: 0,
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
    final pName = participant?['name'] ?? 'Delegate';
    final regNo = participant?['registration_no'] ?? 'MAPCON-2026-DEL';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF8C1119), Color(0xFF5B0A0F)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: maroon.withOpacity(0.25), blurRadius: 12, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: gold.withOpacity(0.2), shape: BoxShape.circle),
                    child: const Icon(Icons.workspace_premium_rounded, color: gold, size: 26),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('VALEDICTORY CME FEEDBACK', style: TextStyle(color: gold, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
                        Text('Delegate Feedback Form', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Please submit your valuable evaluation to immediately generate & unlock your official Certificate of Participation.',
                style: TextStyle(color: Color(0xFFF8FAFC), fontSize: 12.5, height: 1.4),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.badge_outlined, color: gold, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('$pName ($regNo)', style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Section 1: Academic & Speaker Evaluation
        _buildCardSection(
          icon: Icons.school_rounded,
          title: '1. Academic & Presentation Quality',
          subtitle: 'Evaluate topics, speakers, and discussions',
          children: [
            _buildChoiceQuestion(
              questionNumber: '1',
              title: 'Choice of Speakers',
              options: const ['Excellent', 'Good', 'Average'],
              selectedValue: _choiceOfSpeakers,
              onChanged: (val) => setState(() => _choiceOfSpeakers = val),
            ),
            const Divider(height: 28),
            _buildChoiceQuestion(
              questionNumber: '2',
              title: 'Did the CME and Conference provide a thorough exploration of the topic?',
              options: const ['Excellent', 'Good', 'Average'],
              selectedValue: _thoroughExploration,
              onChanged: (val) => setState(() => _thoroughExploration = val),
            ),
            const Divider(height: 28),
            _buildChoiceQuestion(
              questionNumber: '3',
              title: 'Quality of Presentation',
              options: const ['Excellent', 'Good', 'Average'],
              selectedValue: _qualityOfPresentation,
              onChanged: (val) => setState(() => _qualityOfPresentation = val),
            ),
            const Divider(height: 28),
            _buildChoiceQuestion(
              questionNumber: '4',
              title: 'Usefulness of Topic',
              options: const ['Excellent', 'Good', 'Average'],
              selectedValue: _usefulnessOfTopic,
              onChanged: (val) => setState(() => _usefulnessOfTopic = val),
            ),
            const Divider(height: 28),
            _buildChoiceQuestion(
              questionNumber: '5',
              title: 'Evaluation of the programme as a whole',
              options: const ['Excellent', 'Good', 'Average'],
              selectedValue: _programmeEvaluation,
              onChanged: (val) => setState(() => _programmeEvaluation = val),
            ),
            const Divider(height: 28),
            _buildChoiceQuestion(
              questionNumber: '6',
              title: 'Was there adequate time for discussion?',
              options: const ['Yes', 'No'],
              selectedValue: _adequateDiscussionTime,
              onChanged: (val) => setState(() => _adequateDiscussionTime = val),
            ),
            const Divider(height: 28),
            _buildChoiceQuestion(
              questionNumber: '7',
              title: 'Were the topics selected cover important aspects of the specialty?',
              options: const ['Yes', 'No'],
              selectedValue: _topicsCoveredSpecialty,
              onChanged: (val) => setState(() => _topicsCoveredSpecialty = val),
            ),
          ],
        ),

        const SizedBox(height: 18),

        // Section 2: Ratings & Organisation (1 to 5)
        _buildCardSection(
          icon: Icons.star_half_rounded,
          title: '2. Ratings & Arrangements (Scale 1 to 5)',
          subtitle: '1 = Poor, 5 = Outstanding',
          children: [
            _buildScaleRatingQuestion(
              questionNumber: '8',
              title: 'How would you rate the improvement of your understanding based on this session?',
              currentValue: _understandingImprovement,
              onChanged: (val) => setState(() => _understandingImprovement = val),
            ),
            const Divider(height: 28),
            _buildScaleRatingQuestion(
              questionNumber: '9',
              title: 'Rate the arrangements made by the organizers :',
              currentValue: _arrangementsRating,
              onChanged: (val) => setState(() => _arrangementsRating = val),
            ),
            const Divider(height: 28),
            _buildScaleRatingQuestion(
              questionNumber: '10',
              title: 'Registration :',
              currentValue: _registrationRating,
              onChanged: (val) => setState(() => _registrationRating = val),
            ),
            const Divider(height: 28),
            _buildScaleRatingQuestion(
              questionNumber: '11',
              title: 'Overall conduct of the CME & Conference :',
              currentValue: _overallConductRating,
              onChanged: (val) => setState(() => _overallConductRating = val),
            ),
            const Divider(height: 28),
            _buildScaleRatingQuestion(
              questionNumber: '12',
              title: 'Audiovisuals of the sessions :',
              currentValue: _audiovisualsRating,
              onChanged: (val) => setState(() => _audiovisualsRating = val),
            ),
            const Divider(height: 28),
            _buildScaleRatingQuestion(
              questionNumber: '13',
              title: 'Food Arrangements :',
              currentValue: _foodArrangementsRating,
              onChanged: (val) => setState(() => _foodArrangementsRating = val),
            ),
          ],
        ),

        const SizedBox(height: 18),

        // Section 3: Suggestions
        _buildCardSection(
          icon: Icons.edit_note_rounded,
          title: '3. Suggestions & Remarks',
          subtitle: 'Suggestions (if any)',
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: maroon.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                  child: const Text('Q14', style: TextStyle(color: maroon, fontWeight: FontWeight.bold, fontSize: 11)),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Suggestions (if any) *', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: slate)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _suggestionsController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Enter your suggestions or comments for future CME & Conferences...',
                hintStyle: const TextStyle(fontSize: 12.5, color: muted),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: maroon, width: 1.5)),
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Submit Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: maroon,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 4,
            ),
            icon: _isSubmitting
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.workspace_premium_rounded, color: gold, size: 22),
            label: Text(
              _isSubmitting ? 'Generating Certificate...' : 'Submit Feedback & Unlock Certificate',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
            ),
            onPressed: _isSubmitting ? null : _submitFeedbackAndGenerate,
          ),
        ),
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildCardSection({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey.shade200, width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: maroon.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
                  child: Icon(icon, color: maroon, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: slate)),
                      Text(subtitle, style: const TextStyle(fontSize: 11.5, color: muted)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildChoiceQuestion({
    required String questionNumber,
    required String title,
    required List<String> options,
    required String? selectedValue,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: maroon.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
              child: Text('Q$questionNumber', style: const TextStyle(color: maroon, fontWeight: FontWeight.bold, fontSize: 11)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$title *',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: slate, height: 1.3),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((opt) {
            final isSelected = selectedValue != null && selectedValue.toLowerCase() == opt.toLowerCase();
            return ChoiceChip(
              label: Text(opt),
              selected: isSelected,
              selectedColor: maroon,
              backgroundColor: const Color(0xFFF1F5F9),
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF334155),
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                fontSize: 12.5,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: isSelected ? maroon : Colors.grey.shade300),
              ),
              onSelected: (selected) {
                if (selected) onChanged(opt);
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildScaleRatingQuestion({
    required String questionNumber,
    required String title,
    required int currentValue,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: maroon.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
              child: Text('Q$questionNumber', style: const TextStyle(color: maroon, fontWeight: FontWeight.bold, fontSize: 11)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$title *',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: slate, height: 1.3),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(5, (index) {
            final val = index + 1;
            final isSelected = currentValue == val;
            return Expanded(
              child: GestureDetector(
                onTap: () => onChanged(val),
                child: Container(
                  margin: EdgeInsets.only(right: index == 4 ? 0 : 6),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? maroon : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? maroon : Colors.grey.shade300,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.star_rounded,
                        color: isSelected ? gold : (currentValue > 0 && val <= currentValue ? const Color(0xFFF59E0B) : Colors.grey.shade400),
                        size: 18,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$val',
                        style: TextStyle(
                          color: isSelected ? Colors.white : const Color(0xFF334155),
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ],
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
          CardButton(
            icon: Icons.security,
            title: 'Campus Security & Control Room',
            subtitle: 'Call 100 • Emergency Security Cell',
            onTap: () => launchUrl(Uri.parse('tel:100')),
          ),
          CardButton(
            icon: Icons.location_on,
            title: 'Conference Location Map',
            subtitle: 'Open in Google Maps for campus navigation',
            onTap: () => launchUrl(Uri.parse(conference.mapUrl), mode: LaunchMode.externalApplication),
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
