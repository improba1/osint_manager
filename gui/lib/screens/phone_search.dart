import 'package:flutter/material.dart';
import 'package:osint_frontend/api_service.dart';
import 'package:url_launcher/url_launcher.dart';

class PhoneSearchScreen extends StatefulWidget {
  const PhoneSearchScreen({super.key});

  @override
  State<PhoneSearchScreen> createState() => _PhoneSearchScreenState();
}

class _PhoneSearchScreenState extends State<PhoneSearchScreen> {
  final TextEditingController _phoneController = TextEditingController();
  
  bool _isScanning = false;
  bool _fetchTelegram = false;
  String _statusMessage = 'AWAITING TARGET PHONE...';

  Map<String, dynamic>? _validResult;
  Map<String, dynamic>? _countryResult;
  Map<String, dynamic>? _dorksResult;
  Map<String, dynamic>? _viberResult;
  Map<String, dynamic>? _tgChatResult;
  Map<String, dynamic>? _waResult;
  Map<String, dynamic>? _tgProfileResult;

  void _toggleTelegramSearch(bool value) async {
    setState(() {
      _fetchTelegram = value;
    });

    if (value && _validResult?['is_valid'] == true && _tgProfileResult == null) {
      setState(() {
        _isScanning = true;
        _statusMessage = 'EXTRACTING TELEGRAM PROFILE...';
      });
      
      try {
        final tgRes = await ApiService().checkPhoneTelegramProfile(_phoneController.text.trim());
        if (mounted) {
          setState(() {
            _tgProfileResult = tgRes['results'];
            _isScanning = false;
          });
        }
      } catch (e) {
        if (mounted) setState(() { _isScanning = false; });
      }
    }
  }

