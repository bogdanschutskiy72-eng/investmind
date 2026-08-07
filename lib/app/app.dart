import 'package:flutter/material.dart';

import 'app_shell.dart';

class InvestMindApp extends StatelessWidget {
  const InvestMindApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'InvestMind',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF111827),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF20D3C2),
          brightness: Brightness.dark,
        ),
      ),
      home: const AppShell(),
    );
  }
}