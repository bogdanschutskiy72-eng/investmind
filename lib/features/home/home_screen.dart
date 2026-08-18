import 'package:flutter/material.dart';

import '../../shared/widgets/feature_tile.dart';

class HomeScreen extends StatelessWidget {
  final ValueChanged<int> onSelectPage;

  const HomeScreen({super.key, required this.onSelectPage});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ListView(
                children: [
                  const SizedBox(height: 20),

                  const Text(
                    'Добрый вечер, Богдан 👋',
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    'Анализируй. Понимай. Инвестируй осознанно.',
                    style: TextStyle(fontSize: 18, color: Colors.white70),
                  ),

                  const SizedBox(height: 30),

                  TextField(
                    readOnly: true,
                    onTap: () => onSelectPage(7),
                    decoration: InputDecoration(
                      hintText: 'Найти компанию...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: const Icon(Icons.arrow_forward_ios, size: 16),
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
                        onTap: () => onSelectPage(3),
                      ),
                      const SizedBox(width: 16),
                      FeatureTile(
                        icon: Icons.psychology,
                        title: 'Анализы',
                        onTap: () => onSelectPage(5),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      FeatureTile(
                        icon: Icons.public,
                        title: 'Рынок',
                        onTap: () => onSelectPage(1),
                      ),
                      const SizedBox(width: 16),
                      FeatureTile(
                        icon: Icons.account_balance_wallet,
                        title: 'Портфель',
                        onTap: () => onSelectPage(2),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  Row(
                    children: [
                      FeatureTile(
                        icon: Icons.receipt_long,
                        title: 'История',
                        onTap: () => onSelectPage(4),
                      ),
                      const SizedBox(width: 16),
                      FeatureTile(
                        icon: Icons.lightbulb_outline,
                        title: 'InvestMind AI',
                        onTap: () => onSelectPage(5),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
