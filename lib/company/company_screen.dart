import 'dart:async';

import 'package:flutter/material.dart';

import '../services/favorites_service.dart';
import '../services/stock_service.dart';
import '../shared/widgets/info_card.dart';
import '../shared/widgets/price_chart.dart';

class CompanyScreen extends StatefulWidget {
  final String company;

  const CompanyScreen({
    super.key,
    required this.company,
  });

  @override
  State<CompanyScreen> createState() => _CompanyScreenState();
}

class _CompanyScreenState extends State<CompanyScreen> {
  final StockService _stockService = StockService();

  late Future<StockQuote> _quoteFuture;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();

    _quoteFuture = _fetchQuote();

    _refreshTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _refreshQuote(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<StockQuote> _fetchQuote() {
    return _stockService.fetchQuote(
      _symbolForCompany(widget.company),
    );
  }

  void _refreshQuote() {
    if (!mounted) return;

    setState(() {
      _quoteFuture = _fetchQuote();
    });
  }

  String _symbolForCompany(String company) {
    switch (company.toUpperCase()) {
      case 'NVIDIA':
        return 'NVDA';
      case 'ASML':
        return 'ASML';
      case 'TSMC':
        return 'TSM';
      case 'AMD':
        return 'AMD';
      case 'MICROSOFT':
        return 'MSFT';
      case 'APPLE':
        return 'AAPL';
      case 'AMAZON':
        return 'AMZN';
      case 'META':
        return 'META';
      case 'TESLA':
        return 'TSLA';
      default:
        return company.toUpperCase();
    }
  }

  String _sectorForCompany(String company) {
    switch (company.toUpperCase()) {
      case 'NVIDIA':
      case 'ASML':
      case 'TSMC':
      case 'AMD':
        return 'Полупроводники';
      case 'MICROSOFT':
        return 'Программное обеспечение';
      case 'APPLE':
        return 'Потребительская электроника';
      case 'AMAZON':
        return 'Электронная коммерция';
      case 'META':
        return 'Интернет и реклама';
      case 'TESLA':
        return 'Автомобили';
      default:
        return 'Технологии';
    }
  }

  String _formatPrice(double value) {
    return '\$${value.toStringAsFixed(2)}';
  }

  String _formatUpdatedAt(DateTime? value) {
    if (value == null) {
      return 'нет данных';
    }

    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');

    return '$day.$month в $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final symbol = _symbolForCompany(widget.company);

    return Scaffold(
appBar: AppBar(
  title: Text(widget.company),
  actions: [
    ValueListenableBuilder<Set<String>>(
      valueListenable: FavoritesService.instance.favorites,
      builder: (context, favorites, _) {
        final isFavorite = favorites.contains(widget.company);

        return IconButton(
          onPressed: () {
            FavoritesService.instance.toggleFavorite(
              widget.company,
            );
          },
          tooltip: isFavorite
              ? 'Удалить из избранного'
              : 'Добавить в избранное',
          icon: Icon(
            isFavorite ? Icons.star : Icons.star_border,
            color: isFavorite
                ? const Color(0xFF20D3C2)
                : Colors.white,
          ),
        );
      },
    ),
    IconButton(
      onPressed: _refreshQuote,
      tooltip: 'Обновить котировку',
      icon: const Icon(Icons.refresh),
    ),
  ],
),
      body: FutureBuilder<StockQuote>(
        future: _quoteFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.cloud_off,
                      size: 48,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Не удалось загрузить котировку',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),const SizedBox(height: 8),
                    Text(
                      snapshot.error.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _refreshQuote,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Повторить'),
                    ),
                  ],
                ),
              ),
            );
          }

          final quote = snapshot.data;

          if (quote == null) {
            return const Center(
              child: Text('Котировка не получена'),
            );
          }

          final isPositive = quote.percentChange >= 0;

          final changeColor = isPositive
              ? Colors.greenAccent
              : Colors.redAccent;

          final changeSign = isPositive ? '+' : '';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.company,
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$symbol • ${_sectorForCompany(widget.company)}',
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 24),
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
                        'Текущая цена',
                        style: TextStyle(
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _formatPrice(quote.currentPrice),
                        style: const TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$changeSign'
                        '${quote.percentChange.toStringAsFixed(2)}%'
                        '  •  '
                        '$changeSign'
                        '\$${quote.change.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: changeColor,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Обновлено: '
                        '${_formatUpdatedAt(quote.updatedAt)}',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                PriceChart(
                  symbol: symbol,
                ),

                const SizedBox(height: 24),
                const Text(
                  'Данные за торговый день',
                  style: TextStyle(fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    InfoCard(
                      title: 'Открытие',
                      value: _formatPrice(quote.open),
                    ),
                    const SizedBox(width: 16),
                    InfoCard(
                      title: 'Максимум',
                      value: _formatPrice(quote.high),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    InfoCard(
                      title: 'Минимум',
                      value: _formatPrice(quote.low),
                    ),
                    const SizedBox(width: 16),
                    InfoCard(
                      title: 'Пред. закрытие',
                      value: _formatPrice(
                        quote.previousClose,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text(
                  'Краткий анализ',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Цена и данные торгового дня загружаются '
                  'автоматически. Исторический график меняется '
                  'в зависимости от выбранной компании и периода.',
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Демо-рейтинг InvestMind',
                        style: TextStyle(
                          color: Colors.white70,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        '9.6 / 10',
                        style: TextStyle(
                          fontSize: 42,
                          color: Colors.greenAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}