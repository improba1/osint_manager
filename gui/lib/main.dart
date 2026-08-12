import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:osint_frontend/screens/username_search.dart';
import 'package:osint_frontend/screens/email_search.dart';
import 'package:osint_frontend/screens/phone_search.dart';
import 'package:osint_frontend/screens/exif_search.dart';

void main() {
  runApp(const OsintApp());
}

class OsintApp extends StatefulWidget {
  const OsintApp({super.key});

  @override
  State<OsintApp> createState() => _OsintAppState();
}

class _OsintAppState extends State<OsintApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
  }

  ThemeData get _lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF8FAFC), 
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF2563EB), 
        surface: Color(0xFFFFFFFF), 
        error: Color(0xFFDC2626),
      ),
      textTheme: GoogleFonts.shareTechMonoTextTheme(ThemeData.light().textTheme),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFFFFFFF),
        labelStyle: const TextStyle(color: Color(0xFF64748B)),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.0),
          borderRadius: BorderRadius.circular(6),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2.0),
          borderRadius: BorderRadius.circular(6),
        ),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFFFFFFFF),
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }

  ThemeData get _darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0F172A), 
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF3B82F6), 
        surface: Color(0xFF1E293B), 
        error: Color(0xFFEF4444),
      ),
      textTheme: GoogleFonts.shareTechMonoTextTheme(ThemeData.dark().textTheme),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1E293B),
        labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFF334155), width: 1.0),
          borderRadius: BorderRadius.circular(6),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2.0),
          borderRadius: BorderRadius.circular(6),
        ),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1E293B),
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: Color(0xFF334155)),
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OSINT Platform',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: _lightTheme,
      darkTheme: _darkTheme,
      home: MainDashboard(
        isDarkMode: _themeMode == ThemeMode.dark,
        onToggleTheme: _toggleTheme,
      ),
    );
  }
}

class MainDashboard extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  const MainDashboard({super.key, required this.isDarkMode, required this.onToggleTheme});

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  int _selectedIndex = 0;

  Widget _buildDashboardContent() {
    switch (_selectedIndex) {
      case 0:
        return const UsernameSearchScreen(key: ValueKey('USERNAME'));
      case 1:
        return const EmailSearchScreen(key: ValueKey('EMAIL'));
      case 2:
        return const PhoneSearchScreen(key: ValueKey('PHONE'));
      case 3:
        return const ExifAnalysisScreen(key: ValueKey('EXIF'));
      default:
        return const Center(child: Text('Unknown Module'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            backgroundColor: theme.colorScheme.surface,
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() { _selectedIndex = index; });
            },
            useIndicator: true,
            indicatorColor: theme.colorScheme.primary.withOpacity(0.15),
            unselectedIconTheme: IconThemeData(color: theme.brightness == Brightness.dark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
            selectedIconTheme: IconThemeData(color: theme.colorScheme.primary, size: 28),
            unselectedLabelTextStyle: TextStyle(color: theme.brightness == Brightness.dark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
            selectedLabelTextStyle: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
            labelType: NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: Icon(Icons.shield, color: theme.colorScheme.primary, size: 36),
            ),
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: IconButton(
                    icon: Icon(widget.isDarkMode ? Icons.light_mode : Icons.dark_mode),
                    color: theme.iconTheme.color,
                    onPressed: widget.onToggleTheme,
                    tooltip: 'Toggle Theme',
                  ),
                ),
              ),
            ),
            destinations: const [
              NavigationRailDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: Text('Identity')),
              NavigationRailDestination(icon: Icon(Icons.email_outlined), selectedIcon: Icon(Icons.email), label: Text('Mail')),
              NavigationRailDestination(icon: Icon(Icons.phone_outlined), selectedIcon: Icon(Icons.phone), label: Text('Telecom')),
              NavigationRailDestination(icon: Icon(Icons.memory_outlined), selectedIcon: Icon(Icons.memory), label: Text('Forensics')),
            ],
          ),
          VerticalDivider(thickness: 1, width: 1, color: theme.dividerColor.withOpacity(0.1)),
          Expanded(
            child: Container(
              color: theme.scaffoldBackgroundColor,
              child: Padding(
                padding: const EdgeInsets.all(40.0),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _buildDashboardContent(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}