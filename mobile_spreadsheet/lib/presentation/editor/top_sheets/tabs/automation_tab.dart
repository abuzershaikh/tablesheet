import 'package:flutter/material.dart';
import '../components/drawer_action_card.dart';

class AutomationTab extends StatelessWidget {
  final VoidCallback? onOpenPowerScriptStudio;

  const AutomationTab({
    Key? key,
    this.onOpenPowerScriptStudio,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'WORKFLOW AUTOMATION',
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
                  icon: Icons.code_rounded,
                  color: const Color(0xFF107C41),
                  title: 'PowerScript Studio',
                  subtitle: 'Write JS macros & custom scripts',
                  onTap: () => onOpenPowerScriptStudio?.call(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DrawerActionCard(
                  icon: Icons.api_rounded,
                  color: const Color(0xFF00BCD4),
                  title: 'Connect API',
                  subtitle: 'Fetch data via JS fetch API',
                  onTap: () => onOpenPowerScriptStudio?.call(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DrawerActionCard(
                  icon: Icons.message_rounded,
                  color: const Color(0xFF25D366),
                  title: 'WhatsApp Message',
                  subtitle: 'Send messages from sheet',
                  onTap: () {},
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DrawerActionCard(
                  icon: Icons.format_align_center_rounded,
                  color: const Color(0xFF673AB7),
                  title: 'Google Form',
                  subtitle: 'Capture responses to sheet',
                  onTap: () {},
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
