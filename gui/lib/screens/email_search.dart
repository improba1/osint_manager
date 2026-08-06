
import 'package:flutter/material.dart';
import 'package:osint_frontend/api_service.dart';
import 'dart:async';

import 'package:url_launcher/url_launcher.dart';

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
                    if (_leaksResults != null) _buildLeaksSection(theme),
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
      clipBehavior: Clip.antiAlias, // Обрезает анимацию клика по границам карточки
      child: InkWell(
        // Клик работает только если ссылка на профиль действительно есть
        onTap: profileUrl.isNotEmpty
            ? () async {
                final Uri url = Uri.parse(profileUrl);
                if (await canLaunchUrl(url)) {
                  await launchUrl(url);
                }
              }
            : null,
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
                        child: Row(
                          children: [
                            Text(
                              profileUrl, 
                              style: TextStyle(color: theme.colorScheme.primary, decoration: TextDecoration.underline, fontSize: 12),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.open_in_new, size: 12, color: theme.colorScheme.primary), // Иконка внешнего перехода
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHoleheSection(ThemeData theme) {
    // 1. Находим все зарегистрированные аккаунты
    final foundAccounts = _holeheResults!.where((site) {
      if (site == null || site is! Map) return false;
      return site['exists'] == true || site['exists'] == 'true';
    }).toList();
    
    if (foundAccounts.isEmpty) return const SizedBox.shrink();

    // 2. Сортируем: отделяем аккаунты с ценными данными (телефон/почта) от обычных
    final List<Map> accountsWithData = [];
    final List<Map> regularAccounts = [];

    for (var site in foundAccounts) {
      final bool hasPhone = site['phoneNumber'] != null && site['phoneNumber'].toString().isNotEmpty;
      final bool hasEmail = site['emailrecovery'] != null && site['emailrecovery'].toString().isNotEmpty;

      if (hasPhone || hasEmail) {
        accountsWithData.add(site);
      } else {
        regularAccounts.add(site);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 32, bottom: 16),
          child: Text('REGISTERED ACCOUNTS', style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
        ),

        // 3. ОТРИСОВКА ЦЕННЫХ АККАУНТОВ (Выделенные карточки)
        if (accountsWithData.isNotEmpty)
          ...accountsWithData.map((site) {
            final String name = site['name'] ?? site['domain'] ?? 'Unknown';
            final String phone = site['phoneNumber']?.toString() ?? '';
            final String email = site['emailrecovery']?.toString() ?? '';

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                // Синяя рамка, чтобы привлечь внимание к ценной находке
                side: BorderSide(color: theme.colorScheme.primary.withOpacity(0.5)), 
                borderRadius: BorderRadius.circular(6)
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.stars, color: theme.colorScheme.primary, size: 20),
                        const SizedBox(width: 8),
                        Text(name, style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // Строка с телефоном (выделена изумрудным!)
                    if (phone.isNotEmpty)
                      Row(
                        children: [
                          const Icon(Icons.phone_android, color: Color(0xFF10B981), size: 18),
                          const SizedBox(width: 8),
                          Text('Recovery Phone:', style: TextStyle(color: theme.textTheme.bodyMedium?.color, fontSize: 14)),
                          const SizedBox(width: 8),
                          Text(phone, style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 1.5)),
                        ],
                      ),
                      
                    // Строка с резервной почтой
                    if (email.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(top: phone.isNotEmpty ? 8.0 : 0),
                        child: Row(
                          children: [
                            Icon(Icons.mail_lock, color: theme.disabledColor, size: 18),
                            const SizedBox(width: 8),
                            Text('Recovery Email:', style: TextStyle(color: theme.textTheme.bodyMedium?.color, fontSize: 14)),
                            const SizedBox(width: 8),
                            Text(email, style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 1.0)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),

        if (accountsWithData.isNotEmpty && regularAccounts.isNotEmpty)
          const SizedBox(height: 16),

        // 4. ОТРИСОВКА ОБЫЧНЫХ АККАУНТОВ (Облако тегов)
        if (regularAccounts.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: regularAccounts.map((site) {
              return Chip(
                backgroundColor: theme.scaffoldBackgroundColor,
                side: BorderSide(color: theme.dividerColor.withOpacity(0.2)),
                label: Text(site['name'] ?? site['domain'] ?? 'Unknown', style: TextStyle(color: theme.textTheme.bodyMedium?.color)),
                avatar: const Icon(Icons.check_circle, size: 18, color: Color(0xFF10B981)),
              );
            }).toList(),
          )
      ],
    );
  }

  Widget _buildLeaksSection(ThemeData theme) {
    if (_leaksResults == null || _leaksResults!.isEmpty) return const SizedBox.shrink();

    // 1. Проверяем, есть ли вообще хоть одна реальная утечка среди всех сервисов
    bool hasAnyBreach = false;
    for (var site in _leaksResults!) {
      if (site != null && site is Map && site['status'] != 'error' && site['status'] != 'ERROR') {
        final Map<String, dynamic> src = site['leaks_source'] is Map ? site['leaks_source'] : {};
        final int c = int.tryParse(site['leaks']?.toString() ?? '0') ?? 0;
        // Если счетчик > 0 ИЛИ список баз не пустой
        if (c > 0 || src.isNotEmpty) {
          hasAnyBreach = true;
          break;
        }
      }
    }

    // 2. Если ни одной утечки не найдено И глубокий поиск завершен - рисуем зеленую карточку
    if (!hasAnyBreach) {
      if (_activeDeepTasks == 0) {
        return Padding(
          padding: const EdgeInsets.only(top: 32, bottom: 16),
          child: Card(
            shape: RoundedRectangleBorder(
              side: BorderSide(color: const Color(0xFF10B981).withOpacity(0.3)), 
              borderRadius: BorderRadius.circular(6)
            ),
            child: ListTile(
              leading: const Icon(Icons.security, color: Color(0xFF10B981), size: 32),
              title: Text('NO DATA BREACHES DETECTED', style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontWeight: FontWeight.bold)),
              subtitle: Text('This email appears in 0 known compromised databases.', style: TextStyle(color: theme.textTheme.bodySmall?.color)),
              trailing: const Icon(Icons.check_circle, color: Color(0xFF10B981)),
            ),
          ),
        );
      }
      return const SizedBox.shrink();
    }

    // 3. Рисуем карточки для всех сервисов
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 32, bottom: 16),
          child: Text('DATA BREACH DATABASES', style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
        ),
        ..._leaksResults!.map((site) {
          if (site == null || site is! Map) return const SizedBox.shrink();

          final serviceName = site['service_name'] ?? 'Unknown Service';
          final status = site['status']?.toString().toLowerCase();
          final isError = status == 'error' || status == 'unreachable';
          
          final Map<String, dynamic> leaksSource = site['leaks_source'] is Map ? site['leaks_source'] : {};
          
          // === ИСПРАВЛЕНИЕ ===
          // Если API говорит leaks: 0, но список баз полный, мы берем длину списка баз!
          int parsedCount = int.tryParse(site['leaks']?.toString() ?? '0') ?? 0;
          final int leaksCount = (parsedCount == 0 && leaksSource.isNotEmpty) ? leaksSource.length : parsedCount;
          
          final bool hasLeaks = leaksCount > 0;

          // Сортировка по алфавиту
          final List<String> sortedLeakNames = leaksSource.keys.toList()
            ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

          final Color color = isError 
              ? theme.disabledColor 
              : (hasLeaks ? theme.colorScheme.error : const Color(0xFF10B981));
              
          final IconData icon = isError 
              ? Icons.error_outline 
              : (hasLeaks ? Icons.warning_amber_rounded : Icons.security);
              
          final String statusText = isError 
              ? 'ERROR' 
              : (hasLeaks ? 'EXPOSED' : 'SECURE');

          final String subtitleText = isError 
              ? 'Status: ${site['error_message'] ?? "Unreachable"}' 
              : 'Records compromised: $leaksCount';

          final Widget statusBadge = Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Text(statusText, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
          );

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(
              side: BorderSide(color: color.withOpacity(0.3)), 
              borderRadius: BorderRadius.circular(6)
            ),
            child: hasLeaks 
              ? Theme(
                  data: theme.copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    leading: Icon(icon, color: color),
                    title: Text(serviceName, style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontWeight: FontWeight.bold)),
                    subtitle: Text(subtitleText, style: TextStyle(color: theme.textTheme.bodySmall?.color)),
                    iconColor: color,
                    collapsedIconColor: color,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        statusBadge,
                        const SizedBox(width: 8),
                        Icon(Icons.keyboard_arrow_down, color: color.withOpacity(0.7)),
                      ],
                    ),
                    children: [
                      Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(maxHeight: 300),
                        decoration: BoxDecoration(
                          color: theme.scaffoldBackgroundColor.withOpacity(0.4),
                          border: Border(top: BorderSide(color: theme.dividerColor.withOpacity(0.1))),
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: sortedLeakNames.length,
                          itemBuilder: (context, index) {
                            final dbName = sortedLeakNames[index];
                            // Достаем дату утечки, если она есть
                            final dbDate = leaksSource[dbName]?.toString().trim() ?? '';
                            
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                              child: Row(
                                children: [
                                  Icon(Icons.circle, size: 6, color: color.withOpacity(0.6)),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      dbName, 
                                      style: TextStyle(color: theme.textTheme.bodyMedium?.color, fontSize: 13, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  // Если есть дата, выводим её справа аккуратным шрифтом
                                  if (dbDate.isNotEmpty)
                                    Text(
                                      dbDate,
                                      style: TextStyle(color: theme.textTheme.bodySmall?.color, fontSize: 11, fontStyle: FontStyle.italic),
                                    )
                                ],
                              ),
                            );
                          },
                        ),
                      )
                    ],
                  ),
                )
              : ListTile(
                  leading: Icon(icon, color: color),
                  title: Text(serviceName, style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontWeight: FontWeight.bold)),
                  subtitle: Text(subtitleText, style: TextStyle(color: theme.textTheme.bodySmall?.color)),
                  trailing: statusBadge,
                ),
          );
        })
      ],
    );
  }
}