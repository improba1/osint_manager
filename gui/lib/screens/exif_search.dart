import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:osint_frontend/api_service.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class ExifAnalysisScreen extends StatefulWidget {
  const ExifAnalysisScreen({super.key});

  @override
  State<ExifAnalysisScreen> createState() => _ExifAnalysisScreenState();
}

class _ExifAnalysisScreenState extends State<ExifAnalysisScreen> {
  bool _isUploading = false;
  String _statusMessage = 'AWAITING FILE SELECTION...';
  
  String? _selectedFileName;
  Map<String, dynamic>? _parsedData;
  Map<String, dynamic>? _rawData;

  Future<void> _pickAndUploadFile() async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.image,
        withData: true, 
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.single;
      final fileBytes = file.bytes;
      final fileName = file.name;

      if (fileBytes == null) {
        setState(() { _statusMessage = 'ERROR: CANNOT READ FILE DATA'; });
        return;
      }

      setState(() {
        _selectedFileName = fileName;
        _parsedData = null;
        _rawData = null;
        _isUploading = true;
        _statusMessage = 'EXTRACTING METADATA...';
      });

      final response = await ApiService().uploadFileForExif(fileBytes, fileName);

      if (!mounted) return;

      setState(() {
        _isUploading = false;
        if (response['status'] == 'success' && response['results'] != null) {
          _parsedData = response['results'] ?? {};
          _rawData = response['results']['raw_exif'] ?? {};
        } else {
          _statusMessage = 'ERROR: ${response['error_message'] ?? "FAILED TO EXTRACT DATA"}';
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _statusMessage = 'ERROR: FILE SYSTEM/NETWORK EXCEPTION';
        });
      }
    }
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
            Icon(Icons.memory, color: colorScheme.primary, size: 28),
            const SizedBox(width: 16),
            Text(
              'FORENSIC FILE ANALYSIS',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color, letterSpacing: 1.5),
            ),
          ],
        ),
        const SizedBox(height: 32),
        
        InkWell(
          onTap: _isUploading ? null : _pickAndUploadFile,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            width: double.infinity,
            height: 140,
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: _isUploading ? colorScheme.primary : theme.dividerColor,
                width: _isUploading ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isUploading)
                  CircularProgressIndicator(color: colorScheme.primary)
                else
                  Icon(Icons.cloud_upload_outlined, size: 48, color: colorScheme.primary),
                
                const SizedBox(height: 16),
                Text(
                  _isUploading ? 'ANALYZING FILE...' : 'CLICK TO UPLOAD IMAGE FOR FORENSIC ANALYSIS',
                  style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                ),
                if (_selectedFileName != null && !_isUploading)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text('Target: $_selectedFileName', style: TextStyle(color: theme.colorScheme.primary)),
                  )
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        Expanded(
          child: _parsedData == null && !_isUploading
              ? Center(
                  child: Text(
                    _statusMessage, 
                    style: TextStyle(
                      color: _statusMessage.contains('ERROR') ? colorScheme.error : theme.disabledColor, 
                      fontSize: 16, 
                      letterSpacing: 1.5,
                      fontWeight: _statusMessage.contains('ERROR') ? FontWeight.bold : FontWeight.normal
                    )
                  )
                )
              : ListView(
                  children: [
                    if (_parsedData != null) _buildStructuredData(theme),
                    if (_rawData != null && _rawData!.isNotEmpty) _buildRawDataSection(theme),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildStructuredData(ThemeData theme) {
    final String hardwareMake = _parsedData?['hardware']['Make']?.toString().isNotEmpty == true? _parsedData!['hardware']['Make'] : '-';
    final String hardwareModel = _parsedData?['hardware']['Model']?.toString().isNotEmpty == true? _parsedData!['hardware']['Model'] : '-';
    final String softwareDateTime = _parsedData?['software']['DateTime']?.toString().isNotEmpty == true? _parsedData!['software']['DateTime'] : '-';
    final String softwareSoftware = _parsedData?['software']['Software']?.toString().isNotEmpty == true? _parsedData!['software']['Software'] : '-';
    final String latitude = _parsedData?['gps']['latitude']?.toString().isNotEmpty == true ? _parsedData!['gps']['latitude'] : '-';
    final String longitude = _parsedData?['gps']['longitude']?.toString().isNotEmpty == true ? _parsedData!['gps']['longitude'] : '-';

    final bool isEmpty = hardwareMake == '-' && hardwareModel == '-' && softwareDateTime == '-' && softwareSoftware == '-' && latitude == '-' && longitude == '-' ;

    if (isEmpty) {
      final rawKeys = _rawData != null ? _rawData!.keys.toList() : [];
      
      return Card(
        margin: const EdgeInsets.only(top: 16),
        shape: RoundedRectangleBorder(
          side: BorderSide(color: theme.colorScheme.error.withOpacity(0.3)), 
          borderRadius: BorderRadius.circular(6)
        ),
        child: Column(
          children: [
            ListTile(
              leading: Icon(Icons.block, color: theme.colorScheme.error),
              title: const Text('NO STRUCTURED METADATA FOUND'),
              subtitle: const Text('The image has been stripped of standard EXIF tags.'),
            ),
            
            if (rawKeys.isNotEmpty) ...[
              Divider(color: theme.colorScheme.error.withOpacity(0.2), height: 1),
              Theme(
                data: theme.copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  leading: Icon(Icons.data_object, color: theme.colorScheme.error),
                  title: Text('SHOW RAW METADATA', style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.bold)),
                  subtitle: Text('${rawKeys.length} tags detected', style: TextStyle(color: theme.textTheme.bodySmall?.color)),
                  iconColor: theme.colorScheme.error,
                  collapsedIconColor: theme.colorScheme.error,
                  children: [
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: theme.scaffoldBackgroundColor.withOpacity(0.4),
                        border: Border(top: BorderSide(color: theme.colorScheme.error.withOpacity(0.1))),
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: rawKeys.length,
                        itemBuilder: (context, index) {
                          final key = rawKeys[index];
                          final value = _rawData![key]?.toString() ?? '-';
                          
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Text(key, style: TextStyle(color: theme.colorScheme.error, fontSize: 12, fontFamily: 'monospace')),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: SelectableText(value, style: TextStyle(color: theme.textTheme.bodyMedium?.color, fontSize: 13, fontFamily: 'monospace')),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    )
                  ],
                ),
              ),
            ]
          ],
        ),
      );
    }

    double lat = double.parse(latitude);
    double lon = double.parse(longitude);

    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('EXTRACTED FORENSIC DATA', style: TextStyle(color: theme.textTheme.bodySmall?.color, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
            const SizedBox(height: 24),
            _buildDataRow(theme, Icons.camera_alt, 'Hardware', hardwareMake),
            _buildDivider(theme),
            _buildDataRow(theme, Icons.camera_alt, 'Model', hardwareModel),
            _buildDivider(theme),

            _buildDataRow(theme, Icons.laptop, 'DateTime', softwareDateTime),
            _buildDivider(theme),
            _buildDataRow(theme, Icons.laptop, 'Software Version', softwareSoftware),
            _buildDivider(theme),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.location_on, size: 20, color: latitude != '-' ? const Color(0xFF10B981) : theme.colorScheme.primary),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('GPS Coordinates', style: TextStyle(color: theme.textTheme.bodyMedium?.color, fontWeight: FontWeight.bold)),
                      if (lat != null && lon != null) ...[
                        const SizedBox(height: 20),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF10B981),
                            side: const BorderSide(color: Color(0xFF10B981)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                            minimumSize: Size.zero,
                          ),
                          icon: const Icon(Icons.map, size: 16),
                          label: const Text('SHOW ON MAP', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          onPressed: () => _showMapDialog(context, lat!, lon!),
                        ),
                      ]
                    ],
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Row( 
                    children: [
                      Text(latitude, style: TextStyle(color: latitude != '-' ? const Color(0xFF10B981) : theme.textTheme.bodyLarge?.color, fontWeight: FontWeight.bold, fontSize: 15)),
                      Padding(padding: const EdgeInsets.all(24.0)),
                      Text(longitude, style: TextStyle(color: longitude != '-' ? const Color(0xFF10B981) : theme.textTheme.bodyLarge?.color, fontWeight: FontWeight.bold, fontSize: 15))
                    ]
                  )
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataRow(ThemeData theme, IconData icon, String title, String value, {bool isHighlight = false}) {
    final color = isHighlight ? const Color(0xFF10B981) : theme.textTheme.bodyLarge?.color;
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: Text(title, style: TextStyle(color: theme.textTheme.bodyMedium?.color, fontWeight: FontWeight.bold)),
        ),
        Expanded(
          flex: 3,
          child: Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15)),
        ),
      ],
    );
  }

  Widget _buildDivider(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Divider(color: theme.dividerColor.withOpacity(0.1)),
    );
  }

  Widget _buildRawDataSection(ThemeData theme) {
    final keys = _rawData!.keys.toList()..sort();

    return Card(
      margin: const EdgeInsets.only(top: 16, bottom: 32),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: theme.dividerColor.withOpacity(0.2)), 
        borderRadius: BorderRadius.circular(6)
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Icon(Icons.data_object, color: theme.colorScheme.primary),
          title: Text('SHOW RAW METADATA', style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontWeight: FontWeight.bold)),
          subtitle: Text('${keys.length} tags detected', style: TextStyle(color: theme.textTheme.bodySmall?.color)),
          children: [
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor.withOpacity(0.4),
                border: Border(top: BorderSide(color: theme.dividerColor.withOpacity(0.1))),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(), 
                itemCount: keys.length,
                itemBuilder: (context, index) {
                  final key = keys[index];
                  final value = _rawData![key]?.toString() ?? '-';
                  
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(key, style: TextStyle(color: theme.colorScheme.primary, fontSize: 12, fontFamily: 'monospace')),
                        ),
                        Expanded(
                          flex: 3,
                          child: SelectableText(value, style: TextStyle(color: theme.textTheme.bodyMedium?.color, fontSize: 13, fontFamily: 'monospace')),
                        ),
                      ],
                    ),
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }

  void _showMapDialog(BuildContext context, double lat, double lon) {
    final theme = Theme.of(context);
    
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: theme.scaffoldBackgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: theme.colorScheme.primary.withOpacity(0.5)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 800, 
              height: 600, 
              child: Stack(
                children: [
                  FlutterMap(
                    options: MapOptions(
                      initialCenter: LatLng(lat, lon),
                      initialZoom: 15.0, 
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.osint.app',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(lat, lon),
                            width: 80,
                            height: 80,
                            child: const Icon(Icons.location_searching, color: Colors.redAccent, size: 40),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Positioned(
                    top: 16,
                    right: 16,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.black, size: 28),
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.9),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}