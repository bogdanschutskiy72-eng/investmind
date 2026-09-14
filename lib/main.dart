import 'package:flutter/material.dart';

import 'app/app.dart';
import 'features/market/market_persistent_cache_service.dart';
import 'services/favorites_service.dart';
import 'services/portfolio_service.dart';
import 'services/transaction_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await FavoritesService.instance.initialize();
  await PortfolioService.instance.initialize();
  await TransactionService.instance.initialize();

  await MarketPersistentCacheService.instance.restoreAll();
  MarketPersistentCacheService.instance.startAutoSave();

  runApp(const InvestMindApp());
}
