import 'package:flutter/material.dart';
import '../../company/company_screen.dart';

class MarketScreen extends StatelessWidget {
  const MarketScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final companies = [
      "NVIDIA",
      "ASML",
      "TSMC",
      "AMD",
      "Microsoft",
      "Apple",
      "Amazon",
      "Meta",
      "Tesla",
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Рынок"),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: companies.length,
        itemBuilder: (context, index) {
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: ListTile(
              leading: const Icon(Icons.show_chart),
              title: Text(companies[index]),
              subtitle: const Text("Нажмите для анализа"),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CompanyScreen(
                      company: companies[index],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}