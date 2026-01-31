
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header with Logo
            Container(
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
              ),
              width: double.infinity,
              child: Column(
                children: [
                  Image.asset(
                    'assets/logo.png',
                    height: 80, // Adjust size as needed
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'LS TECHNOLOGY',
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1F2937),
                    ),
                  ),
                  Text(
                    'INVENTORY APP',
                     style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF6B7280),
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _buildMenuItem(
                    context,
                    title: 'Register New Item',
                    description: 'Add products and generate QR codes',
                    icon: Icons.add_circle,
                    color: const Color(0xFF2563EB),
                    route: '/register',
                  ),
                  const SizedBox(height: 16),
                  _buildMenuItem(
                    context,
                    title: 'Outward',
                    description: 'Scan QR codes to process outward',
                    icon: Icons.qr_code_scanner,
                    color: const Color(0xFF059669),
                    route: '/outward',
                  ),
                  const SizedBox(height: 16),
                  _buildMenuItem(
                    context,
                    title: 'Inward',
                    description: 'Add inventory to existing products',
                    icon: Icons.arrow_circle_down,
                    color: const Color(0xFF7C3AED),
                    route: '/inward',
                  ),
                  const SizedBox(height: 16),
                  _buildMenuItem(
                    context,
                    title: 'View Inventory',
                    description: 'View all products and stock levels',
                    icon: Icons.list_alt,
                    color: const Color(0xFFDC2626),
                    route: '/inventory',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required String route,
  }) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, route),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              offset: const Offset(0, 2),
              blurRadius: 3.84,
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              child: Icon(icon, size: 32, color: color),
            ),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1F2937),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFF6B7280),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
