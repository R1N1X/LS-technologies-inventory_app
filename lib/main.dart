
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ls_tech_app/screens/home_screen.dart';
import 'package:ls_tech_app/screens/register_screen.dart';
import 'package:ls_tech_app/screens/inward_screen.dart';
import 'package:ls_tech_app/screens/outward_screen.dart';
import 'package:ls_tech_app/screens/inventory_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LS Technology',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
        useMaterial3: true,
        textTheme: GoogleFonts.interTextTheme(
          Theme.of(context).textTheme,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF1F2937),
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: Color(0xFF374151)),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),
        '/register': (context) => const RegisterScreen(),
        '/inward': (context) => const InwardScreen(),
        '/outward': (context) => const OutwardScreen(),
        '/inventory': (context) => const InventoryScreen(),
      },
    );
  }
}
