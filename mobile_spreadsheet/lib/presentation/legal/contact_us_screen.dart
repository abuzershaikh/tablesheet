import 'package:flutter/material.dart';

class ContactUsScreen extends StatelessWidget {
  const ContactUsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contact Us'),
        backgroundColor: const Color(0xFF2848D3),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Get in Touch',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Have questions, feedback, or need support? We are here to help!',
              style: TextStyle(fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 32),
            _buildContactCard(Icons.email, 'Email Support', 'support@tablesheets.com'),
            const SizedBox(height: 16),
            _buildContactCard(Icons.phone, 'Call Us', '+1 (800) 123-4567'),
            const SizedBox(height: 16),
            _buildContactCard(Icons.location_on, 'Office', '123 Tech Park, Innovation City'),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard(IconData icon, String title, String subtitle) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF2848D3).withOpacity(0.1),
          child: Icon(icon, color: const Color(0xFF2848D3)),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
      ),
    );
  }
}
