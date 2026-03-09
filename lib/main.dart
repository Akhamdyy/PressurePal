import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'config/theme.dart';
import 'config/translations.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'services/notification_service.dart';
import 'services/biometric_service.dart'; 


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  tz.initializeTimeZones();
  try {
    await Supabase.initialize(
      url: 'https://hcgnkywynqwuyjiahywb.supabase.co',       
      anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '', 
    );
    await NotificationService.init();
  } catch (e) {
    debugPrint("Startup Error: $e");
  }
  runApp(const HealthApp());
}

class HealthApp extends StatelessWidget {
  const HealthApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: languageNotifier,
      builder: (context, langCode, child) {
        return ValueListenableBuilder<ThemeMode>(
          valueListenable: themeNotifier,
          builder: (context, currentMode, child) {
            return MaterialApp(
              title: 'PressurePal',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: currentMode,
              locale: Locale(langCode), 
              supportedLocales: const [Locale('en'), Locale('ar')],
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: const AuthGate(),
            );
          },
        );
      },
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // IF LOGGED IN -> GO TO BIOMETRIC GATE
        if (snapshot.data?.session != null) {
          return const BiometricGate(); 
        } 
        // IF LOGGED OUT -> GO TO LOGIN
        return const LoginScreen();
      },
    );
  }
}

// --- NEW CLASS: The "Face Unlock" Screen ---
class BiometricGate extends StatefulWidget {
  const BiometricGate({super.key});

  @override
  State<BiometricGate> createState() => _BiometricGateState();
}

class _BiometricGateState extends State<BiometricGate> {
  bool _isLocked = true; // Assume locked initially
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('biometrics_enabled') ?? false;

    if (!enabled) {
      // Feature is OFF, let them in
      if (mounted) setState(() { _isLocked = false; _isLoading = false; });
      return;
    }

    // Feature is ON, try to authenticate
    bool authenticated = await BiometricService.authenticate();
    
    if (authenticated) {
      if (mounted) setState(() { _isLocked = false; _isLoading = false; });
    } else {
      // Failed or Cancelled. Keep locked, stop loading.
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_isLocked) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 80, color: Colors.grey),
              const SizedBox(height: 20),
              const Text("PressurePal Locked", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _checkBiometrics, // Try again
                icon: const Icon(Icons.face),
                label: const Text("Unlock"),
              ),
            ],
          ),
        ),
      );
    }

    // If not locked, show the Home Screen
    return const HomeScreen(); 
  }
}