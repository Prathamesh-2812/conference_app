import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'config.dart';
import 'services/api_service.dart';
import 'services/webcam_service.dart';

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

class _ConferenceAppState extends State<ConferenceApp> {
  ConferenceInfo info = ConferenceInfo.fallback();

  @override
  void initState() {
    super.initState();
    _loadConference();
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
        title: info.name,
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
    setState(() {
      logged = p.getString('token') != null;
      loading = false;
    });
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
  final e = TextEditingController(text: 'participant@conference.local');
  final p = TextEditingController(text: 'Demo@123');
  bool busy = false, obscure = true;

  Future<void> login() async {
    setState(() => busy = true);
    try {
      final r = await ApiService.login(e.text.trim(), p.text);
      final sp = await SharedPreferences.getInstance();
      await sp.setString('token', r['token']);
      await sp.setString('name', r['user']['name']);
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
                        width: 84,
                        height: 84,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: conference.primaryColor.withOpacity(0.06),
                          shape: BoxShape.circle,
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/logo.png',
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => Icon(
                              Icons.school,
                              size: 44,
                              color: conference.primaryColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      conference.shortName,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: conference.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Delegate & Participant Portal',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: muted,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 28),
                    TextField(
                      controller: e,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email Address',
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
                      decoration: InputDecoration(
                        labelText: 'Password',
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
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Column(
                        children: [
                          Text(
                            'Demo Credentials',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: slate),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'participant@conference.local / Demo@123',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: muted, fontSize: 12),
                          ),
                        ],
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
          onDestinationSelected: (x) => setState(() => i = x),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home, color: maroon),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month, color: maroon),
              label: 'Schedule',
            ),
            NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline),
              selectedIcon: Icon(Icons.chat_bubble, color: maroon),
              label: 'Chat',
            ),
            NavigationDestination(
              icon: Icon(Icons.notifications_none),
              selectedIcon: Icon(Icons.notifications, color: maroon),
              label: 'Notices',
            ),
            NavigationDestination(
              icon: Icon(Icons.photo_library_outlined),
              selectedIcon: Icon(Icons.photo_library, color: maroon),
              label: 'Gallery',
            ),
            NavigationDestination(
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

  @override
  Widget build(BuildContext c) {
    final conference = ConferenceScope.of(c);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [conference.primaryColor, darkMaroon],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (Navigator.canPop(c))
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                    onPressed: () => Navigator.maybePop(c),
                  ),
                ),
              Container(
                width: 46,
                height: 46,
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.school,
                      color: conference.primaryColor,
                      size: 26,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      conference.shortName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: gold.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: gold.withOpacity(0.5), width: 0.8),
                          ),
                          child: Text(
                            title,
                            style: const TextStyle(
                              color: Color(0xFFFFF8E7),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
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

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

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
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Header(title: 'Overview'),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 90),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                    icon: Icons.face_retouching_natural,
                    title: 'AI Smart Photo Gallery',
                    subtitle: 'Find your photos with AI selfie face match',
                    trailingBadge: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: gold.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: gold),
                      ),
                      child: const Text(
                        'AI POWERED',
                        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: darkMaroon),
                      ),
                    ),
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
                  if (conference.settings['enableAttendance'] != false)
                    CardButton(
                      icon: Icons.fact_check,
                      title: 'My Attendance',
                      subtitle: 'Session attendance record & verification',
                      onTap: () => go(context, const AttendanceScreen()),
                    ),
                  if (conference.settings['enableCertificates'] != false)
                    CardButton(
                      icon: Icons.workspace_premium,
                      title: 'Certificate of Participation',
                      subtitle: 'View & download certified credentials',
                      onTap: () => go(context, const CertificateScreen()),
                    ),
                  CardButton(
                    icon: Icons.restaurant,
                    title: 'Meals & Dining',
                    subtitle: 'Breakfast, lunch, high-tea & banquet',
                    onTap: () => go(context, const MealsScreen()),
                  ),
                  CardButton(
                    icon: Icons.emergency,
                    title: 'Emergency Help & Contacts',
                    subtitle: 'Help desk, medical unit & security',
                    onTap: () => go(context, const EmergencyScreen()),
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

  Future<List<dynamic>> load() async {
    final result = await ApiService.get('/sessions?conferenceId=1');
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
            const SizedBox(height: 24),
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
                    icon: const Icon(Icons.alarm_add_rounded, size: 20),
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
class SpeakersScreen extends StatelessWidget {
  const SpeakersScreen({super.key});

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
        child: FutureBuilder(
          future: ApiService.get('/speakers?conferenceId=1'),
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
      );
  }
}

// ----------------------------------------------------
// NOTICES SCREEN
// ----------------------------------------------------
class NoticesScreen extends StatelessWidget {
  const NoticesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        children: [
          const Header(title: 'Notices & Announcements'),
          Expanded(
            child: FutureBuilder(
              future: ApiService.get('/notices?conferenceId=1'),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: maroon));
                }

                if (snapshot.hasError) {
                  return const Center(child: Text('Unable to load notices'));
                }

                final data = snapshot.data is List ? snapshot.data as List : <dynamic>[];

                if (data.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_none, size: 54, color: muted),
                        SizedBox(height: 12),
                        Text(
                          'No Announcements Yet',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: slate),
                        ),
                        SizedBox(height: 4),
                        Text('Check back later for event updates', style: TextStyle(color: muted)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(18),
                  itemCount: data.length,
                  itemBuilder: (context, index) {
                    final item = data[index];
                    final isUrgent = item['priority'] == 'URGENT';

                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: BorderSide(
                          color: isUrgent ? Colors.red.shade300 : Colors.grey.shade200,
                          width: 1.2,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isUrgent ? Colors.red.shade50 : maroon.withOpacity(0.08),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isUrgent ? Icons.warning_amber_rounded : Icons.notifications_active_outlined,
                                    color: isUrgent ? Colors.red.shade700 : maroon,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    '${item['title'] ?? 'Announcement'}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                      color: slate,
                                    ),
                                  ),
                                ),
                                if (isUrgent)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'URGENT',
                                      style: TextStyle(
                                        color: Colors.red.shade900,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '${item['message'] ?? ''}',
                              style: const TextStyle(fontSize: 14, color: Color(0xFF334155), height: 1.45),
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
        ],
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
      final res = await ApiService.get('/gallery/my-photos?conferenceId=1');
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
        'conferenceId': 1,
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
          SnackBar(content: Text('Matching error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _openPhotoViewer(BuildContext context, dynamic photo, {bool isMatched = false}) {
    final photoUrl = photo['url'] ?? '';
    final caption = photo['caption'] ?? 'Conference Moment';
    final album = photo['album'] ?? 'General';
    final confidence = isMatched ? (photo['confidencePercent'] ?? '95% Match') : null;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.9),
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
    return SafeArea(
      top: false,
      child: Column(
        children: [
          const Header(title: 'Gallery & AI Match'),
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: maroon,
              unselectedLabelColor: muted,
              indicatorColor: maroon,
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
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAiSelfieTab(),
                _buildAllPhotosTab(),
              ],
            ),
          ),
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
                    child: const Icon(Icons.camera_enhance, color: gold, size: 28),
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
              final url = item['url'] ?? '';
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
    return FutureBuilder(
      future: ApiService.get('/gallery?conferenceId=1'),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: maroon));
        }
        if (snapshot.hasError) {
          return const Center(child: Text('Unable to load conference gallery'));
        }

        final photos = snapshot.data is List ? (snapshot.data as List) : [];
        if (photos.isEmpty) {
          return const Center(child: Text('No conference photos uploaded yet'));
        }

        final distinctAlbums = {'ALL', ...photos.map((p) => (p['album'] ?? 'General').toString())}.toList();
        final filtered = _activeAlbum == 'ALL'
            ? photos
            : photos.where((p) => p['album'] == _activeAlbum).toList();

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
                  final url = item['url'] ?? '';
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
                    icon: Icons.person,
                    title: 'Dr. Pallavi Kiran Shinde',
                    subtitle: 'Conference Liaison Faculty • Chat with your liaison',
                    onTap: () => Navigator.push(
                      c,
                      MaterialPageRoute(
                        builder: (_) => const AppShell(child: ConversationScreen()),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Center(
                    child: Text(
                      'Real-time communication enabled by Socket.IO',
                      style: TextStyle(color: muted, fontSize: 12.5),
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
  final t = TextEditingController();
  final messages = ['Welcome to MAPCON 2026! How can I assist you today?'];

  void send() {
    if (t.text.trim().isEmpty) return;
    setState(() {
      messages.add(t.text.trim());
      t.clear();
    });
  }

  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(
          title: const Text('Dr. Pallavi Kiran Shinde', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: maroon,
          foregroundColor: Colors.white,
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: messages.length,
                itemBuilder: (c, i) => Align(
                  alignment: i.isEven ? Alignment.centerLeft : Alignment.centerRight,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: i.isEven ? Colors.white : maroon,
                      borderRadius: BorderRadius.circular(16),
                      border: i.isEven ? Border.all(color: Colors.grey.shade200) : null,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      messages[i],
                      style: TextStyle(color: i.isEven ? slate : Colors.white, fontSize: 14),
                    ),
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: t,
                      decoration: InputDecoration(
                        hintText: 'Type your message...',
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                    child: IconButton(
                      onPressed: send,
                      icon: const Icon(Icons.send, color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
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
                    return const Center(child: Text('Unable to load profile'));
                  }
                  final x = s.data ?? {};
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
                                        color: Colors.black.withOpacity(0.25),
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        x['name'] ?? '',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: slate),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        x['email'] ?? '',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: muted, fontSize: 13.5),
                      ),
                      const SizedBox(height: 24),
                      InfoSection(
                        title: 'BASIC INFORMATION',
                        items: {
                          'Role': x['role'],
                          'Mobile No': x['phone'],
                          'University': x['university'],
                          'Designation': x['designation'],
                          'Blood Group': x['blood_group'],
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
                          'Arrival Date': formatSessionDate(x['arrival_date']),
                          'Arrival Time': formatSingleTime(x['arrival_time']),
                          'Departure Date': formatSessionDate(x['departure_date']),
                          'Departure Time': formatSingleTime(x['departure_time']),
                        },
                      ),
                      const SizedBox(height: 10),
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

class AttendanceScreen extends StatelessWidget {
  const AttendanceScreen({super.key});
  @override
  Widget build(BuildContext c) => ListApiPage(
        title: 'My Attendance',
        path: '/me/attendance',
        icon: Icons.fact_check,
        fields: const ['title', 'session_date', 'start_time', 'scan_type', 'scanned_at'],
      );
}

class MealsScreen extends StatelessWidget {
  const MealsScreen({super.key});
  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(
          title: const Text('Meals & Catering Schedule', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: maroon,
          foregroundColor: Colors.white,
        ),
        body: ListView(
          padding: const EdgeInsets.all(18),
          children: const [
            MealCard('Breakfast', '07:30 AM – 09:30 AM', 'Dining Hall A • Main Campus', Icons.free_breakfast),
            MealCard('Lunch', '12:30 PM – 02:30 PM', 'Conference Banquet Hall', Icons.lunch_dining),
            MealCard('High Tea & Networking', '04:30 PM – 05:30 PM', 'Auditorium Foyer', Icons.local_cafe),
            MealCard('Gala Dinner', '07:30 PM – 10:00 PM', 'Grand Ballroom / Hyatt Regency', Icons.dinner_dining),
          ],
        ),
      );
}

class MealCard extends StatelessWidget {
  final String title, time, venue;
  final IconData icon;

  const MealCard(this.title, this.time, this.venue, this.icon, {super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.grey.shade200, width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: maroon.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: maroon, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: slate)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 13, color: muted),
                      const SizedBox(width: 4),
                      Text(time, style: const TextStyle(color: slate, fontWeight: FontWeight.w700, fontSize: 12.5)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 13, color: maroon),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(venue, style: const TextStyle(color: muted, fontSize: 12), overflow: TextOverflow.ellipsis),
                      ),
                    ],
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

class CertificateScreen extends StatelessWidget {
  const CertificateScreen({super.key});
  @override
  Widget build(BuildContext c) => DetailApiPage(
        title: 'Certificate of Participation',
        path: '/me/certificate',
        icon: Icons.workspace_premium,
        empty: 'Certificate will be issued post valedictory session',
        fields: const ['certificate_no', 'issued_at', 'certificate_url'],
      );
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
