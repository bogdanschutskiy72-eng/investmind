import 'package:flutter/material.dart';

import '../../company/company_screen.dart';
import '../../services/favorites_service.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Избранное'),
      ),
      body: ValueListenableBuilder<Set<String>>(
        valueListenable: FavoritesService.instance.favorites,
        builder: (context, favorites, _) {
          final companies = favorites.toList()..sort();

          if (companies.isEmpty) {
            return const Center(
              child: Text(
                'Пока нет избранных компаний',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white70,
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: companies.length,
            itemBuilder: (context, index) {
              final company = companies[index];

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: ListTile(
                  leading: const Icon(
                    Icons.star,
                    color: Color(0xFF20D3C2),
                  ),
                  title: Text(
                    company,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: const Text(
                    'Нажмите, чтобы открыть компанию',
                  ),
                  trailing: IconButton(
                    onPressed: () {
                      FavoritesService.instance.remove(company);
                    },
                    tooltip: 'Удалить',
                    icon: const Icon(Icons.delete_outline),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CompanyScreen(
                          company: company,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}