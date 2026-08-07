import 'package:flutter/material.dart';

import '../features/favorites/favorites_screen.dart';
import '../features/home/home_screen.dart';
import '../features/market/market_screen.dart';
import '../features/portfolio/portfolio_screen.dart';
import '../features/transactions/transactions_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  void _selectPage(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  List<Widget> _buildPages() {
    return [
      HomeScreen(
        onOpenMarket: () => _selectPage(1),
        onOpenPortfolio: () => _selectPage(2),
        onOpenFavorites: () => _selectPage(3),
        onOpenTransactions: () => _selectPage(4),
      ),
      const MarketScreen(),
      const PortfolioScreen(),
      const FavoritesScreen(),
      const TransactionsScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final pages = _buildPages();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 900;
        final isWideDesktop = constraints.maxWidth >= 1200;

        if (isDesktop) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  extended: isWideDesktop,
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: _selectPage,
                  backgroundColor: const Color(0xFF0F172A),
                  indicatorColor:
                      const Color(0xFF20D3C2).withValues(
                    alpha: 0.16,
                  ),
                  selectedIconTheme: const IconThemeData(
                    color: Color(0xFF20D3C2),
                  ),
                  selectedLabelTextStyle: const TextStyle(
                    color: Color(0xFF20D3C2),
                    fontWeight: FontWeight.bold,
                  ),
                  leading: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 24,
                    ),
                    child: isWideDesktop
                        ? const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.lightbulb_outline,
                                color: Color(0xFF20D3C2),
                                size: 30,
                              ),
                              SizedBox(width: 12),
                              Text(
                                'InvestMind',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          )
                        : const Icon(
                            Icons.lightbulb_outline,
                            color: Color(0xFF20D3C2),
                            size: 30,
                          ),
                  ),
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home),
                      label: Text('Главная'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.public_outlined),
                      selectedIcon: Icon(Icons.public),
                      label: Text('Рынок'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(
                        Icons.account_balance_wallet_outlined,
                      ),
                      selectedIcon: Icon(
                        Icons.account_balance_wallet,
                      ),
                      label: Text('Портфель'),),
                    NavigationRailDestination(
                      icon: Icon(Icons.star_border),
                      selectedIcon: Icon(Icons.star),
                      label: Text('Избранное'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(
                        Icons.receipt_long_outlined,
                      ),
                      selectedIcon: Icon(
                        Icons.receipt_long,
                      ),
                      label: Text('История'),
                    ),
                  ],
                ),
                const VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: Color(0xFF1E293B),
                ),
                Expanded(
                  child: IndexedStack(
                    index: _selectedIndex,
                    children: pages,
                  ),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          body: IndexedStack(
            index: _selectedIndex,
            children: pages,
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: _selectPage,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Главная',
              ),
              NavigationDestination(
                icon: Icon(Icons.public_outlined),
                selectedIcon: Icon(Icons.public),
                label: 'Рынок',
              ),
              NavigationDestination(
                icon: Icon(
                  Icons.account_balance_wallet_outlined,
                ),
                selectedIcon: Icon(
                  Icons.account_balance_wallet,
                ),
                label: 'Портфель',
              ),
              NavigationDestination(
                icon: Icon(Icons.star_border),
                selectedIcon: Icon(Icons.star),
                label: 'Избранное',
              ),
              NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(
                  Icons.receipt_long,
                ),
                label: 'История',
              ),
            ],
          ),
        );
      },
    );
  }
}