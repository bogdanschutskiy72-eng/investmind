import 'package:flutter/material.dart';

import '../../shared/widgets/feature_tile.dart';

class HomeScreen extends StatelessWidget {
  final VoidCallback? onOpenFavorites;
  final VoidCallback? onOpenTransactions;
  final VoidCallback? onOpenMarket;
  final VoidCallback? onOpenPortfolio;

  const HomeScreen({
    super.key,
    this.onOpenFavorites,
    this.onOpenTransactions,
    this.onOpenMarket,
    this.onOpenPortfolio,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 1200,
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ListView(
                children: [
                  const SizedBox(height: 20),
                  const Text(
                    'Добрый вечер, Богдан 👋',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Анализируй. Понимай. Инвестируй осознанно.',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 30),
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Найти компанию...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: const Color(0xFF1E293B),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '💡 Честный вывод дня',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Компании, связанные с искусственным интеллектом, '
                          'продолжают демонстрировать рост, но высокая оценка '
                          'требует осторожности.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      FeatureTile(
                        icon: Icons.star,
                        title: 'Избранное',
                        onTap: onOpenFavorites ?? () {},
                      ),
                      const SizedBox(width: 16),
                      FeatureTile(
                        icon: Icons.receipt_long,
                        title: 'История',
                        onTap: onOpenTransactions ?? () {},
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      FeatureTile(
                        icon: Icons.public,
                        title: 'Рынок',
                        onTap: onOpenMarket ?? () {},
                      ),
                      const SizedBox(width: 16),
                      FeatureTile(icon: Icons.account_balance_wallet,
                        title: 'Портфель',
                        onTap: onOpenPortfolio ?? () {},
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}