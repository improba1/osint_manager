// lib/screens/exif_analysis_screen.dart
import 'package:flutter/material.dart';

class ExifAnalysisScreen extends StatelessWidget {
  const ExifAnalysisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('FILE'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.memory, size: 32),
            const SizedBox(width: 16),
            const Text(
              'METADATA EXTRACTION',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2.0),
            ),
          ],
        ),
        const SizedBox(height: 32),
        Container(
          width: double.infinity,
          height: 200,
          decoration: BoxDecoration(
            color: const Color(0xFF0A0A0A),
            border: Border.all(width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.upload_file, size: 64),
              const SizedBox(height: 16),
              Text(
                'CLICK TO SELECT FILE OR DROP HERE',
                style: TextStyle(fontSize: 18),
              ),
            ],
          ),
        ),
        const Expanded(
          child: Center(
            child: Text('NO FILE LOADED', style: TextStyle(color: Colors.white24, fontSize: 24, letterSpacing: 4)),
          ),
        ),
      ],
    );
  }
}