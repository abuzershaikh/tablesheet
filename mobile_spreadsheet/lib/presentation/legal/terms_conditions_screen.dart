import 'package:flutter/material.dart';

class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms & Conditions'),
        backgroundColor: const Color(0xFF2848D3),
        foregroundColor: Colors.white,
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Text(
          'Terms & Conditions\n\n'
          'Please read these terms and conditions carefully before using Spreadsheet Pro.\n\n'
          '1. Acceptance of Terms\nBy accessing and using this application, you accept and agree to be bound by the terms and provisions of this agreement.\n\n'
          '2. User Responsibilities\nYou are responsible for maintaining the confidentiality of your account and data. You agree not to use the application for any unlawful purpose.\n\n'
          '3. Modifications\nWe reserve the right to modify these terms at any time. Your continued use of the app constitutes agreement to any changes.\n\n'
          '4. Disclaimer\nThe application is provided "as is" without warranty of any kind. We are not liable for any data loss or damages arising from the use of this app.',
          style: TextStyle(fontSize: 16, height: 1.5),
        ),
      ),
    );
  }
}
