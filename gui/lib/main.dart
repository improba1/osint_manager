import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';

void main() {
  runApp(const OsintApp());
}

class OsintApp extends StatefulWidget {
  const OsintApp({super.key});

  @override
  State<OsintApp> createState() => _OsintAppState();
}

class _OsintAppState extends State<OsintApp> {
  Color _accentColor = const Color(0xFFD500F9);

  void _updateAccentColor(Color newColor) {
    setState(() {
      _accentColor = newColor;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OSINT Dashboard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF000000),
        primaryColor: _accentColor,
        colorScheme: ColorScheme.dark(
          primary: _accentColor,
          secondary: _accentColor.withOpacity(0.6),
          surface: const Color(0xFF0A0A0A),
        ),
        textTheme: GoogleFonts.shareTechMonoTextTheme(
          ThemeData.dark().textTheme,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF121212),
          labelStyle: TextStyle(color: _accentColor),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: _accentColor.withOpacity(0.4), width: 1.0),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: _accentColor, width: 2.0),
          ),
        ),
      ),
      home: MainDashboard(
        currentAccentColor: _accentColor,
        onColorChanged: _updateAccentColor,
      ),
    );
  }
}

class MainDashboard extends StatefulWidget {
  final Color currentAccentColor;
  final Function(Color) onColorChanged;

  const MainDashboard({
    super.key, 
    required this.currentAccentColor, 
    required this.onColorChanged
  });

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  int _selectedIndex = 0;

  final List<Color> _colorPresets = [
    const Color(0xFFD500F9), // SYNTHWAVE PURPLE
    const Color(0xFF00FF41), // MATRIX GREEN
    const Color(0xFF00E5FF), // CYBERPUNK CYAN
    const Color(0xFFFF9100), // TACTICAL ORANGE
  ];

  String _getColorName(Color color) {
    if (color == const Color(0xFFD500F9)) return 'SYNTHWAVE';
    if (color == const Color(0xFF00FF41)) return 'MATRIX';
    if (color == const Color(0xFF00E5FF)) return 'CYBERPUNK';
    if (color == const Color(0xFFFF9100)) return 'TACTICAL';
    return 'UNKNOWN';
  }

  Widget _buildDashboardContent() {
    switch (_selectedIndex) {
      case 0:
        return UsernameSearchPanel(
          key: const ValueKey('USERNAME'),
          accentColor: widget.currentAccentColor,
        );
      case 1:
        return _buildPlaceholderPanel('EMAIL INTELLIGENCE', 'Enter target email address...', Icons.email);
      case 2:
        return _buildPlaceholderPanel('PHONE LOOKUP', 'Enter phone number...', Icons.phone);
      case 3:
        return _buildFileAnalysisPanel();
      default:
        return const Center(child: Text('Unknown Module'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            backgroundColor: const Color(0xFF0A0A0A),
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            unselectedIconTheme: const IconThemeData(color: Colors.white30),
            selectedIconTheme: IconThemeData(color: widget.currentAccentColor, size: 30),
            unselectedLabelTextStyle: const TextStyle(color: Colors.white30),
            selectedLabelTextStyle: TextStyle(
              color: widget.currentAccentColor, 
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
            labelType: NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20.0),
              child: Icon(Icons.radar, color: widget.currentAccentColor, size: 40),
            ),
            
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: PopupMenuButton<Color>(
                    tooltip: 'Change Theme Color',
                    offset: const Offset(60, -40), 
                    color: const Color(0xFF121212),
                    icon: Icon(Icons.palette_outlined, color: widget.currentAccentColor, size: 26),
                    onSelected: widget.onColorChanged,
                    itemBuilder: (BuildContext context) {
                      return _colorPresets.map((Color color) {
                        final bool isCurrent = widget.currentAccentColor == color;
                        return PopupMenuItem<Color>(
                          value: color,
                          child: Row(
                            children: [
                              Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                _getColorName(color),
                                style: TextStyle(
                                  color: isCurrent ? color : Colors.white,
                                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
            
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: Text('Username'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.email_outlined),
                selectedIcon: Icon(Icons.email),
                label: Text('Email'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.phone_outlined),
                selectedIcon: Icon(Icons.phone),
                label: Text('Phone'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.insert_drive_file_outlined),
                selectedIcon: Icon(Icons.insert_drive_file),
                label: Text('EXIF Data'),
              ),
            ],
          ),
          VerticalDivider(thickness: 1, width: 1, color: widget.currentAccentColor.withOpacity(0.3)),
          
          Expanded(
            child: Container(
              color: const Color(0xFF000000),
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _buildDashboardContent(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderPanel(String title, String hintText, IconData icon) {
    return Column(
      key: ValueKey<String>(title),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: widget.currentAccentColor, size: 32),
            const SizedBox(width: 16),
            Text(title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2.0)),
          ],
        ),
        const Expanded(
          child: Center(
            child: Text('MODULE OFFLINE', style: TextStyle(color: Colors.white24, fontSize: 24, letterSpacing: 4)),
          ),
        ),
      ],
    );
  }

  Widget _buildFileAnalysisPanel() {
    return Column(
      key: const ValueKey<String>('FILE'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.memory, color: widget.currentAccentColor, size: 32),
            const SizedBox(width: 16),
            const Text('METADATA EXTRACTION', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2.0)),
          ],
        ),
        const SizedBox(height: 32),
        Container(
          width: double.infinity,
          height: 200,
          decoration: BoxDecoration(
            color: const Color(0xFF121212),
            border: Border.all(color: widget.currentAccentColor.withOpacity(0.4), width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.upload_file, size: 64, color: widget.currentAccentColor.withOpacity(0.6)),
              const SizedBox(height: 16),
              Text('CLICK TO SELECT FILE OR DROP HERE', style: TextStyle(color: widget.currentAccentColor, fontSize: 18)),
            ],
          ),
        ),
      ],
    );
  }
}

class UsernameSearchPanel extends StatefulWidget {
  final Color accentColor;
  const UsernameSearchPanel({super.key, required this.accentColor});

