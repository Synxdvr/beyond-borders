import 'package:beyond_borders/pages/community.dart';
import 'package:beyond_borders/pages/notifications.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:beyond_borders/components/custom_drawer.dart';
import 'package:beyond_borders/services/auth_wrapper.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:lottie/lottie.dart';
import 'package:firebase_core/firebase_core.dart';
// Remove this line: import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:beyond_borders/authentication/login.dart';
import 'package:beyond_borders/authentication/main_page.dart';
import 'package:beyond_borders/pages/destinations.dart';
import 'package:beyond_borders/pages/about.dart';
import 'package:beyond_borders/pages/profile.dart';
import 'package:beyond_borders/pages/settings.dart';
import 'package:beyond_borders/pages/wishlist.dart';
import 'package:beyond_borders/authentication/forgot_password.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart'; // Add this for kIsWeb

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyDmHsaXh1Om-eiaA9l78A0y_nM4_qNecxc", // Paste your API Key here
        authDomain: "test-project-60c5e.firebaseapp.com",
        projectId: "test-project-60c5e",
        storageBucket: "test-project-60c5e.firebasestorage.app",
        messagingSenderId: "472457433132",
        appId: "1:472457433132:web:a07489ceb3131707008189",
      ),
    );
  } else {
    // Android/iOS still use the auto-config
    await Firebase.initializeApp();
  }

  await dotenv.load();
  runApp(const MyApp());
}



class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    // Remove dynamic links initialization
    // _initializeDynamicLinks();
  }

  // Remove the entire _initializeDynamicLinks method
  // Remove the entire _handleDynamicLink method

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: 'Poppins'),
      initialRoute: '/loading',
      routes: {
        '/loading': (context) => LoadingScreen(),
        '/login': (context) => Login(),
        '/onboarding': (context) => OnboardingScreen(),
        '/destinations': (context) => Destination(),
        '/about': (context) => about(),
        '/auth': (context) => AuthWrapper(),
        '/profile': (context) => Profile(),
        '/community': (context) => CommunityPage(),
        '/notifications': (context) => NotificationsPage(),
        '/settings': (context) => SettingsPage(),
        '/forgot-password': (context) => ForgotPasswordScreen(),
      },
      home: AuthWrapper(),
    );
  }
}

class LoadingScreen extends StatefulWidget {
  @override
  _LoadingScreenState createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(seconds: 5), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomeWithDrawer()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset("assets/animations/loading.json", width: 200, height: 200, fit: BoxFit.contain),
            SizedBox(height: 20),
            Text("Loading...", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class HomeWithDrawer extends StatefulWidget {
  const HomeWithDrawer({super.key});

  @override
  _HomeWithDrawerState createState() => _HomeWithDrawerState();
}

class _HomeWithDrawerState extends State<HomeWithDrawer> {
  int _selectedIndex = 0;
  final List<Widget> _pages = [
    Destination(),
    WishlistPage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Using StreamBuilder to reactively listen for changes in authentication state
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Show loading spinner while checking auth state
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData || snapshot.data == null) {
          // If user is not logged in, redirect to OnboardingScreen
          return OnboardingScreen();
        }

        // If logged in, display the HomeWithDrawer content with bottom navigation
        return Scaffold(
          drawer: CustomDrawer(),
          body: _pages[_selectedIndex],
          bottomNavigationBar: BottomNavigationBar(
            selectedItemColor: Colors.blue,
            unselectedItemColor: Colors.grey,
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.explore), label: 'Explore'),
              BottomNavigationBarItem(icon: Icon(Icons.favorite_border), label: 'Wishlist'),
            ],
          ),
        );
      },
    );
  }
}