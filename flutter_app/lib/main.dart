import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'config.dart';
import 'services/api_service.dart';

const maroon=Color(0xFF8C1119), cream=Color(0xFFFCFAF5), gold=Color(0xFFC8A45A), muted=Color(0xFF82909A);

void main()=>runApp(const ConferenceApp());
class ConferenceInfo {
  final String name;
  final String shortName;
  final String welcomeMessage;
  final String description;
  final String aboutConference;
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
        welcomeMessage: 'Welcome to the Conference',
        description:
            '100th AIU Annual General Body Meet & National Conference of Vice Chancellors',
        aboutConference: '',
        mapUrl: defaultMapUrl,
        startDate: '2026-04-27',
        endDate: '2026-04-30',
        contactEmail: 'admin@conference.local',
        contactPhone: '1800123456',
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
    return context
            .dependOnInheritedWidgetOfExactType<ConferenceScope>()
            ?.info ??
        ConferenceInfo.fallback();
  }

  @override
  bool updateShouldNotify(ConferenceScope oldWidget) => info != oldWidget.info;
}

class ConferenceApp extends StatefulWidget{const ConferenceApp({super.key});@override State<ConferenceApp> createState()=>_ConferenceAppState();}
class _ConferenceAppState extends State<ConferenceApp>{ConferenceInfo info=ConferenceInfo.fallback();@override void initState(){super.initState();_loadConference();}Future<void>_loadConference()async{try{final data=await ApiService.conference();if(mounted)setState(()=>info=ConferenceInfo.fromJson(data));}catch(_){}}@override Widget build(BuildContext c)=>ConferenceScope(info:info,child:MaterialApp(debugShowCheckedModeBanner:false,title:info.name,theme:ThemeData(useMaterial3:true,scaffoldBackgroundColor:info.backgroundColor,colorScheme:ColorScheme.fromSeed(seedColor:info.primaryColor),fontFamily:'Arial'),home:const AuthGate()));}

class AuthGate extends StatefulWidget{const AuthGate({super.key});@override State<AuthGate> createState()=>_AuthGateState();}
class _AuthGateState extends State<AuthGate>{bool loading=true,logged=false;@override void initState(){super.initState();_check();}Future<void>_check()async{final p=await SharedPreferences.getInstance();setState((){logged=p.getString('token')!=null;loading=false;});} @override Widget build(BuildContext c)=>loading?const Scaffold(body:Center(child:CircularProgressIndicator())):logged?const MainShell():LoginScreen(onLogin:()=>setState(()=>logged=true));}

class LoginScreen extends StatefulWidget{final VoidCallback onLogin;const LoginScreen({super.key,required this.onLogin});@override State<LoginScreen> createState()=>_LoginScreenState();}
class _LoginScreenState extends State<LoginScreen>{final e=TextEditingController(text:'participant@conference.local'),p=TextEditingController(text:'Demo@123');bool busy=false,obscure=true;Future<void>login()async{setState(()=>busy=true);try{final r=await ApiService.login(e.text.trim(),p.text);final sp=await SharedPreferences.getInstance();await sp.setString('token',r['token']);await sp.setString('name',r['user']['name']);widget.onLogin();}catch(x){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(x.toString())));}finally{if(mounted)setState(()=>busy=false);}}@override Widget build(BuildContext c){final conference=ConferenceScope.of(c);return Scaffold(backgroundColor: conference.backgroundColor, body:SafeArea(child:SingleChildScrollView(padding:const EdgeInsets.all(24),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[const SizedBox(height:40),Container(height:130,decoration:BoxDecoration(color:conference.primaryColor,borderRadius:BorderRadius.circular(28)),child:const Center(child:Icon(Icons.event_available,size:72,color:Colors.white))),const SizedBox(height:28),Text(conference.name,style:TextStyle(fontSize:30,fontWeight:FontWeight.w800,color:conference.primaryColor)),const SizedBox(height:8),const Text('Secure conference access for delegates, speakers and teams.',style:TextStyle(color:muted,fontSize:16)),const SizedBox(height:28),TextField(controller:e,keyboardType:TextInputType.emailAddress,decoration:const InputDecoration(labelText:'Email',prefixIcon:Icon(Icons.email_outlined),border:OutlineInputBorder())),const SizedBox(height:14),TextField(controller:p,obscureText:obscure,decoration:InputDecoration(labelText:'Password',prefixIcon:const Icon(Icons.lock_outline),suffixIcon:IconButton(onPressed:()=>setState(()=>obscure=!obscure),icon:Icon(obscure?Icons.visibility:Icons.visibility_off)),border:const OutlineInputBorder())),const SizedBox(height:20),FilledButton(style:FilledButton.styleFrom(backgroundColor:conference.primaryColor,padding:const EdgeInsets.symmetric(vertical:16)),onPressed:busy?null:login,child:busy?const CircularProgressIndicator(color:Colors.white):const Text('Sign In')),const SizedBox(height:12),const Text('Demo: participant@conference.local / Demo@123',textAlign:TextAlign.center,style:TextStyle(color:muted))]))));}}

