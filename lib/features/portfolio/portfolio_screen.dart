import 'package:flutter/material.dart';

import '../../company/company_screen.dart';
import '../../services/portfolio_service.dart';
import '../../services/stock_service.dart';

class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({super.key});

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  final StockService _stockService = StockService();

  final Map<String, Future<StockQuote>> _quoteFutures = {};

  Future<StockQuote> _quoteForSymbol(String symbol) {
    return _quoteFutures.putIfAbsent(
      symbol,
      () => _stockService.fetchQuote(symbol),
    );
  }

  Future<StockQuote?> _safeQuote(String symbol) async {
    try {
      return await _quoteForSymbol(symbol);
    } catch (_) {
      return null;
    }
  }

  void _refreshAll() {
    setState(() {
      _quoteFutures.clear();
    });
  }

  void _refreshSymbol(String symbol) {
    setState(() {
      _quoteFutures[symbol] =
          _stockService.fetchQuote(symbol);
    });
  }

  double? _parseNumber(String value) {
    return double.tryParse(
      value.trim().replaceAll(',', '.'),
    );
  }

  String _money(double value) {
    return '\$${value.toStringAsFixed(2)}';
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
      text: position?.quantity.toString() ?? '',
    );

    final averagePriceController = TextEditingController(
      text: position?.averagePrice.toString() ?? '',
    );

    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            position == null
                ? 'Добавить позицию'
                : 'Изменить позицию',
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
                        labelText: 'Название компании',
                        hintText: 'Например, NVIDIA',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: symbolController,
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
                        hintText: 'Например, 2.5',
                      ),
                      validator: (value) {
                        final number = _parseNumber(value ?? '');

                        if (number == null || number <= 0) {
                          return 'Введите количество больше нуля';}

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
                        labelText: 'Средняя цена покупки',
                        hintText: 'Например, 180.50',
                        prefixText: '\$ ',
                      ),
                      validator: (value) {
                        final number = _parseNumber(value ?? '');

                        if (number == null || number <= 0) {
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
                Navigator.pop(dialogContext);
              },
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) {
                  return;
                }

                final symbol =
                    symbolController.text.trim().toUpperCase();

                final quantity = _parseNumber(
                  quantityController.text,
                )!;

                final averagePrice = _parseNumber(
                  averagePriceController.text,
                )!;

                await PortfolioService.instance.addOrUpdatePosition(
                  company: companyController.text,
                  symbol: symbol,
                  quantity: quantity,
                  averagePrice: averagePrice,
                );

                _quoteFutures.remove(symbol);

                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
              },
              child: const Text('Сохранить'),
            ),
          ],
        );
      },
    );


  }

  Future<void> _removePosition(
    PortfolioPosition position,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Удалить позицию?'),
          content: Text(
            '${position.company} будет удалена из портфеля.',
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

    if (shouldDelete != true) {
      return;
    }

    await PortfolioService.instance.removePosition(
      position.symbol,
    );

    _quoteFutures.remove(position.symbol);
  }

  void _openCompany(PortfolioPosition position) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CompanyScreen(
          company: position.symbol,
        ),
      ),
    );
  }

  Widget _buildSummary(
    List<PortfolioPosition> positions,
  ) {
    final totalInvested = positions.fold<double>(
      0,
      (sum, position) => sum + position.investedAmount,
    );

    return FutureBuilder<List<StockQuote?>>(
      future: Future.wait(
        positions.map(
          (position) => _safeQuote(position.symbol),
        ),
      ),
      builder: (context, snapshot) {
        double currentValue = 0;
        bool hasAllQuotes = false;

        if (snapshot.hasData) {
          hasAllQuotes = snapshot.data!.every(
            (quote) => quote != null,
          );

          for (var index = 0;
              index < positions.length;
              index++) {
            final quote = snapshot.data![index];

            if (quote != null) {
              currentValue +=
                  quote.currentPrice * positions[index].quantity;
            }
          }
        }

        final profit = currentValue - totalInvested;

        final profitPercent = totalInvested > 0
            ? profit / totalInvested * 100
            : 0.0;

        final isPositive = profit >= 0;

        return Container(
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
                'Общая стоимость',
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              if (snapshot.connectionState ==
                  ConnectionState.waiting)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: CircularProgressIndicator(),
                )
              else
                Text(
                  _money(currentValue),
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _SummaryValue(
                      title: 'Вложено',
                      value: _money(totalInvested),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _SummaryValue(
                      title: 'Прибыль / убыток',
                      value: hasAllQuotes
                          ? '${isPositive ? '+' : ''}'
                              '${_money(profit)}\n'
                              '${isPositive ? '+' : ''}'
                              '${profitPercent.toStringAsFixed(2)}%'
                          : 'Нет всех данных',
                      valueColor: hasAllQuotes
                          ? isPositive
                              ? Colors.greenAccent
                              : Colors.redAccent
                          : Colors.white54,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPositionCard(
    PortfolioPosition position,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
      ),
      child: InkWell(
        onTap: () => _openCompany(position),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0x3320D3C2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  position.symbol.length > 6
                      ? position.symbol.substring(0, 6)
                      : position.symbol,
                  style: const TextStyle(
                    color: Color(0xFF20D3C2),fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      position.company,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${position.quantity} акц. • '
                      'средняя ${_money(position.averagePrice)}',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 115,
                child: FutureBuilder<StockQuote>(
                  future: _quoteForSymbol(position.symbol),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Align(
                        alignment: Alignment.centerRight,
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        ),
                      );
                    }

                    if (snapshot.hasError ||
                        snapshot.data == null) {
                      return IconButton(
                        onPressed: () {
                          _refreshSymbol(position.symbol);
                        },
                        tooltip: 'Повторить',
                        icon: const Icon(
                          Icons.refresh,
                          color: Colors.redAccent,
                        ),
                      );
                    }

                    final quote = snapshot.data!;

                    final currentValue =
                        quote.currentPrice * position.quantity;

                    final profit =
                        currentValue - position.investedAmount;

                    final isPositive = profit >= 0;

                    return Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.end,
                      children: [
                        Text(
                          _money(currentValue),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${isPositive ? '+' : ''}'
                          '${_money(profit)}',
                          style: TextStyle(
                            color: isPositive
                                ? Colors.greenAccent
                                : Colors.redAccent,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    _showPositionDialog(
                      position: position,
                    );
                  }

                  if (value == 'delete') {_removePosition(position);
                  }
                },
                itemBuilder: (context) {
                  return const [
                    PopupMenuItem(
                      value: 'edit',
                      child: Text('Изменить'),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('Удалить'),
                    ),
                  ];
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Портфель'),
        actions: [
          IconButton(
            onPressed: _refreshAll,
            tooltip: 'Обновить котировки',
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: _showPositionDialog,
            tooltip: 'Добавить позицию',
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: ValueListenableBuilder<List<PortfolioPosition>>(
        valueListenable:
            PortfolioService.instance.positions,
        builder: (context, positions, _) {
          if (positions.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 58,
                    color: Colors.white38,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Портфель пока пуст',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Добавь первую купленную акцию',
                    style: TextStyle(
                      color: Colors.white60,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _showPositionDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Добавить позицию'),
                  ),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildSummary(positions),
              const SizedBox(height: 24),
              Text(
                'Позиции: ${positions.length}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ...positions.map(_buildPositionCard),
            ],
          );
        },
      ),
    );
  }
}

class _SummaryValue extends StatelessWidget {
  final String title;
  final String value;
  final Color? valueColor;

  const _SummaryValue({
    required this.title,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}