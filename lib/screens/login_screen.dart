import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/biometric_service.dart'; // <--- NEW: Import the service

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isLoading = false;
  bool _isSignUp = false;
  
  final _storage = const FlutterSecureStorage();

  Future<void> _handleAuth() async {
    setState(() => _isLoading = true);
    try {
      if (_isSignUp) {
        await Supabase.instance.client.auth.signUp(
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text.trim(),
        );
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account created! Logging in...')));
        await _saveCredentials(); 
      } else {
        await Supabase.instance.client.auth.signInWithPassword(
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text.trim(),
        );
        await _saveCredentials();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveCredentials() async {
    await _storage.write(key: 'email', value: _emailCtrl.text.trim());
    await _storage.write(key: 'password', value: _passCtrl.text.trim());
  }

  Future<void> _checkBiometrics() async {
    try {
      // 1. Use the Service to check availability
      final bool isSupported = await BiometricService.isDeviceSupported();
      
      if (!isSupported) {
         if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No biometric sensor found.')));
         return;
      }

      // 2. Use the Service to Authenticate (Fixes the crash!)
      final bool didAuthenticate = await BiometricService.authenticate();

      if (didAuthenticate) {
        final savedEmail = await _storage.read(key: 'email');
        final savedPassword = await _storage.read(key: 'password');

        if (savedEmail != null && savedPassword != null) {
          setState(() => _isLoading = true);
          await Supabase.instance.client.auth.signInWithPassword(
            email: savedEmail,
            password: savedPassword,
          );
        } else {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No saved login found. Please log in manually once.')));
        }
      }
    } catch (e) {
      debugPrint("Biometric Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.favorite_rounded, size: 80, color: Theme.of(context).primaryColor),
              const SizedBox(height: 20),
              Text(
                _isSignUp ? "Create Account" : "Welcome Back",
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text("Track your heart health securely.", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 40),
              TextField(
                controller: _emailCtrl,
                decoration: const InputDecoration(labelText: "Email", prefixIcon: Icon(Icons.email_outlined)),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _passCtrl,
                decoration: const InputDecoration(labelText: "Password", prefixIcon: Icon(Icons.lock_outline)),
                obscureText: true,
              ),
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                child: _isLoading 
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _handleAuth,
                      child: Text(_isSignUp ? "Sign Up" : "Log In"),
                    ),
              ),
              const SizedBox(height: 20),
              if (!_isLoading)
                IconButton(
                  icon: Icon(Icons.fingerprint, size: 60, color: Theme.of(context).primaryColor),
                  onPressed: _checkBiometrics,
                  tooltip: "Log in with Biometrics",
                ),
              TextButton(
                onPressed: () => setState(() => _isSignUp = !_isSignUp),
                child: Text(_isSignUp ? "Already have an account? Log In" : "New user? Create Account"),
              )
            ],
          ),
        ),
      ),
    );
  }
}