class MainShell extends StatefulWidget{const MainShell({super.key});@override State<MainShell> createState()=>_MainShellState();}
class _MainShellState extends State<MainShell>{int i=0;final pages=const[HomeScreen(),ScheduleScreen(),ChatScreen(),NoticesScreen(),GalleryScreen(),ProfileScreen()];@override Widget build(BuildContext c)=>Scaffold(body:pages[i],bottomNavigationBar:NavigationBar(selectedIndex:i,onDestinationSelected:(x)=>setState(()=>i=x),destinations:const[NavigationDestination(icon:Icon(Icons.home_outlined),selectedIcon:Icon(Icons.home),label:'Home'),NavigationDestination(icon:Icon(Icons.calendar_month_outlined),selectedIcon:Icon(Icons.calendar_month),label:'Schedule'),NavigationDestination(icon:Icon(Icons.chat_bubble_outline),selectedIcon:Icon(Icons.chat_bubble),label:'Chat'),NavigationDestination(icon:Icon(Icons.notifications_none),selectedIcon:Icon(Icons.notifications),label:'Notices'),NavigationDestination(icon:Icon(Icons.photo_library_outlined),selectedIcon:Icon(Icons.photo_library),label:'Gallery'),NavigationDestination(icon:Icon(Icons.person_outline),selectedIcon:Icon(Icons.person),label:'Profile')]));}

class Header extends StatelessWidget{final String title;const Header({super.key,this.title='Home'});@override Widget build(BuildContext c){final conference=ConferenceScope.of(c);return Container(padding:const EdgeInsets.fromLTRB(22,46,22,22),decoration:BoxDecoration(color:conference.primaryColor,borderRadius:const BorderRadius.vertical(bottom:Radius.circular(30))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[const CircleAvatar(radius:24,backgroundColor:Colors.white,child:Icon(Icons.account_balance,color:maroon)),const Spacer(),Container(padding:const EdgeInsets.symmetric(horizontal:12,vertical:8),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(10)),child:const Text('DPU',style:TextStyle(color:maroon,fontWeight:FontWeight.w900,fontSize:22)))]),const SizedBox(height:12),Text(conference.shortName,style:const TextStyle(color:Colors.white,fontSize:25,fontWeight:FontWeight.w800)),const SizedBox(height:6),Text(title,style:const TextStyle(color:Colors.white,fontSize:18,fontWeight:FontWeight.w600))]));}}

