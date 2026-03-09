import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// 1. The Global Theme Switcher
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

class AppTheme {
  // --- COLORS ---
  static const primaryColor = Color(0xFFD32F2F); // Medical Red
  static const secondaryColor = Color(0xFF009688); // Teal
  
  // --- LIGHT THEME ---
  // --- LIGHT THEME ---
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      textTheme: GoogleFonts.poppinsTextTheme(),
      primaryColor: primaryColor,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
        // FORCE THE FAB TO BE RED IN LIGHT MODE:
        primary: primaryColor, 
        secondary: secondaryColor,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 20),
        iconTheme: IconThemeData(color: Colors.black),
      ),
      // --- FIX 1: Make background slightly darker so cards stand out ---
      scaffoldBackgroundColor: const Color(0xFFEEEEEE), 
      
      cardTheme: const CardThemeData(
        color: Colors.white, // Ensure cards are pure white
        elevation: 0, 
        // We handle shape/shadow manually in the UI, but this is a good default
      ),
      
      // --- FIX 2: Force "Add Log" button to be Red with White text ---
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
    );
  }

  // --- DARK THEME (NEW!) ---
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
      primaryColor: primaryColor,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.dark,
        surface: const Color(0xFF1E1E1E), // Dark Grey Cards
      ),
      scaffoldBackgroundColor: const Color(0xFF121212), // Almost Black
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        backgroundColor: Color(0xFF121212),
        elevation: 0,
        titleTextStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1E1E1E),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      // Fix Bottom Sheet color in Dark Mode
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xFF1E1E1E),
        modalBackgroundColor: Color(0xFF1E1E1E),
      ),
    );
  }
}