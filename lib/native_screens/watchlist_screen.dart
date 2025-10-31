import 'package:flutter/material.dart';

class WatchlistScreen extends StatelessWidget {
  const WatchlistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Watchlist'),
      ),
      body: ListView.separated(
        itemCount: 20,
        separatorBuilder: (context, index) => const Divider(),
        itemBuilder: (context, index) {
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
              child: const Icon(Icons.show_chart),
            ),
            title: Text('Ticker ${index + 1}'),
            subtitle: Text('Company Name ${index + 1}'),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\$${(100 + index * 5.37).toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '+${(0.5 + index * 0.1).toStringAsFixed(2)}%',
                  style: TextStyle(
                    color: Colors.green[700],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
