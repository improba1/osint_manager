import 'package:flutter/material.dart';
import 'package:osint_frontend/api_service.dart';
import 'dart:async';

class EmailSearchScreen extends StatefulWidget {
  const EmailSearchScreen({super.key});

  @override
  State<EmailSearchScreen> createState() => _EmailSearchScreenState();
}

class _EmailSearchScreenState extends State<EmailSearchScreen> {
  final TextEditingController _emailController = TextEditingController();
  
  bool _isStageOneRunning = false;
  int _activeDeepTasks = 0;
  String _statusMessage = 'AWAITING TARGET EMAIL...';
  StreamSubscription? _leaksSubscription;

  Map<String, dynamic>? _validateResult;
  Map<String, dynamic>? _disposableResult;
  Map<String, dynamic>? _gravatarResult;
  List<dynamic>? _holeheResults;
  List<dynamic>? _leaksResults;

  void _startAnalysis() async {
    // ПРЕДОХРАНИТЕЛЬ ОТ ДВОЙНЫХ ЗАПУСКОВ
    if (_isStageOneRunning || _activeDeepTasks > 0) return;

    final email = _emailController.text.trim();
    if (email.isEmpty) return;

    setState(() {
      _validateResult = null;
      _disposableResult = null;
      _gravatarResult = null;
      _holeheResults = null;
      _leaksResults = null;
      _isStageOneRunning = true;
      _activeDeepTasks = 0;
      _statusMessage = 'STAGE 1: VALIDATING EMAIL...';
    });

    final api = ApiService();

    try {
      final results = await Future.wait([
        api.checkEmailValidate(email),
        api.checkEmailDisposable(email),
      ]);

      if (!mounted) return;

      setState(() {
        _validateResult = results[0]['results'];
        _disposableResult = results[1]['results'];
        _isStageOneRunning = false;
      });

      final bool isValid = _validateResult?['is_valid'] == true;
      final bool isDisposable = _disposableResult?['is_disposable'] == true;

      if (!isValid || isDisposable) {
        setState(() { _statusMessage = 'ANALYSIS HALTED: EMAIL INVALID OR DISPOSABLE'; });
        return; 
      }

      setState(() {
        _activeDeepTasks = 3;
        _statusMessage = 'STAGE 2: DEEP OSINT IN PROGRESS...';
        _leaksResults = []; 
      });

      api.checkEmailGravatar(email).then((res) {
        if (mounted) {
          setState(() {
            if (res['status'] == 'success' && res['results'] != null) {
              _gravatarResult = res['results'];
            }
            _activeDeepTasks--; 
          });
        }
      });

      api.checkEmailHolehe(email).then((res) {
        if (mounted) {
          setState(() {
            if (res['status'] == 'success' && res['results'] != null) {
              _holeheResults = res['results'] is List ? res['results'] : [res['results']];
            } else {
              print('Holehe failed: ${res['error_message']}');
            }
            _activeDeepTasks--;
          });
        }
      });

      _leaksSubscription?.cancel(); 
      bool leaksFinished = false; 
      
      _leaksSubscription = api.liveEmailLeaksSearch(email).listen(
        (data) {
          if (!mounted) return;
          setState(() {
            if (data['status'] == 'COMPLETED' || data['status'] == 'ERROR') {
              if (data['status'] == 'ERROR') _leaksResults!.add(data);
              if (!leaksFinished) {
                leaksFinished = true;
                _activeDeepTasks--;
              }
              _leaksSubscription?.cancel();
            } else {
              _leaksResults!.add(data);
            }
          });
        },
        onError: (err) {
          if (mounted && !leaksFinished) {
            setState(() { leaksFinished = true; _activeDeepTasks--; });
          }
        },
        onDone: () {
          if (mounted && !leaksFinished) {
            setState(() { leaksFinished = true; _activeDeepTasks--; });
          }
        }
      );

    } catch (e) {
      if (mounted) {
        setState(() {
          _isStageOneRunning = false;
          _statusMessage = 'ERROR: API CONNECTION FAILED';
        });
      }
    }
  }

