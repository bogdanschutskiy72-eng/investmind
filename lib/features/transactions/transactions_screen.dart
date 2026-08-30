import 'package:flutter/material.dart';

import '../../company/company_screen.dart';
import '../../services/transaction_service.dart';

class TransactionsScreen extends StatelessWidget {
  const TransactionsScreen({super.key});

  String _formatMoney(double value) {
    return '\$${value.toStringAsFixed(2)}';
  }

  String _formatQuantity(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }

    return value.toStringAsFixed(4);
  }

  String _formatDate(DateTime value) {
    final localValue = value.toLocal();

    final day = localValue.day.toString().padLeft(2, '0');
    final month = localValue.month.toString().padLeft(2, '0');
    final year = localValue.year.toString();

    final hour = localValue.hour.toString().padLeft(2, '0');
    final minute = localValue.minute.toString().padLeft(2, '0');

    return '$day.$month.$year • $hour:$minute';
  }

  double _totalRealizedProfit(List<PortfolioTransaction> transactions) {
    double total = 0;

    for (final transaction in transactions) {
      if (transaction.type == TransactionType.sell) {
        total += transaction.realizedProfit ?? 0;
      }
    }

    return total;
  }

  Widget _scoreBadge(String text, {bool highlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: highlight
            ? const Color(0xFF20D3C2).withValues(alpha: 0.10)
            : Colors.white.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: highlight ? const Color(0xFF20D3C2) : Colors.white70,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildAnalyticsSnapshot(PortfolioTransaction transaction) {
    final snapshot = transaction.analyticsSnapshot;

    if (snapshot == null) {
      return const Padding(
        padding: EdgeInsets.only(top: 12),
        child: Text(
          'Для этой старой операции '
          'аналитический snapshot не сохранён.',
          style: TextStyle(color: Colors.white38, fontSize: 11),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'InvestMind на момент операции',
            style: TextStyle(color: Colors.white54, fontSize: 11),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _scoreBadge(
                'InvestMind '
                '${snapshot.investMindScore}',
              ),
              _scoreBadge(
                'Opportunity '
                '${snapshot.opportunityScore}',
                highlight: true,
              ),
              _scoreBadge(
                'Context '
                '${snapshot.marketContextScore}',
              ),
              _scoreBadge(
                'Conf '
                '${snapshot.confidenceScore}',
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            'Зафиксировано: '
            '${_formatDate(snapshot.capturedAt)}',
            style: const TextStyle(color: Colors.white38, fontSize: 10),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('История операций')),
      body: ValueListenableBuilder<List<PortfolioTransaction>>(
        valueListenable: TransactionService.instance.transactions,
        builder: (context, transactions, _) {
          if (transactions.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.receipt_long_outlined,
                      size: 72,
                      color: Colors.white54,
                    ),
                    SizedBox(height: 20),
                    Text(
                      'История пока пуста',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Новые покупки и продажи '
                      'будут появляться здесь.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white60, fontSize: 16),
                    ),
                  ],
                ),
              ),
            );
          }

          final totalProfit = _totalRealizedProfit(transactions);

          final totalProfitPositive = totalProfit >= 0;

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Зафиксированный результат',
                      style: TextStyle(color: Colors.white60, fontSize: 15),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${totalProfitPositive ? '+' : '-'}'
                      '${_formatMoney(totalProfit.abs())}',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: totalProfitPositive
                            ? Colors.greenAccent
                            : Colors.redAccent,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Прибыль и убыток по '
                      'завершённым продажам',
                      style: TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Все операции',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ...transactions.map((transaction) {
                final isBuy = transaction.type == TransactionType.buy;

                final operationTitle = isBuy ? 'Покупка' : 'Продажа';

                final operationColor = isBuy
                    ? const Color(0xFF20D3C2)
                    : Colors.orangeAccent;

                final operationIcon = isBuy
                    ? Icons.add_shopping_cart
                    : Icons.sell_outlined;

                final realizedProfit = transaction.realizedProfit;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                CompanyScreen(company: transaction.symbol),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: operationColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  operationIcon,
                                  color: operationColor,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${transaction.company} • '
                                      '${transaction.symbol}',
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '$operationTitle • '
                                      '${_formatQuantity(transaction.quantity)} шт. '
                                      'по ${_formatMoney(transaction.price)}',
                                      style: TextStyle(
                                        color: operationColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _formatDate(transaction.createdAt),
                                      style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                _formatMoney(transaction.totalAmount),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          _buildAnalyticsSnapshot(transaction),
                          if (!isBuy && realizedProfit != null) ...[
                            const SizedBox(height: 14),
                            const Divider(height: 1),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                const Text(
                                  'Результат продажи',
                                  style: TextStyle(color: Colors.white60),
                                ),
                                const Spacer(),
                                Text(
                                  '${realizedProfit >= 0 ? '+' : '-'}'
                                  '${_formatMoney(realizedProfit.abs())}',
                                  style: TextStyle(
                                    color: realizedProfit >= 0
                                        ? Colors.greenAccent
                                        : Colors.redAccent,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}
