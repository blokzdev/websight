import 'package:flutter/material.dart';

class PortfolioScreen extends StatelessWidget {
  const PortfolioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Portfolio'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.account_balance_wallet, size: 80),
            const SizedBox(height: 20),
            Text(
              'Total Value',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              '\$12,345.67',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
          ],
        ),
      ),
    );
  }
}
