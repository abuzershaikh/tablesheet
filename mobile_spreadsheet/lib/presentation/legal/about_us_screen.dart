import 'package:flutter/material.dart';

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About Us'),
        backgroundColor: const Color(0xFF2848D3),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 32),
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFF2848D3).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.table_chart,
                size: 60,
                color: Color(0xFF2848D3),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Spreadsheet Pro',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF2848D3)),
            ),
            const SizedBox(height: 8),
            const Text(
              'Version 1.0.0',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            const Text(
              'Spreadsheet Pro is the ultimate mobile solution for managing, analyzing, and visualizing your data on the go.\n\n'
              'Experience desktop-class spreadsheet capabilities right at your fingertips. Key features include:\n\n'
              '• Advanced Formula Evaluation\n'
              '• Powerful Pivot Tables & Slicers\n'
              '• Seamless Data Cleaning & Text-to-Columns\n'
              '• CSV & Excel File Support\n'
              '• Rich UI Formatting & Visualizations\n\n'
              'Designed to handle large datasets effortlessly, Spreadsheet Pro helps you turn raw numbers into actionable insights anywhere, anytime.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