class CardButton extends StatelessWidget{final IconData icon;final String title,subtitle;final VoidCallback onTap;const CardButton({super.key,required this.icon,required this.title,required this.subtitle,required this.onTap});@override Widget build(BuildContext c){final conference=ConferenceScope.of(c);return Card(elevation:0,margin:const EdgeInsets.only(bottom:14),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(20)),child:InkWell(borderRadius:BorderRadius.circular(20),onTap:onTap,child:Padding(padding:const EdgeInsets.all(18),child:Row(children:[Container(width:54,height:54,decoration:BoxDecoration(color:conference.primaryColor.withOpacity(.07),borderRadius:BorderRadius.circular(16)),child:Icon(icon,color:conference.primaryColor)),const SizedBox(width:16),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontSize:18,fontWeight:FontWeight.w800)),const SizedBox(height:3),Text(subtitle,style:const TextStyle(color:muted))])),const Icon(Icons.arrow_forward_ios,size:16,color:gold)]))));}}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void go(BuildContext context, Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    final conference = ConferenceScope.of(context);

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Column(
          children: [
            const Header(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 90),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    conference.welcomeMessage,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: conference.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    conference.description,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'ESSENTIAL INFO',
                    style: TextStyle(
                      letterSpacing: 1.5,
                      color: muted,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  CardButton(
                    icon: Icons.groups,
                    title: 'Conference Speakers',
                    subtitle: 'Distinguished speakers & profiles',
                    onTap: () => go(context, const SpeakersScreen()),
                  ),
                  CardButton(
                    icon: Icons.calendar_month,
                    title: 'Event Schedule',
                    subtitle: 'Detailed session timeline',
                    onTap: () => go(context, const ScheduleScreen()),
                  ),
                  CardButton(
                    icon: Icons.location_on,
                    title: 'Directions & Venue',
                    subtitle: 'Open conference location in Maps',
                    onTap: () => launchUrl(
                      Uri.parse(conference.mapUrl),
                      mode: LaunchMode.externalApplication,
                    ),
                  ),
                  CardButton(
                    icon: Icons.hotel,
                    title: 'My Accommodation',
                    subtitle: 'Hotel, room and check-in details',
                    onTap: () => go(context, const AccommodationScreen()),
                  ),
                  CardButton(
                    icon: Icons.directions_car,
                    title: 'Transport',
                    subtitle: 'Pickup, vehicle and driver details',
                    onTap: () => go(context, const TransportScreen()),
                  ),
                  CardButton(
                    icon: Icons.assignment,
                    title: 'Duty Roster',
                    subtitle: 'Your assigned conference duties',
                    onTap: () => go(context, const DutiesScreen()),
                  ),
                  if (conference.settings['enableRegistration'] != false)
                    CardButton(
                      icon: Icons.qr_code_2,
                      title: 'Digital ID / QR',
                      subtitle: 'Registration pass and QR code',
                      onTap: () => go(context, const DigitalIdScreen()),
                    ),
                  if (conference.settings['enableAttendance'] != false)
                    CardButton(
                      icon: Icons.fact_check,
                      title: 'Attendance',
                      subtitle: 'Your session attendance history',
                      onTap: () => go(context, const AttendanceScreen()),
                    ),
                  if (conference.settings['enableCertificates'] != false)
                    CardButton(
                      icon: Icons.workspace_premium,
                      title: 'Certificate',
                      subtitle: 'View and download certificate',
                      onTap: () => go(context, const CertificateScreen()),
                    ),
                  CardButton(
                    icon: Icons.restaurant,
                    title: 'Meals',
                    subtitle: 'Breakfast, lunch, tea and dinner',
                    onTap: () => go(context, const MealsScreen()),
                  ),
                  CardButton(
                    icon: Icons.emergency,
                    title: 'Emergency Help',
                    subtitle: 'Medical, security and help desk',
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
class ScheduleScreen extends StatefulWidget{const ScheduleScreen({super.key});@override State<ScheduleScreen> createState()=>_ScheduleScreenState();}
class _ScheduleScreenState extends State<ScheduleScreen> {
  Future<List<dynamic>> load() async {
    final result = await ApiService.get('/sessions?conferenceId=1');
    return result is List ? result : <dynamic>[];
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        children: [
          const Header(title: 'Event Schedule'),
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: load(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return const Center(child: Text('Unable to load schedule'));
                }

                final data = snapshot.data ?? [];

                if (data.isEmpty) {
                  return const Center(child: Text('No sessions available'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(18),
                  itemCount: data.length,
                  itemBuilder: (context, index) {
                    final x = data[index];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(
                          backgroundImage: x['speaker_photo'] != null ? NetworkImage(x['speaker_photo']) : null,
                          backgroundColor: maroon.withOpacity(.08),
                          child: x['speaker_photo'] == null ? const Icon(Icons.event, color: maroon) : null,
                        ),
                        title: Text(
                          '${x['title'] ?? ''}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                       subtitle: Text(
                         '${x['session_date'] ?? ''} • '
                         '${x['start_time'] ?? ''} - ${x['end_time'] ?? ''}\n'
                         '${x['speaker_name'] ?? 'Speaker'} • '
                         '${x['hall_name'] ?? 'Hall'}\n'
                         'Category: ${x['category'] ?? '-'}',
                       ),
                        isThreeLine: true,
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

class SpeakersScreen extends StatelessWidget {
  const SpeakersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final conference = ConferenceScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Conference Speakers'),
        backgroundColor: conference.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 740),
          child: FutureBuilder(
            future: ApiService.get('/speakers?conferenceId=1'),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return const Center(child: Text('Unable to load speakers'));
              }

              final list = snapshot.data is List ? snapshot.data as List : [];
              if (list.isEmpty) {
                return const Center(child: Text('No speakers announced yet'));
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                itemCount: list.length,
                itemBuilder: (context, index) {
                  final s = list[index];
                  final photoUrl = resolveSpeakerPhoto(s['photo']);

                  return Card(
                    elevation: 1.5,
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey[200]!),
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
                                width: 84,
                                height: 84,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: conference.primaryColor, width: 2.5),
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
                                      child: Icon(Icons.person, size: 42, color: conference.primaryColor),
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
                                        fontWeight: FontWeight.w800,
                                        color: conference.primaryColor,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: conference.primaryColor.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        '${s['designation'] ?? 'Speaker'}',
                                        style: TextStyle(
                                          color: conference.primaryColor,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      '${s['organization'] ?? 'Conference Guest'}',
                                      style: const TextStyle(
                                        fontSize: 13.5,
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
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.grey[200]!),
                              ),
                              child: Text(
                                '${s['bio']}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[800],
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
                                      side: BorderSide(color: Colors.grey[300]!),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    ),
                                    onPressed: () => launchUrl(Uri.parse('mailto:${s['email']}')),
                                  ),
                                if (s['phone'] != null && s['phone'].toString().isNotEmpty)
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.phone_outlined, size: 16, color: Colors.green),
                                    label: Text('${s['phone']}'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.black87,
                                      side: BorderSide(color: Colors.grey[300]!),
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

class NoticesScreen extends StatelessWidget {
  const NoticesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        children: [
          const Header(title: 'Notices'),
          Expanded(
            child: FutureBuilder(
              future: ApiService.get('/notices?conferenceId=1'),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return const Center(child: Text('Unable to load notices'));
                }

                final data = snapshot.data is List
                    ? snapshot.data as List
                    : <dynamic>[];

                if (data.isEmpty) {
                  return const Center(
                    child: Text(
                      'No Notices',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(18),
                  itemCount: data.length,
                  itemBuilder: (context, index) {
                    return Card(
                      child: ListTile(
                        leading: const Icon(
                          Icons.notifications,
                          color: maroon,
                        ),
                        title: Text(
                          '${data[index]['title'] ?? ''}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        subtitle: Text(
                          '${data[index]['message'] ?? ''}',
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
class GalleryScreen extends StatelessWidget{const GalleryScreen({super.key});@override Widget build(BuildContext c)=>SafeArea(top:false,child:Column(children:[const Header(title:'Event Gallery'),Expanded(child:FutureBuilder(future:ApiService.get('/gallery?conferenceId=1'),builder:(c,s){if(s.connectionState==ConnectionState.waiting)return const Center(child:CircularProgressIndicator());if(s.hasError)return const Center(child:Text('Unable to load gallery'));final d=s.data as List;return GridView.builder(padding:const EdgeInsets.all(10),gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:2,crossAxisSpacing:8,mainAxisSpacing:8),itemCount:d.length,itemBuilder:(c,i)=>ClipRRect(borderRadius:BorderRadius.circular(14),child:Image.network(d[i]['url'],fit:BoxFit.cover,errorBuilder:(_,__,___)=>Container(color:Colors.grey.shade200,child:const Icon(Icons.image)))));} ))]));}

class ChatScreen extends StatelessWidget{const ChatScreen({super.key});@override Widget build(BuildContext c)=>SafeArea(top:false,child:Column(children:[const Header(title:'Messages'),Expanded(child:ListView(padding:const EdgeInsets.all(18),children:[CardButton(icon:Icons.person,title:'Dr. Pallavi Kiran Shinde',subtitle:'Conference Liaison Faculty • Chat with your liaison',onTap:()=>Navigator.push(c,MaterialPageRoute(builder:(_)=>const ConversationScreen()))),const SizedBox(height:20),const Center(child:Text('Real-time chat is enabled by the backend Socket.IO layer.',style:TextStyle(color:muted)))]))]));}
class ConversationScreen extends StatefulWidget{const ConversationScreen({super.key});@override State<ConversationScreen> createState()=>_ConversationScreenState();}
class _ConversationScreenState extends State<ConversationScreen>{final t=TextEditingController();final messages=['Good morning! How can I help you?'];void send(){if(t.text.trim().isEmpty)return;setState((){messages.add(t.text.trim());t.clear();});} @override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:const Text('Dr. Pallavi Kiran Shinde')),body:Column(children:[Expanded(child:ListView.builder(padding:const EdgeInsets.all(16),itemCount:messages.length,itemBuilder:(c,i)=>Align(alignment:i.isEven?Alignment.centerLeft:Alignment.centerRight,child:Container(margin:const EdgeInsets.only(bottom:10),padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:i.isEven?Colors.white:maroon,borderRadius:BorderRadius.circular(16)),child:Text(messages[i],style:TextStyle(color:i.isEven?Colors.black:Colors.white))))),),Padding(padding:const EdgeInsets.all(12),child:Row(children:[Expanded(child:TextField(controller:t,decoration:const InputDecoration(hintText:'Message...',border:OutlineInputBorder()))),IconButton(onPressed:send,icon:const Icon(Icons.send,color:maroon))]))]));}

class ProfileScreen extends StatefulWidget{const ProfileScreen({super.key});@override State<ProfileScreen> createState()=>_ProfileScreenState();}
class _ProfileScreenState extends State<ProfileScreen>{Future<dynamic> load()=>ApiService.get('/me/profile');Future<void>logout()async{final p=await SharedPreferences.getInstance();await p.clear();if(mounted)Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder:(_)=>const AuthGate()),(_)=>false);} @override Widget build(BuildContext c)=>SafeArea(top:false,child:Column(children:[const Header(title:'My Profile'),Expanded(child:FutureBuilder(future:load(),builder:(c,s){if(s.connectionState==ConnectionState.waiting)return const Center(child:CircularProgressIndicator());if(s.hasError)return const Center(child:Text('Unable to load profile'));final x=s.data;return ListView(padding:const EdgeInsets.fromLTRB(20,20,20,90),children:[CircleAvatar(radius:48,backgroundImage:x['photo']!=null?NetworkImage(x['photo']):null,child:x['photo']==null?const Icon(Icons.person,size:48):null),const SizedBox(height:14),Text(x['name']??'',textAlign:TextAlign.center,style:const TextStyle(fontSize:30,fontWeight:FontWeight.w900)),Text(x['email']??'',textAlign:TextAlign.center,style:const TextStyle(color:muted)),const SizedBox(height:20),InfoSection(title:'BASIC INFORMATION',items:{'Role':x['role'],'Mobile No':x['phone'],'University':x['university'],'Designation':x['designation'],'Blood Group':x['blood_group'],'Registration No':x['registration_no']}),InfoSection(title:'ACCOMMODATION',items:{'Hotel':x['hotel_name'],'Room':x['room_number'],'Liaison':x['liaison_name'],'Liaison Phone':x['liaison_phone']}),InfoSection(title:'ARRIVAL DETAILS',items:{'Mode of Travel':x['mode_of_travel'],'Arrival Date':x['arrival_date'],'Arrival Time':x['arrival_time'],'Departure Date':x['departure_date'],'Departure Time':x['departure_time']}),OutlinedButton.icon(onPressed:logout,icon:const Icon(Icons.logout),label:const Text('Sign Out'))]);}))]));}
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
            letterSpacing: 1.4,
            color: muted,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: items.entries.map((entry) {
              return ListTile(
                title: Text(entry.key),
                trailing: SizedBox(
                  width: 170,
                  child: Text(
                    '${entry.value ?? '—'}',
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
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
class AccommodationScreen extends StatelessWidget{const AccommodationScreen({super.key});@override Widget build(BuildContext c)=>DetailApiPage(title:'Your Accommodation',path:'/me/accommodation',icon:Icons.hotel,empty:'No room assigned',fields:['hotel_name','room_number','room_type','address','check_in','check_out']);}
class TransportScreen extends StatelessWidget{const TransportScreen({super.key});@override Widget build(BuildContext c)=>ListApiPage(title:'Transport',path:'/me/transport',icon:Icons.directions_car,fields:['pickup_location','drop_location','pickup_time','vehicle_number','vehicle_type','driver_name','driver_phone','status']);}
class DutiesScreen extends StatelessWidget{const DutiesScreen({super.key});@override Widget build(BuildContext c)=>ListApiPage(title:'Duty Roster',path:'/me/duties',icon:Icons.assignment,fields:['title','location','duty_date','start_time','end_time','supervisor','status']);}
class AttendanceScreen extends StatelessWidget{const AttendanceScreen({super.key});@override Widget build(BuildContext c)=>ListApiPage(title:'My Attendance',path:'/me/attendance',icon:Icons.fact_check,fields:['title','session_date','start_time','scan_type','scanned_at']);}
class MealsScreen extends StatelessWidget{const MealsScreen({super.key});@override Widget build(BuildContext c)=>StaticMeals();}
class StaticMeals extends StatelessWidget{const StaticMeals({super.key});@override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:const Text('Meals')),body:ListView(padding:const EdgeInsets.all(18),children:const[Meal('Breakfast','07:00 – 09:00','Hyatt Regency',Icons.free_breakfast),Meal('Lunch','12:30 – 14:00','Conference Dining Hall',Icons.lunch_dining),Meal('High Tea','16:00 – 17:00','Foyer',Icons.local_cafe),Meal('Dinner','19:30 – 21:30','Hyatt Regency',Icons.dinner_dining)]));}
class Meal extends StatelessWidget{final String a,b,c;final IconData i;const Meal(this.a,this.b,this.c,this.i,{super.key});@override Widget build(BuildContext x)=>Card(child:ListTile(leading:Icon(i,color:maroon),title:Text(a,style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text('$b\n$c'),isThreeLine:true));}
class DigitalIdScreen extends StatelessWidget {
  const DigitalIdScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Digital Conference ID')),
      body: Center(
        child: FutureBuilder(
          future: ApiService.get('/me/registration'),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const CircularProgressIndicator();
            }

            if (snapshot.hasError) {
              return const Text('Unable to load ID');
            }

            final data = snapshot.data is Map
                ? snapshot.data as Map
                : <dynamic, dynamic>{};

            final qrData =
                data['qr_token'] ?? data['registration_no'] ?? 'DPU-QR';

            return Card(
              margin: const EdgeInsets.all(20),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if(ConferenceScope.of(context).logoUrl != null)
                      Image.network(ConferenceScope.of(context).logoUrl!, height: 60)
                    else
                      const Icon(Icons.account_balance, color: maroon, size: 42),
                    const SizedBox(height: 10),
                    Text(
                      ConferenceScope.of(context).shortName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: maroon, fontWeight: FontWeight.w900, fontSize: 20),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      '${data['participant_name'] ?? data['name'] ?? ''}',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      '${data['conference_name'] ?? ''}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Registration: ${data['registration_no'] ?? ''}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 18),
                    QrImageView(
                      data: qrData.toString(),
                      size: 190,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(color: maroon, borderRadius: BorderRadius.circular(20)),
                      child: Text(
                        '${data['category'] ?? ''}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
class CertificateScreen extends StatelessWidget{const CertificateScreen({super.key});@override Widget build(BuildContext c)=>DetailApiPage(title:'Certificate',path:'/me/certificate',icon:Icons.workspace_premium,empty:'Certificate not issued yet',fields:['certificate_no','issued_at','certificate_url']);}
class EmergencyScreen extends StatelessWidget{const EmergencyScreen({super.key});@override Widget build(BuildContext c){final conference=ConferenceScope.of(c);return Scaffold(appBar:AppBar(title:const Text('Emergency & Help')),body:ListView(padding:const EdgeInsets.all(18),children:[CardButton(icon:Icons.support_agent,title:'Conference Help Desk',subtitle:'1800123456',onTap:()=>launchUrl(Uri.parse('tel:1800123456'))),CardButton(icon:Icons.local_hospital,title:'Medical Emergency',subtitle:'Call 108',onTap:()=>launchUrl(Uri.parse('tel:108'))),CardButton(icon:Icons.security,title:'Security',subtitle:'Call 100',onTap:()=>launchUrl(Uri.parse('tel:100'))),CardButton(icon:Icons.location_on,title:'Venue Map',subtitle:'Open in Google Maps',onTap:()=>launchUrl(Uri.parse(conference.mapUrl),mode:LaunchMode.externalApplication))]));}}

class SimplePage extends StatelessWidget{final String title;final Future future;final Widget Function(dynamic) builder;const SimplePage({super.key,required this.title,required this.future,required this.builder});@override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:Text(title)),body:FutureBuilder(future:future,builder:(c,s){if(s.connectionState==ConnectionState.waiting)return const Center(child:CircularProgressIndicator());if(s.hasError)return const Center(child:Text('Unable to load data'));final d=s.data as List;return ListView.separated(padding:const EdgeInsets.all(18),itemCount:d.length,separatorBuilder:(_,__)=>const SizedBox(height:8),itemBuilder:(c,i)=>Card(child:builder(d[i]))); }));}
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
      appBar: AppBar(title: Text(title)),
      body: FutureBuilder(
        future: ApiService.get(path),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text('Unable to load details'));
          }

          if (snapshot.data == null) {
            return Center(child: Text(empty));
          }

          final data = snapshot.data is Map
              ? snapshot.data as Map
              : <dynamic, dynamic>{};

          if (data.isEmpty) {
            return Center(child: Text(empty));
          }

          return ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Card(
                child: Column(
                  children: fields.map((field) {
                    return ListTile(
                      leading: Icon(icon, color: maroon),
                      title: Text(
                        field.replaceAll('_', ' ').toUpperCase(),
                      ),
                      subtitle: Text(
                        '${data[field] ?? '—'}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
class ListApiPage extends StatelessWidget{final String title,path;final IconData icon;final List<String>fields;const ListApiPage({super.key,required this.title,required this.path,required this.icon,required this.fields});@override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:Text(title)),body:FutureBuilder(future:ApiService.get(path),builder:(c,s){if(s.connectionState==ConnectionState.waiting)return const Center(child:CircularProgressIndicator());if(s.hasError)return const Center(child:Text('Unable to load details'));final d=s.data as List;if(d.isEmpty)return const Center(child:Text('No records found'));return ListView.builder(padding:const EdgeInsets.all(18),itemCount:d.length,itemBuilder:(c,i)=>Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(children:fields.map((f)=>ListTile(dense:true,leading:Icon(icon,color:maroon),title:Text(f.replaceAll('_',' ')),trailing:SizedBox(width:190,child:Text('${d[i][f]??'—'}',textAlign:TextAlign.right,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.w700))))).toList()))));}));}
