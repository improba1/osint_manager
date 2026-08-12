import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:osint_frontend/api_service.dart';
import 'dart:async';

class UsernameSearchScreen extends StatefulWidget {
  const UsernameSearchScreen({super.key});

  @override
  State<UsernameSearchScreen> createState() => _UsernameSearchScreenState();
}

class _UsernameSearchScreenState extends State<UsernameSearchScreen> {
  final TextEditingController _usernameController = TextEditingController();
  bool _isLoading = false;
  bool _showOnlyFound = false;
  final List<Map<String, dynamic>> _liveResults = [];
  StreamSubscription? _subscription;

  void _startLiveSearch() {
    if (_usernameController.text.isEmpty) return;

    _subscription?.cancel();

    setState(() {
      _isLoading = true;
      _liveResults.clear();
    });

    _subscription = ApiService().liveUsernameSearch(_usernameController.text).listen(
      (data) {
        if (!mounted) return;
        if (data['status'] == 'COMPLETED' || data['status'] == 'ERROR') {
          setState(() { _isLoading = false; });
          if (data['status'] == 'ERROR') _liveResults.add(data);
        } else {
          setState(() { _liveResults.add(data); });
        }
      },
      onError: (err) { if (mounted) setState(() { _isLoading = false; }); },
      onDone: () { if (mounted) setState(() { _isLoading = false; }); }
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.person, color: colorScheme.primary, size: 28),
            const SizedBox(width: 16),
            Text(
              'IDENTITY RECONNAISSANCE',
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
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: 'Target Username',
                  prefixIcon: Icon(Icons.search, color: colorScheme.primary),
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
                onPressed: _isLoading ? null : _startLiveSearch,
                icon: _isLoading 
                  ? Container(width: 20, height: 20, padding: const EdgeInsets.all(2), child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.radar),
                label: Text(_isLoading ? 'SCANNING' : 'EXECUTE', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (_liveResults.isNotEmpty || _isLoading)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('SHOW ONLY IDENTIFIED', style: TextStyle(color: theme.textTheme.bodySmall?.color, fontWeight: FontWeight.bold)),
              Switch(
                value: _showOnlyFound,
                activeColor: colorScheme.primary,
                onChanged: (value) { setState(() { _showOnlyFound = value; }); },
              ),
            ],
          ),
        const SizedBox(height: 16),
        Expanded(child: _buildResultsArea(theme)),
      ],
    );
  }

  Widget _buildResultsArea(ThemeData theme) {
    if (_liveResults.isEmpty && !_isLoading) {
      return Center(
        child: Text('AWAITING QUERY', style: TextStyle(color: theme.disabledColor, fontSize: 18, letterSpacing: 2)),
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
        child: Text('QUERYING DATABASES...', style: TextStyle(color: theme.colorScheme.primary, fontSize: 16)),
      );
    }

    return ListView.builder(
      itemCount: displayResults.length,
      itemBuilder: (context, index) {
        final site = displayResults[index];
        final statusStr = site['status']?.toString().toLowerCase() ?? '';
        final bool isFound = statusStr == 'found' || statusStr == 'success' || statusStr == 'true' || statusStr == '200';
        
        final statusColor = isFound ? const Color(0xFF10B981) : theme.colorScheme.error;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            onTap: () async {
              final urlStr = site['url'];
              if (urlStr != null && urlStr.isNotEmpty) {
                final Uri url = Uri.parse(urlStr);
                if (await canLaunchUrl(url)) await launchUrl(url);
              }
            },
            mouseCursor: SystemMouseCursors.click, 
            leading: Icon(isFound ? Icons.check_circle : Icons.cancel, color: statusColor, size: 20),
            title: Text(
              site['service_name'] ?? 'Unknown',
              style: TextStyle(fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color),
            ),
            subtitle: Text(
              site['url'] ?? '',
              style: TextStyle(color: theme.colorScheme.primary, decoration: TextDecoration.underline, fontSize: 13),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: statusColor.withOpacity(0.2)),
              ),
              child: Text(
                (site['status'] ?? '').toString().toUpperCase(),
                style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ),
        );
      },
    );
  }
}