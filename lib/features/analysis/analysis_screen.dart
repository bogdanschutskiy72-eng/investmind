import 'package:flutter/material.dart';

import '../comparison/comparison_screen.dart';
import 'company_analysis_screen.dart';

class AnalysisScreen extends StatelessWidget {
  const AnalysisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Анализы')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Text(
                  'InvestMind Intelligence',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 8),

                const Text(
                  'Данные вместо шума. Анализ вместо эмоций.',
                  style: TextStyle(fontSize: 17, color: Colors.white60),
                ),

                const SizedBox(height: 28),

                _AnalysisCard(
                  icon: Icons.business_outlined,
                  title: 'Анализ компании',
                  description:
                      'Финансовые показатели, движение цены, '
                      'риски и ключевые рыночные сигналы.',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CompanyAnalysisScreen(),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 16),

                _AnalysisCard(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Анализ портфеля',
                  description:
                      'Концентрация активов, распределение риска '
                      'и зависимость от отдельных отраслей.',
                  onTap: () {
                    _showComingSoon(context, 'Анализ портфеля');
                  },
                ),

                const SizedBox(height: 16),

                _AnalysisCard(
                  icon: Icons.compare_arrows,
                  title: 'Сравнение компаний',
                  description:
                      'Сравнение от 2 до 4 компаний по '
                      'InvestMind Score, фундаментальным, '
                      'техническим показателям и AI-анализу.',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ComparisonScreen(),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 16),

                _AnalysisCard(
                  icon: Icons.psychology_outlined,
                  title: 'Спросить InvestMind',
                  description:
                      'Будущий ИИ-помощник для вопросов о компаниях, '
                      'рынке и собственном портфеле.',
                  onTap: () {
                    _showComingSoon(context, 'InvestMind AI');
                  },
                ),

                const SizedBox(height: 28),

                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.shield_outlined, color: Color(0xFF20D3C2)),

                      SizedBox(width: 14),

                      Expanded(
                        child: Text(
                          'ИИ InvestMind будет объяснять данные и риски, '
                          'но не сможет самостоятельно совершать сделки '
                          'или управлять деньгами пользователя.',
                          style: TextStyle(height: 1.5, color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature — модуль готовится к подключению.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _AnalysisCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _AnalysisCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: const Color(0xFF20D3C2).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: const Color(0xFF20D3C2), size: 28),
            ),

            const SizedBox(width: 18),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    description,
                    style: const TextStyle(color: Colors.white60, height: 1.4),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            const Icon(Icons.chevron_right, color: Colors.white38),
          ],
        ),
      ),
    );
  }
}
