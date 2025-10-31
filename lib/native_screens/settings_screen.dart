import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notifications = true;
  bool _darkMode = false;
  bool _biometric = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Enable Notifications'),
            subtitle: const Text('Receive alerts and updates'),
            secondary: const Icon(Icons.notifications_outlined),
            value: _notifications,
            onChanged: (bool value) {
              setState(() {
                _notifications = value;
              });
            },
          ),
          SwitchListTile(
            title: const Text('Dark Mode'),
            subtitle: const Text('Use the dark theme'),
            secondary: const Icon(Icons.dark_mode_outlined),
            value: _darkMode,
            onChanged: (bool value) {
              setState(() {
                _darkMode = value;
                // Note: Theme switching logic would be handled by a theme provider
              });
            },
          ),
          SwitchListTile(
            title: const Text('Biometric Unlock'),
            subtitle: const Text('Use fingerprint or face to unlock'),
            secondary: const Icon(Icons.fingerprint),
            value: _biometric,
            onChanged: (bool value) {
              setState(() {
                _biometric = value;
              });
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy Policy'),
            onTap: () {
              // Navigate to a web privacy page
            },
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Terms of Service'),
            onTap: () {
              // Navigate to a web terms page
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About'),
            subtitle: const Text('Version 1.0.0'),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}
