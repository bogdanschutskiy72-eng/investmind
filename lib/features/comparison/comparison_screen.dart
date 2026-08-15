import 'package:flutter/material.dart';

class ComparisonScreen extends StatelessWidget {
  const ComparisonScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Сравнение компаний',
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Выбери несколько компаний, чтобы сравнить их '
                    'по ключевым показателям InvestMind.',
                    style: TextStyle(fontSize: 17, color: Colors.white70),
                  ),
                  const SizedBox(height: 28),

                  Expanded(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.compare_arrows,
                              size: 64,
                              color: Color(0xFF20D3C2),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Модуль сравнения подключён',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 10),
                            Text(
                              'Следующим шагом добавим выбор 2–4 компаний '
                              'и таблицу Technical, Fundamental, Growth, '
                              'Valuation, Risk и Confidence.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white70,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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
