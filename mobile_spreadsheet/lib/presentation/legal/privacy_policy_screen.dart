import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        backgroundColor: const Color(0xFF2848D3),
        foregroundColor: Colors.white,
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Text(
          'Privacy Policy\n\n'
          'Welcome to Spreadsheet Pro. Your privacy is important to us. This policy explains how we handle and protect your personal data when you use our services.\n\n'
          '1. Data Collection\nWe only collect the data necessary to provide you with the best spreadsheet experience. This includes basic usage statistics and your document preferences.\n\n'
          '2. Data Security\nWe implement robust security measures to ensure that your sheets and data remain completely confidential and secure.\n\n'
          '3. Third-Party Services\nWe do not sell or share your data with third parties. Your spreadsheets belong to you.',
          style: TextStyle(fontSize: 16, height: 1.5),
        ),
      ),
    );
  }
}