  @override
  State<UsernameSearchPanel> createState() => _UsernameSearchPanelState();
}

class _UsernameSearchPanelState extends State<UsernameSearchPanel> {
  final TextEditingController _usernameController = TextEditingController();
  bool _isLoading = false;
  bool _showOnlyFound = false;
  final List<Map<String, dynamic>> _liveResults = [];
  WebSocketChannel? _channel; 

  void _startLiveSearch() {
    if (_usernameController.text.isEmpty) return;

    setState(() {
      _isLoading = true;
      _liveResults.clear();
    });

    try {
      _channel = WebSocketChannel.connect(
        Uri.parse('ws://127.0.0.1:8000/api/username'),
      );

      _channel!.sink.add(jsonEncode({'username': _usernameController.text}));

      _channel!.stream.listen(
        (message) {
          try {
            final Map<String, dynamic> data = Map<String, dynamic>.from(jsonDecode(message));

            if (data['status'] == 'COMPLETED' || data['status'] == 'ERROR') {
              setState(() { _isLoading = false; });
              if (data['status'] == 'ERROR') _liveResults.add(data);
              _channel!.sink.close();
            } else {
              setState(() { _liveResults.add(data); });
            }
          } catch (e) {
            print("Parsing error: $e");
          }
        },
        onError: (err) { setState(() { _isLoading = false; }); },
        onDone: () { setState(() { _isLoading = false; }); }
      );
    } catch (e) {
      setState(() { _isLoading = false; });
      print("WebSocket error: $e");
    }
  }

  @override
  void dispose() {
    _channel?.sink.close();
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.person, color: widget.accentColor, size: 32),
            const SizedBox(width: 16),
            const Text(
              'USERNAME SEARCH',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2.0),
            ),
          ],
        ),
        const SizedBox(height: 32),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: _usernameController,
                style: TextStyle(color: widget.accentColor, fontSize: 18),
                cursorColor: widget.accentColor,
                decoration: InputDecoration(
                  labelText: 'Enter target username...',
                  prefixIcon: Icon(Icons.terminal, color: widget.accentColor.withOpacity(0.6)),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 1,
              child: SizedBox(
                height: 58,
                child: _isLoading 
                  ? Center(child: CircularProgressIndicator(color: widget.accentColor))
                  : ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.accentColor.withOpacity(0.1),
                        foregroundColor: widget.accentColor,
                        side: BorderSide(color: widget.accentColor),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                      onPressed: _startLiveSearch,
                      icon: const Icon(Icons.search),
                      label: const Text('INITIATE', style: TextStyle(fontSize: 18)),
                    ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_liveResults.isNotEmpty || _isLoading)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text('SHOW ONLY FOUND', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
              Switch(
                value: _showOnlyFound,
                activeColor: const Color(0xFF00FF41), 
                onChanged: (value) {
                  setState(() { _showOnlyFound = value; });
                },
              ),
            ],
          ),
        const SizedBox(height: 16),
        Expanded(child: _buildResultsArea()),
      ],
    );
  }

  Widget _buildResultsArea() {
    if (_liveResults.isEmpty && !_isLoading) {
      return const Center(
        child: Text('AWAITING INPUT...', style: TextStyle(color: Colors.white24, fontSize: 24, letterSpacing: 4)),
      );
    }

    List<Map<String, dynamic>> displayResults = _liveResults;
    if (_showOnlyFound) {
      displayResults = displayResults.where((site) {
        final status = site['status']?.toString().toLowerCase() ?? '';
        return status == 'found' || status == 'success' || status == 'true' || status == '200';
      }).toList();
    }
    
    if (displayResults.isEmpty && _isLoading) {
       return Center(
        child: Text('SEARCHING DATABASE...', style: TextStyle(color: widget.accentColor, fontSize: 18)),
      );
    }

    return ListView.builder(
      itemCount: displayResults.length,
      itemBuilder: (context, index) {
        final site = displayResults[index];
        final statusStr = site['status']?.toString().toLowerCase() ?? '';
        final bool isFound = statusStr == 'found' || statusStr == 'success' || statusStr == 'true' || statusStr == '200';
        
        final statusColor = isFound ? const Color(0xFF00FF41) : Colors.redAccent.withOpacity(0.8);

        return Card(
          color: const Color(0xFF0A0A0A), 
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            side: BorderSide(color: isFound ? const Color(0xFF00FF41).withOpacity(0.3) : const Color(0xFF1A1A1A)),
            borderRadius: BorderRadius.circular(4)
          ),
          child: ListTile(
            onTap: () async {
              final urlStr = site['url'];
              if (urlStr != null && urlStr.isNotEmpty) {
                final Uri url = Uri.parse(urlStr);
                if (await canLaunchUrl(url)) await launchUrl(url);
              }
            },
            mouseCursor: SystemMouseCursors.click, 
            leading: Icon(isFound ? Icons.check_circle : Icons.error_outline, color: statusColor),
            title: Text(
              site['service_name'] ?? 'Unknown',
              style: TextStyle(color: isFound ? Colors.white : Colors.white54, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              site['url'] ?? '',
              style: const TextStyle(color: Colors.blueAccent, decoration: TextDecoration.underline, fontSize: 13),
            ),
            trailing: Text(
              (site['status'] ?? '').toString().toUpperCase(),
              style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
            ),
          ),
        );
      },
    );
  }
}