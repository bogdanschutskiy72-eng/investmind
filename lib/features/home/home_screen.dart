import 'package:flutter/material.dart';
import '../../shared/widgets/feature_tile.dart';

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

              // Логотип / название
              const Center(
                child: Text(
                  'InvestMind',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // Приветствие
              const Text(
                'Добрый вечер, Богдан 👋',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Анализируй.\nПонимай.\nИнвестируй осознанно.',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey.shade400,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 32),

              // Поиск
              TextField(
                decoration: InputDecoration(
                  hintText: 'Найти компанию...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Карточка дня
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      '💡 Честный вывод дня',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Компании, связанные с искусственным интеллектом, '
                      'продолжают демонстрировать рост, но высокая оценка '
                      'требует осторожности.',
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              Row(
                children: const [
                  FeatureTile(
                    icon: Icons.star,
                    title: 'Избранное',
                  ),
                  SizedBox(width: 16),
                  FeatureTile(
                    icon: Icons.analytics,
                    title: 'Анализы',
                  ),
                ],
              ),

              const SizedBox(height: 16),

              Row(
                children: const [
                  FeatureTile(
                    icon: Icons.public,
                    title: 'Рынок',
                  ),
                  SizedBox(width: 16),
                  FeatureTile(
                    icon: Icons.account_balance_wallet,
                    title: 'Портфель',
                  ),
                ],
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}