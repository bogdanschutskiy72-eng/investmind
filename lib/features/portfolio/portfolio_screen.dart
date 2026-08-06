import 'package:flutter/material.dart';

import '../../company/company_screen.dart';
import '../../services/portfolio_service.dart';
import '../../services/stock_service.dart';

class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({super.key});

  @override
  State<PortfolioScreen> createState() =>
      _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  final StockService _stockService = StockService();

  final Map<String, Future<StockQuote>> _quoteFutures =
      <String, Future<StockQuote>>{};

  Future<StockQuote> _quoteFor(String symbol) {
    return _quoteFutures.putIfAbsent(
      symbol,
      () => _stockService.fetchQuote(symbol),
    );
  }

  void _refreshQuotes() {
    setState(() {
      _quoteFutures.clear();
    });
  }

  String _formatMoney(double value) {
    return '\$${value.toStringAsFixed(2)}';
  }

  String _formatQuantity(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }

    return value.toStringAsFixed(4);
  }

  double? _parseNumber(String value) {
    return double.tryParse(
      value.trim().replaceAll(',', '.'),
    );
  }

  Future<void> _showPositionDialog({
    PortfolioPosition? position,
  }) async {
    final companyController = TextEditingController(
      text: position?.company ?? '',
    );

    final symbolController = TextEditingController(
      text: position?.symbol ?? '',
    );

    final quantityController = TextEditingController(
      text: position == null
          ? ''
          : _formatQuantity(position.quantity),
    );

    final averagePriceController = TextEditingController(
      text: position == null
          ? ''
          : position.averagePrice.toStringAsFixed(2),
    );

    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            position == null
                ? 'Добавить позицию'
                : 'Редактировать позицию',
          ),
          content: SizedBox(
            width: 420,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: companyController,
                      decoration: const InputDecoration(
                        labelText: 'Компания',
                        hintText: 'Например, NVIDIA',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: symbolController,
                      enabled: position == null,
                      textCapitalization:
                          TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Тикер',
                        hintText: 'Например, NVDA',
                      ),
                      validator: (value) {
                        if (value == null ||
                            value.trim().isEmpty) {
                          return 'Введите тикер';
                        }

                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: quantityController,
                      keyboardType:
                          const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Количество акций',
                      ),
                      validator: (value) {
                        final quantity = _parseNumber(
                          value ?? '',
                        );

                        if (quantity == null || quantity <= 0) {return 'Введите количество больше нуля';
                        }

                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: averagePriceController,
                      keyboardType:
                          const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Средняя цена',
                        prefixText: '\$ ',
                      ),
                      validator: (value) {
                        final price = _parseNumber(
                          value ?? '',
                        );

                        if (price == null || price <= 0) {
                          return 'Введите цену больше нуля';
                        }

                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) {
                  return;
                }

                await PortfolioService.instance
                    .addOrUpdatePosition(
                  company: companyController.text,
                  symbol: symbolController.text,
                  quantity:
                      _parseNumber(quantityController.text)!,
                  averagePrice: _parseNumber(
                    averagePriceController.text,
                  )!,
                );

                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext, true);
                }
              },
              child: const Text('Сохранить'),
            ),
          ],
        );
      },
    );

    if (saved == true && mounted) {
      _refreshQuotes();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Позиция сохранена'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _showSellDialog({
    required PortfolioPosition position,
    required double currentPrice,
  }) async {
    final quantityController = TextEditingController(
      text: _formatQuantity(position.quantity),
    );

    final priceController = TextEditingController(
      text: currentPrice.toStringAsFixed(2),
    );

    final formKey = GlobalKey<FormState>();

    final sold = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Продать акции'),
          content: SizedBox(
            width: 420,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${position.company} • '
                      '${position.symbol}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'В портфеле: '
                      '${_formatQuantity(position.quantity)} шт.\n'
                      'Средняя цена: '
                      '${_formatMoney(position.averagePrice)}',
                      style: const TextStyle(
                        color: Colors.white60,
                      ),
                    ),
                    const SizedBox(height: 20),TextFormField(
                      controller: quantityController,
                      keyboardType:
                          const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Количество для продажи',
                      ),
                      validator: (value) {
                        final quantity = _parseNumber(
                          value ?? '',
                        );

                        if (quantity == null || quantity <= 0) {
                          return 'Введите количество больше нуля';
                        }

                        if (quantity > position.quantity) {
                          return 'В портфеле недостаточно акций';
                        }

                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: priceController,
                      keyboardType:
                          const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Цена продажи',
                        prefixText: '\$ ',
                      ),
                      validator: (value) {
                        final price = _parseNumber(
                          value ?? '',
                        );

                        if (price == null || price <= 0) {
                          return 'Введите цену больше нуля';
                        }

                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Отмена'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                if (!formKey.currentState!.validate()) {
                  return;
                }

                try {
                  final profit =
                      await PortfolioService.instance
                          .sellPosition(
                    symbol: position.symbol,
                    quantity:
                        _parseNumber(quantityController.text)!,
                    salePrice:
                        _parseNumber(priceController.text)!,
                  );

                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext, true);
                  }

                  if (mounted) {
                    final resultText = profit >= 0
                        ? 'Прибыль: ${_formatMoney(profit)}'
                        : 'Убыток: ${_formatMoney(profit.abs())}';

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Продажа сохранена. $resultText',
                        ),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                } catch (error) {
                  if (!dialogContext.mounted) {
                    return;
                  }

                  ScaffoldMessenger.of(dialogContext)
                      .showSnackBar(
                    SnackBar(
                      content: Text(error.toString()),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.sell_outlined),
              label: const Text('Продать'),
            ),
          ],
        );
      },
    );

    if (sold == true && mounted) {
      _refreshQuotes();
    }
  }

  Future<void> _confirmDelete(
    PortfolioPosition position,
  ) async {final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Удалить позицию?'),
          content: Text(
            '${position.company} • ${position.symbol}\n\n'
            'Позиция будет удалена без записи продажи '
            'в историю.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text(
                'Удалить',
                style: TextStyle(
                  color: Colors.redAccent,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await PortfolioService.instance.removePosition(
        position.symbol,
      );

      _refreshQuotes();
    }
  }

  Future<_PortfolioSummary> _loadSummary(
    List<PortfolioPosition> positions,
  ) async {
    double invested = 0;
    double currentValue = 0;

    for (final position in positions) {
      invested += position.investedAmount;

      try {
        final quote = await _quoteFor(position.symbol);

        currentValue +=
            quote.currentPrice * position.quantity;
      } catch (_) {
        currentValue += position.investedAmount;
      }
    }

    return _PortfolioSummary(
      invested: invested,
      currentValue: currentValue,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Портфель'),
        actions: [
          IconButton(
            onPressed: _refreshQuotes,
            tooltip: 'Обновить котировки',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showPositionDialog,
        icon: const Icon(Icons.add),
        label: const Text('Добавить'),
      ),
      body: ValueListenableBuilder<List<PortfolioPosition>>(
        valueListenable:
            PortfolioService.instance.positions,
        builder: (context, positions, _) {
          if (positions.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 72,
                      color: Colors.white54,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Портфель пока пуст',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Добавь первую позицию или покупку '
                      'со страницы компании.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _showPositionDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('Добавить позицию'),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              _refreshQuotes();
            },
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [FutureBuilder<_PortfolioSummary>(
                  future: _loadSummary(positions),
                  builder: (context, snapshot) {
                    final summary = snapshot.data;

                    if (summary == null) {
                      return const SizedBox(
                        height: 160,
                        child: Center(
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    final profit =
                        summary.currentValue -
                            summary.invested;

                    final profitPercent =
                        summary.invested == 0
                            ? 0.0
                            : profit /
                                summary.invested *
                                100;

                    final isPositive = profit >= 0;

                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius:
                            BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Стоимость портфеля',
                            style: TextStyle(
                              color: Colors.white60,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _formatMoney(
                              summary.currentValue,
                            ),
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '${isPositive ? '+' : '-'}'
                            '${_formatMoney(profit.abs())} '
                            '(${isPositive ? '+' : '-'}'
                            '${profitPercent.abs().toStringAsFixed(2)}%)',
                            style: TextStyle(
                              color: isPositive
                                  ? Colors.greenAccent
                                  : Colors.redAccent,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Вложено: '
                            '${_formatMoney(summary.invested)}',
                            style: const TextStyle(
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                const Text(
                  'Мои позиции',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ...positions.map(
                  (position) => Padding(
                    padding:
                        const EdgeInsets.only(bottom: 14),
                    child: FutureBuilder<StockQuote>(
                      future: _quoteFor(position.symbol),
                      builder: (context, snapshot) {
                        final quote = snapshot.data;

                        final currentPrice =
                            quote?.currentPrice ??
                                position.averagePrice;

                        final currentValue =
                            currentPrice *
                                position.quantity;

                        final profit = currentValue -
                            position.investedAmount;

                        final isPositive = profit >= 0;

                        return Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius:
                                BorderRadius.circular(18),
                          ),
                          child: Column(
                            children: [
                              InkWell(
                                borderRadius:
                                    BorderRadius.circular(14),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          CompanyScreen(
                                        company:
                                            position.company,
                                      ),
                                    ),
                                  );
                                },
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment
                                                .start,
                                        children: [
                                          Text(
                                            position.company,
                                            style:
                                                const TextStyle(
                                              fontSize: 19,
                                              fontWeight:
                                                  FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 5),
                                          Text(
                                            '${position.symbol} • '
                                            '${_formatQuantity(position.quantity)} шт.',
                                            style:
                                                const TextStyle(
                                              color:
                                                  Colors.white60,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          _formatMoney(
                                            currentValue,
                                          ),
                                          style:
                                              const TextStyle(
                                            fontSize: 19,
                                            fontWeight:
                                                FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Text('${isPositive ? '+' : '-'}'
                                          '${_formatMoney(profit.abs())}',
                                          style: TextStyle(
                                            color: isPositive
                                                ? Colors
                                                    .greenAccent
                                                : Colors
                                                    .redAccent,
                                            fontWeight:
                                                FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Divider(height: 1),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        _showSellDialog(
                                          position: position,
                                          currentPrice:
                                              currentPrice,
                                        );
                                      },
                                      icon: const Icon(
                                        Icons.sell_outlined,
                                      ),
                                      label:
                                          const Text('Продать'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  IconButton(
                                    onPressed: () {
                                      _showPositionDialog(
                                        position: position,
                                      );
                                    },
                                    tooltip: 'Редактировать',
                                    icon: const Icon(
                                      Icons.edit_outlined,
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () {
                                      _confirmDelete(position);
                                    },
                                    tooltip: 'Удалить',
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.redAccent,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PortfolioSummary {
  final double invested;
  final double currentValue;

  const _PortfolioSummary({
    required this.invested,
    required this.currentValue,
  });
}