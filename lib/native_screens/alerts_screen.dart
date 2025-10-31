import 'package:flutter/material.dart';

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alerts'),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications, size: 80, color: Colors.grey),
            SizedBox(height: 20),
            Text('No new alerts'),
          ],
        ),
      ),
    );
  }
}
