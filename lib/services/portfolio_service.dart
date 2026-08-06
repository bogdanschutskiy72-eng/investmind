import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'transaction_service.dart';

class PortfolioPosition {
  final String company;
  final String symbol;
  final double quantity;
  final double averagePrice;

  const PortfolioPosition({
    required this.company,
    required this.symbol,
    required this.quantity,
    required this.averagePrice,
  });

  double get investedAmount => quantity * averagePrice;

  Map<String, dynamic> toJson() {
    return {
      'company': company,
      'symbol': symbol,
      'quantity': quantity,
      'averagePrice': averagePrice,
    };
  }

  factory PortfolioPosition.fromJson(
    Map<String, dynamic> json,
  ) {
    return PortfolioPosition(
      company: json['company']?.toString() ?? '',
      symbol: json['symbol']?.toString() ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
      averagePrice:
          (json['averagePrice'] as num?)?.toDouble() ?? 0,
    );
  }
}

class PortfolioService {
  PortfolioService._();

  static final PortfolioService instance =
      PortfolioService._();

  static const String _storageKey = 'portfolio_positions';

  final ValueNotifier<List<PortfolioPosition>> positions =
      ValueNotifier<List<PortfolioPosition>>(
    <PortfolioPosition>[],
  );

  late SharedPreferences _preferences;

  Future<void> initialize() async {
    _preferences = await SharedPreferences.getInstance();

    final savedData =
        _preferences.getStringList(_storageKey) ?? <String>[];

    final loadedPositions = <PortfolioPosition>[];

    for (final item in savedData) {
      try {
        final decoded = jsonDecode(item);

        if (decoded is Map<String, dynamic>) {
          final position =
              PortfolioPosition.fromJson(decoded);

          if (position.symbol.isNotEmpty &&
              position.quantity > 0 &&
              position.averagePrice > 0) {
            loadedPositions.add(position);
          }
        }
      } catch (_) {
        // Повреждённую запись пропускаем.
      }
    }

    loadedPositions.sort(
      (first, second) =>
          first.symbol.compareTo(second.symbol),
    );

    positions.value = loadedPositions;
  }

  Future<void> addPurchase({
    required String company,
    required String symbol,
    required double quantity,
    required double purchasePrice,
  }) async {
    final normalizedSymbol =
        symbol.trim().toUpperCase();

    final normalizedCompany = company.trim();

    if (normalizedSymbol.isEmpty ||
        quantity <= 0 ||
        purchasePrice <= 0) {
      throw ArgumentError(
        'Проверь тикер, количество и цену покупки.',
      );
    }

    final updated =
        List<PortfolioPosition>.from(positions.value);

    final existingIndex = updated.indexWhere(
      (position) =>
          position.symbol == normalizedSymbol,
    );

    if (existingIndex >= 0) {
      final existing = updated[existingIndex];

      final totalQuantity =
          existing.quantity + quantity;

      final totalInvested =
          existing.investedAmount +
          quantity * purchasePrice;

      final newAveragePrice =
          totalInvested / totalQuantity;

      updated[existingIndex] = PortfolioPosition(
        company: normalizedCompany.isEmpty
            ? existing.company
            : normalizedCompany,
        symbol: normalizedSymbol,
        quantity: totalQuantity,
        averagePrice: newAveragePrice,
      );
    } else {
      updated.add(
        PortfolioPosition(
          company: normalizedCompany.isEmpty
              ? normalizedSymbol
              : normalizedCompany,
          symbol: normalizedSymbol,
          quantity: quantity,
          averagePrice: purchasePrice,
        ),
      );
    }

    updated.sort(
      (first, second) =>
          first.symbol.compareTo(second.symbol),
    );

    positions.value = updated;

    await _save();

    await TransactionService.instance.addTransaction(
      company: normalizedCompany.isEmpty
          ? normalizedSymbol: normalizedCompany,
      symbol: normalizedSymbol,
      type: TransactionType.buy,
      quantity: quantity,
      price: purchasePrice,
    );
  }

  Future<double> sellPosition({
    required String symbol,
    required double quantity,
    required double salePrice,
  }) async {
    final normalizedSymbol =
        symbol.trim().toUpperCase();

    if (normalizedSymbol.isEmpty ||
        quantity <= 0 ||
        salePrice <= 0) {
      throw ArgumentError(
        'Проверь тикер, количество и цену продажи.',
      );
    }

    final updated =
        List<PortfolioPosition>.from(positions.value);

    final existingIndex = updated.indexWhere(
      (position) =>
          position.symbol == normalizedSymbol,
    );

    if (existingIndex < 0) {
      throw StateError(
        'Позиция $normalizedSymbol не найдена.',
      );
    }

    final existing = updated[existingIndex];

    if (quantity > existing.quantity) {
      throw StateError(
        'Нельзя продать больше акций, чем есть в портфеле.',
      );
    }

    final realizedProfit =
        (salePrice - existing.averagePrice) * quantity;

    final remainingQuantity =
        existing.quantity - quantity;

    if (remainingQuantity <= 0.000001) {
      updated.removeAt(existingIndex);
    } else {
      updated[existingIndex] = PortfolioPosition(
        company: existing.company,
        symbol: existing.symbol,
        quantity: remainingQuantity,
        averagePrice: existing.averagePrice,
      );
    }

    positions.value = updated;

    await _save();

    await TransactionService.instance.addTransaction(
      company: existing.company,
      symbol: existing.symbol,
      type: TransactionType.sell,
      quantity: quantity,
      price: salePrice,
      realizedProfit: realizedProfit,
    );

    return realizedProfit;
  }

  Future<void> addOrUpdatePosition({
    required String company,
    required String symbol,
    required double quantity,
    required double averagePrice,
  }) async {
    final normalizedSymbol =
        symbol.trim().toUpperCase();

    final normalizedCompany = company.trim();

    if (normalizedSymbol.isEmpty ||
        quantity <= 0 ||
        averagePrice <= 0) {
      throw ArgumentError(
        'Проверь тикер, количество и среднюю цену.',
      );
    }

    final updated =
        List<PortfolioPosition>.from(positions.value);

    final existingIndex = updated.indexWhere(
      (position) =>
          position.symbol == normalizedSymbol,
    );

    final newPosition = PortfolioPosition(
      company: normalizedCompany.isEmpty
          ? normalizedSymbol
          : normalizedCompany,
      symbol: normalizedSymbol,
      quantity: quantity,
      averagePrice: averagePrice,
    );

    if (existingIndex >= 0) {
      updated[existingIndex] = newPosition;
    } else {
      updated.add(newPosition);
    }

    updated.sort(
      (first, second) =>
          first.symbol.compareTo(second.symbol),
    );

    positions.value = updated;

    await _save();
  }

  Future<void> removePosition(String symbol) async {
    final normalizedSymbol =
        symbol.trim().toUpperCase();

    final updated = positions.value
        .where(
          (position) =>
              position.symbol != normalizedSymbol,
        )
        .toList();

    positions.value = updated;

    await _save();
  }

  PortfolioPosition? findPosition(String symbol) {
    final normalizedSymbol =
        symbol.trim().toUpperCase();

    for (final position in positions.value) {
      if (position.symbol == normalizedSymbol) {
        return position;
      }
    }

    return null;
  }

  Future<void> _save() async {
    final encodedPositions = positions.value
        .map(
          (position) =>
              jsonEncode(position.toJson()),
        )
        .toList();

    await _preferences.setStringList(
      _storageKey,
      encodedPositions,
    );
  }
}