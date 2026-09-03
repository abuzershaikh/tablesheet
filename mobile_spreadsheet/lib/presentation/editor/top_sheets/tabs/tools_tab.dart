import 'package:flutter/material.dart';
import '../components/drawer_action_card.dart';

class ToolsTab extends StatelessWidget {
  final VoidCallback onFindReplace;
  final VoidCallback onSmartTextParser;
  final VoidCallback onReceiptPdf;
  final VoidCallback onAudioRecorder;

  const ToolsTab({
    Key? key,
    required this.onFindReplace,
    required this.onSmartTextParser,
    required this.onReceiptPdf,
    required this.onAudioRecorder,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ADVANCED TOOLS & AI',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DrawerActionCard(
                  icon: Icons.search_rounded,
                  color: const Color(0xFF0078D4),
                  title: 'Find & Replace',
                  subtitle: 'Search text and replace values',
                  onTap: onFindReplace,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DrawerActionCard(
                  icon: Icons.auto_awesome_rounded,
                  color: const Color(0xFF8E44AD),
                  title: 'Smart Text AI',
                  subtitle: 'Parse un-structured text data',
                  onTap: onSmartTextParser,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DrawerActionCard(
                  icon: Icons.receipt_long_rounded,
                  color: const Color(0xFFE67E22),
                  title: 'PDF Receipt',
                  subtitle: 'Generate invoice/voucher for row',
                  onTap: onReceiptPdf,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DrawerActionCard(
                  icon: Icons.mic_rounded,
                  color: const Color(0xFFE74C3C),
                  title: 'Audio Notes',
                  subtitle: 'Record voice snippet for sheet',
                  onTap: onAudioRecorder,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }


}
