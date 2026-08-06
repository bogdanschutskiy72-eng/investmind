import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TransactionType {
  buy,
  sell,
}

class PortfolioTransaction {
  final String id;
  final String company;
  final String symbol;
  final TransactionType type;
  final double quantity;
  final double price;
  final DateTime createdAt;
  final double? realizedProfit;

  const PortfolioTransaction({
    required this.id,
    required this.company,
    required this.symbol,
    required this.type,
    required this.quantity,
    required this.price,
    required this.createdAt,
    this.realizedProfit,
  });

  double get totalAmount => quantity * price;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'company': company,
      'symbol': symbol,
      'type': type.name,
      'quantity': quantity,
      'price': price,
      'createdAt': createdAt.toIso8601String(),
      'realizedProfit': realizedProfit,
    };
  }

  factory PortfolioTransaction.fromJson(
    Map<String, dynamic> json,
  ) {
    final typeName = json['type']?.toString();

    return PortfolioTransaction(
      id: json['id']?.toString() ?? '',
      company: json['company']?.toString() ?? '',
      symbol: json['symbol']?.toString() ?? '',
      type: typeName == TransactionType.sell.name
          ? TransactionType.sell
          : TransactionType.buy,
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
      price: (json['price'] as num?)?.toDouble() ?? 0,
      createdAt: DateTime.tryParse(
            json['createdAt']?.toString() ?? '',
          ) ??
          DateTime.now(),
      realizedProfit:
          (json['realizedProfit'] as num?)?.toDouble(),
    );
  }
}

class TransactionService {
  TransactionService._();

  static final TransactionService instance =
      TransactionService._();

  static const String _storageKey =
      'portfolio_transactions';

  final ValueNotifier<List<PortfolioTransaction>>
      transactions =
      ValueNotifier<List<PortfolioTransaction>>(
    <PortfolioTransaction>[],
  );

  late SharedPreferences _preferences;

  Future<void> initialize() async {
    _preferences = await SharedPreferences.getInstance();

    final savedData =
        _preferences.getStringList(_storageKey) ??
            <String>[];

    final loadedTransactions =
        <PortfolioTransaction>[];

    for (final item in savedData) {
      try {
        final decoded = jsonDecode(item);

        if (decoded is Map<String, dynamic>) {
          final transaction =
              PortfolioTransaction.fromJson(decoded);

          if (transaction.id.isNotEmpty &&
              transaction.symbol.isNotEmpty &&
              transaction.quantity > 0 &&
              transaction.price > 0) {
            loadedTransactions.add(transaction);
          }
        }
      } catch (_) {
        // Повреждённую запись пропускаем.
      }
    }

    loadedTransactions.sort(
      (first, second) =>
          second.createdAt.compareTo(first.createdAt),
    );

    transactions.value = loadedTransactions;
  }

  Future<void> addTransaction({
    required String company,
    required String symbol,
    required TransactionType type,
    required double quantity,
    required double price,
    double? realizedProfit,
  }) async {
    final normalizedSymbol =
        symbol.trim().toUpperCase();

    if (normalizedSymbol.isEmpty ||
        quantity <= 0 ||
        price <= 0) {
      throw ArgumentError(
        'Проверь тикер, количество и цену.',
      );
    }

    final transaction = PortfolioTransaction(
      id: DateTime.now()
          .microsecondsSinceEpoch
          .toString(),
      company: company.trim().isEmpty
          ? normalizedSymbol
          : company.trim(),
      symbol: normalizedSymbol,
      type: type,
      quantity: quantity,
      price: price,
      createdAt: DateTime.now(),
      realizedProfit: realizedProfit,
    );

    final updated =
        List<PortfolioTransaction>.from(
      transactions.value,
    );

    updated.insert(0, transaction);transactions.value = updated;

    await _save();
  }

  Future<void> removeTransaction(
    String transactionId,
  ) async {
    final updated = transactions.value
        .where(
          (transaction) =>
              transaction.id != transactionId,
        )
        .toList();

    transactions.value = updated;

    await _save();
  }

  Future<void> clearTransactions() async {
    transactions.value = <PortfolioTransaction>[];
    await _save();
  }

  Future<void> _save() async {
    final encodedTransactions =
        transactions.value
            .map(
              (transaction) => jsonEncode(
                transaction.toJson(),
              ),
            )
            .toList();

    await _preferences.setStringList(
      _storageKey,
      encodedTransactions,
    );
  }
}