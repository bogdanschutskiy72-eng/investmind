import 'package:flutter/material.dart';

import '../../shared/widgets/feature_tile.dart';
import '../favorites/favorites_screen.dart';
import '../market/market_screen.dart';
import '../portfolio/portfolio_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ListView(
            children: [
              const SizedBox(height: 20),
              const Center(
                child: Text(
                  'InvestMind',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                'Добрый вечер, Богдан 👋',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Анализируй.\nПонимай.\nИнвестируй осознанно.',
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
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const FavoritesScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 16),
                  FeatureTile(
                    icon: Icons.analytics,
                    title: 'Анализы',
                    onTap: () {},
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  FeatureTile(
                    icon: Icons.public,
                    title: 'Рынок',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MarketScreen(),
                        ),);
                    },
                  ),
                  const SizedBox(width: 16),
                  FeatureTile(
                    icon: Icons.account_balance_wallet,
                    title: 'Портфель',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PortfolioScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}