import 'package:flutter/material.dart';
import '../my_radio/my_radio_screen.dart';
import '../world_radio/world_radio_screen.dart';
import '../favorites/favorites_screen.dart';
import 'double_back_to_exit.dart';
import 'mini_player_bar.dart';
import '../../main.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  static const List<Widget> _screens = [
    MyRadioScreen(),
    WorldRadioScreen(),
    FavoritesScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return DoubleBackToExit(
      onExit: () => audioHandler.stop(),
      child: Scaffold(
        body: IndexedStack(index: _selectedIndex, children: _screens),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_selectedIndex != 0)
              MiniPlayerBar(
                onTap: () => setState(() => _selectedIndex = 0),
              ),
            NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) {
                setState(() => _selectedIndex = index);
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.radio_outlined),
                  selectedIcon: Icon(Icons.radio),
                  label: 'My Radio',
                ),
                NavigationDestination(
                  icon: Icon(Icons.public_outlined),
                  selectedIcon: Icon(Icons.public),
                  label: 'World',
                ),
                NavigationDestination(
                  icon: Icon(Icons.favorite_outline),
                  selectedIcon: Icon(Icons.favorite),
                  label: 'Favorites',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
