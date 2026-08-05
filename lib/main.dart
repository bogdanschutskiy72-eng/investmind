import 'package:flutter/material.dart';

import 'app/app.dart';
import 'services/favorites_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await FavoritesService.instance.initialize();

  runApp(const InvestMindApp());
}