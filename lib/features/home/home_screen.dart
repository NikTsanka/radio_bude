import 'package:flutter/material.dart';
import '../my_radio/my_radio_screen.dart';
import '../world_radio/world_radio_screen.dart';
import '../favorites/favorites_screen.dart';
import '../../core/services/connectivity_service.dart';
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
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const MyRadioScreen(),
      const WorldRadioScreen(),
      FavoritesScreen(
        onNavigateToWorld: () => setState(() => _selectedIndex = 1),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return DoubleBackToExit(
      onExit: () => audioHandler.stop(),
      child: Scaffold(
        body: IndexedStack(index: _selectedIndex, children: _screens),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _OfflineBanner(),
            ClipRect(
              child: AnimatedAlign(
                alignment: Alignment.topCenter,
                heightFactor: _selectedIndex != 0 ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeInOut,
                child: AnimatedOpacity(
                  opacity: _selectedIndex != 0 ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: MiniPlayerBar(
                    onTap: () => setState(() => _selectedIndex = 0),
                  ),
                ),
              ),
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

class _OfflineBanner extends StatelessWidget {
  static final _conn = ConnectivityService();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _conn,
      builder: (context, _) {
        return AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: _conn.isOnline
              ? const SizedBox.shrink()
              : Material(
                  color: Colors.red[700],
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.wifi_off, color: Colors.white, size: 16),
                        SizedBox(width: 8),
                        Text(
                          'No internet connection',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }
}