  void _startAnalysis() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) return;

    final phoneRegExp = RegExp(r'^\+[0-9]+$');
    if (!phoneRegExp.hasMatch(phone)) {
      setState(() {
        _statusMessage = 'ERROR: INVALID FORMAT. MUST START WITH "+" FOLLOWED BY DIGITS ONLY.';
        _validResult = null; 
      });
      return;
    }

    setState(() {
      _validResult = null;
      _countryResult = null;
      _dorksResult = null;
      _viberResult = null;
      _tgChatResult = null;
      _waResult = null;
      _tgProfileResult = null;
      _isScanning = true;
      _statusMessage = 'STAGE 1: VALIDATING PHONE NUMBER...';
    });

    final api = ApiService();

    try {
      final validRes = await api.checkPhoneValid(phone);
      if (!mounted) return;

      setState(() { _validResult = validRes['results']; });

      if (_validResult?['is_valid'] != true) {
        setState(() {
          _statusMessage = 'OSINT HALTED: PHONE NUMBER IS INVALID OR DISCONNECTED';
          _isScanning = false;
        });
        return; 
      }

      setState(() { _statusMessage = 'STAGE 2: EXTRACTING TELECOM DATA & GENERATING LINKS...'; });

      final basicResults = await Future.wait([
        api.checkPhoneCountry(phone),
        api.checkPhoneDorks(phone),
        api.checkPhoneViber(phone),
        api.checkPhoneTelegramChat(phone),
        api.checkPhoneWhatsapp(phone),
      ]);

      if (!mounted) return;

      setState(() {
        _countryResult = basicResults[0]['results'];
        _dorksResult = basicResults[1]['results'];
        _viberResult = basicResults[2]['results'];
        _tgChatResult = basicResults[3]['results'];
        _waResult = basicResults[4]['results'];
      });

      if (_fetchTelegram) {
        setState(() { _statusMessage = 'STAGE 3: DEEP TELEGRAM RECONNAISSANCE...'; });
        final tgRes = await api.checkPhoneTelegramProfile(phone);
        if (mounted) {
          setState(() { _tgProfileResult = tgRes['results']; });
        }
      }

      setState(() { _isScanning = false; });

    } catch (e) {
      if (mounted) {
        setState(() {
          _isScanning = false;
          _statusMessage = 'ERROR: API CONNECTION FAILED';
        });
      }
    }
  }

  Future<void> _launchURL(String? urlString) async {
    if (urlString == null || urlString.isEmpty) return;
    final Uri url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      key: const ValueKey('PHONE'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.phone, color: colorScheme.primary, size: 28),
            const SizedBox(width: 16),
            Text(
              'TELECOM RECONNAISSANCE',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color, letterSpacing: 1.5),
            ),
          ],
        ),
        const SizedBox(height: 32),
        
        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: 'Target Phone (e.g., +1234567890)',
                  prefixIcon: Icon(Icons.dialpad, color: colorScheme.primary),
                ),
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              height: 56,
              width: 180,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                onPressed: _isScanning ? null : _startAnalysis,
                icon: _isScanning 
                  ? Container(width: 20, height: 20, padding: const EdgeInsets.all(2), child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.radar),
                label: Text(_isScanning ? 'SCANNING' : 'EXECUTE', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
        
        Padding(
          padding: const EdgeInsets.only(top: 16.0),
          child: Row(
            children: [
              Switch(
                value: _fetchTelegram,
                activeColor: colorScheme.primary,
                onChanged: _isScanning ? null : _toggleTelegramSearch,
              ),
              const SizedBox(width: 8),
              Text(
                'ENABLE DEEP TELEGRAM PROFILE EXTRACTION',
                style: TextStyle(color: theme.textTheme.bodyMedium?.color, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        
        Expanded(
          child: _validResult == null && !_isScanning
              ? Center(
                  child: Text(
                    _statusMessage, 
                    style: TextStyle(
                      color: _statusMessage.contains('ERROR') ? colorScheme.error : theme.disabledColor, 
                      fontSize: _statusMessage.contains('ERROR') ? 16 : 18, 
                      letterSpacing: 1.5,
                      fontWeight: _statusMessage.contains('ERROR') ? FontWeight.bold : FontWeight.normal
                    )
                  )
                )
              : ListView(
                  children: [
                    _buildBasicInfoCard(theme),
                    
                    if (_validResult != null && !(_validResult?['is_valid'] == true))
                      Padding(
                        padding: const EdgeInsets.only(top: 32),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            decoration: BoxDecoration(
                              color: colorScheme.error.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: colorScheme.error.withOpacity(0.3)),
                            ),
                            child: Text(
                              'OSINT HALTED: PHONE NUMBER IS INVALID', 
                              style: TextStyle(color: colorScheme.error, fontSize: 14, fontWeight: FontWeight.bold)
                            ),
                          ),
                        ),
                      ),

                    if (_validResult?['is_valid'] == true) _buildActionsCard(theme),
                    if (_tgProfileResult != null) _buildTelegramProfileCard(theme),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildBasicInfoCard(ThemeData theme) {
    if (_validResult == null) return const SizedBox.shrink();
    
    final bool isValid = _validResult?['is_valid'] == true;
    final color = isValid ? const Color(0xFF10B981) : theme.colorScheme.error;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            Icon(isValid ? Icons.check_circle : Icons.cancel, color: color, size: 40),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('STATUS: ${isValid ? "VALID & ACTIVE" : "INVALID"}', style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
                  if (isValid && _countryResult != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.public, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text('Country: ${_countryResult!['country'] ?? 'Unknown'}', style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.cell_tower, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text('Carrier: ${_countryResult!['carrier_name'] ?? 'Unknown'}', style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontSize: 14)),
                      ],
                    ),
                  ]
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildActionsCard(ThemeData theme) {
    if (_dorksResult == null && _tgChatResult == null && _waResult == null && _viberResult == null) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('EXTERNAL OSINT ACTIONS', style: TextStyle(color: theme.textTheme.bodySmall?.color, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildLinkButton(theme, 'GOOGLE DORKS', Icons.travel_explore, _dorksResult?['url']),
                _buildLinkButton(theme, 'TELEGRAM CHAT', Icons.telegram, _tgChatResult?['url']),
                _buildLinkButton(theme, 'WHATSAPP CHAT', Icons.chat, _waResult?['url']),
                _buildLinkButton(theme, 'VIBER CHAT', Icons.phone_in_talk, _viberResult?['url']),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLinkButton(ThemeData theme, String label, IconData icon, String? url) {
    if (url == null || url.isEmpty) return const SizedBox.shrink();
    
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: theme.colorScheme.primary,
        elevation: 0,
        side: BorderSide(color: theme.dividerColor.withOpacity(0.2)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      onPressed: () => _launchURL(url),
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }

  Widget _buildTelegramProfileCard(ThemeData theme) {
    final status = _tgProfileResult?['status'] ?? '';
    final error = _tgProfileResult?['error_message'] ?? '';
    
    if (status == 'error' || error.isNotEmpty) {
      return Card(
        margin: const EdgeInsets.only(top: 16),
        shape: RoundedRectangleBorder(side: BorderSide(color: theme.colorScheme.error.withOpacity(0.3)), borderRadius: BorderRadius.circular(6)),
        child: ListTile(
          leading: Icon(Icons.error_outline, color: theme.colorScheme.error),
          title: const Text('TELEGRAM PROFILE NOT FOUND'),
          subtitle: Text(error),
        ),
      );
    }

    final id = _tgProfileResult?['id'] ?? '';
    final username = _tgProfileResult?['username'] ?? 'None';
    final firstName = _tgProfileResult?['first_name'] ?? 'Unknown';
    final lastName = _tgProfileResult?['last_name'] ?? '';
    final fullName = '$firstName $lastName'.trim();

    return Card(
      margin: const EdgeInsets.only(top: 16),
      shape: RoundedRectangleBorder(side: BorderSide(color: theme.colorScheme.primary.withOpacity(0.3)), borderRadius: BorderRadius.circular(6)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            CircleAvatar(radius: 36, backgroundColor: theme.colorScheme.primary.withOpacity(0.1), child: Icon(Icons.telegram, size: 40, color: theme.colorScheme.primary)),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('TELEGRAM ACCOUNT IDENTIFIED', style: TextStyle(color: theme.colorScheme.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(fullName, style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text('Username: @$username', style: TextStyle(color: theme.textTheme.bodyMedium?.color)),
                  if (id.toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('Internal ID: $id', style: TextStyle(color: theme.textTheme.bodySmall?.color)),
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