  @override
  void dispose() {
    _leaksSubscription?.cancel();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bool isAnyTaskRunning = _isStageOneRunning || _activeDeepTasks > 0;

    return Column(
      key: const ValueKey('EMAIL'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.email, color: colorScheme.primary, size: 28),
            const SizedBox(width: 16),
            Text(
              'EMAIL RECONNAISSANCE',
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
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Target Email Address',
                  prefixIcon: Icon(Icons.mail_outline, color: colorScheme.primary),
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
                onPressed: isAnyTaskRunning ? null : _startAnalysis,
                icon: isAnyTaskRunning 
                  ? Container(width: 20, height: 20, padding: const EdgeInsets.all(2), child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.radar),
                label: Text(isAnyTaskRunning ? 'SCANNING' : 'EXECUTE', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        
        Expanded(
          child: _validateResult == null && !_isStageOneRunning
              ? Center(child: Text(_statusMessage, style: TextStyle(color: theme.disabledColor, fontSize: 18, letterSpacing: 2)))
              : ListView(
                  children: [
                    _buildDiagnosticsRow(theme),
                    
                    if (_validateResult != null && !(_validateResult?['is_valid'] == true) || (_disposableResult?['is_disposable'] == true))
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
                              'OSINT HALTED: INVALID OR DISPOSABLE TARGET', 
                              style: TextStyle(color: colorScheme.error, fontSize: 14, fontWeight: FontWeight.bold)
                            ),
                          ),
                        ),
                      ),

                    if (_gravatarResult != null && _gravatarResult!['status'] != 'error') _buildGravatarCard(theme),
                    if (_leaksResults != null && _leaksResults!.isNotEmpty) _buildLeaksSection(theme),
                    if (_holeheResults != null && _holeheResults!.isNotEmpty) _buildHoleheSection(theme),
                    
                    if (_activeDeepTasks > 0)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: Text('DEEP OSINT TASKS REMAINING: $_activeDeepTasks...', style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold)),
                        ),
                      )
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildDiagnosticsRow(ThemeData theme) {
    if (_validateResult == null && _disposableResult == null) return const SizedBox.shrink();

    final bool isValid = _validateResult?['is_valid'] == true;
    final bool isDisposable = _disposableResult?['is_disposable'] == true;

    return Row(
      children: [
        Expanded(
          child: _buildStatusCard(
            theme: theme,
            title: 'DOMAIN MX RECORD',
            value: _validateResult == null ? 'SCANNING...' : (isValid ? 'VALID' : 'INVALID'),
            isPositive: isValid,
            icon: Icons.dns,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatusCard(
            theme: theme,
            title: 'DISPOSABLE EMAIL',
            value: _disposableResult == null ? 'SCANNING...' : (isDisposable ? 'DETECTED' : 'SAFE (PERMANENT)'),
            isPositive: !isDisposable, 
            icon: Icons.delete_sweep,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusCard({required ThemeData theme, required String title, required String value, required bool isPositive, required IconData icon}) {
    final bool isScanning = value == 'SCANNING...';
    // Строгие корпоративные цвета
    final color = isScanning ? theme.disabledColor : (isPositive ? const Color(0xFF10B981) : theme.colorScheme.error);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: theme.textTheme.bodySmall?.color, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildGravatarCard(ThemeData theme) {
    // Безопасное извлечение данных
    final name = _gravatarResult?['name'] ?? '';
    final photoUrl = _gravatarResult?['profile_photo'] ?? '';
    final location = _gravatarResult?['location'] ?? '';
    final profileUrl = _gravatarResult?['profile_url'] ?? '';
    final job = _gravatarResult?['job'] ?? '';
    
    // Показываем карточку, если есть хотя бы имя ИЛИ фото ИЛИ профиль
    if (name.isEmpty && photoUrl.isEmpty && profileUrl.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            if (photoUrl.isNotEmpty)
              CircleAvatar(radius: 36, backgroundImage: NetworkImage(photoUrl), backgroundColor: theme.scaffoldBackgroundColor)
            else
              CircleAvatar(radius: 36, backgroundColor: theme.scaffoldBackgroundColor, child: Icon(Icons.person, size: 36, color: theme.colorScheme.primary)),
            
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('GRAVATAR PROFILE MATCH', style: TextStyle(color: theme.textTheme.bodySmall?.color, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  // Если имени нет, показываем "Unknown Name", чтобы структура не ломалась
                  Text(name.isNotEmpty ? name : 'Unknown Name', style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontSize: 20, fontWeight: FontWeight.bold)),
                  if (location.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('Location: $location', style: TextStyle(color: theme.textTheme.bodyMedium?.color)),
                    ),
                  if (job.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('Job: $job', style: TextStyle(color: theme.textTheme.bodyMedium?.color)),
                    ),
                  if (profileUrl.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(profileUrl, style: TextStyle(color: theme.colorScheme.primary, decoration: TextDecoration.underline, fontSize: 12)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHoleheSection(ThemeData theme) {
    final foundAccounts = _holeheResults!.where((site) {
      if (site == null || site is! Map) return false;
      return site['exists'] == true || site['exists'] == 'true';
    }).toList();
    
    if (foundAccounts.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 32, bottom: 16),
          child: Text('REGISTERED ACCOUNTS', style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: foundAccounts.map((site) {
            return Chip(
              backgroundColor: theme.scaffoldBackgroundColor,
              side: BorderSide(color: theme.dividerColor.withOpacity(0.2)),
              label: Text(site['name'] ?? site['domain'] ?? 'Unknown', style: TextStyle(color: theme.textTheme.bodyMedium?.color)),
              avatar: const Icon(Icons.check_circle, size: 18, color: Color(0xFF10B981)), // Изумрудный цвет
            );
          }).toList(),
        )
      ],
    );
  }

  Widget _buildLeaksSection(ThemeData theme) {
    final leaksWithData = _leaksResults!.where((site) {
      if (site == null || site is! Map) return false;
      return site['status'] != 'error' && (site['leaks'] != null && site['leaks'] > 0);
    }).toList();
    
    if (leaksWithData.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 32, bottom: 16),
          child: Text('DATA BREACHES DETECTED', style: TextStyle(color: theme.colorScheme.error, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
        ),
        ...leaksWithData.map((leak) {
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(
              side: BorderSide(color: theme.colorScheme.error.withOpacity(0.3)), 
              borderRadius: BorderRadius.circular(6)
            ),
            child: ListTile(
              leading: Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error),
              title: Text(leak['service_name'] ?? 'Unknown Breach', style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontWeight: FontWeight.bold)),
              subtitle: Text('Records compromised: ${leak['leaks']}', style: TextStyle(color: theme.textTheme.bodySmall?.color)),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('EXPOSED', style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ),
          );
        })
      ],
    );
  }
}