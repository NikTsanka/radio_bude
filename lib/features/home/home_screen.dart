import 'package:flutter/material.dart';
import '../my_radio/my_radio_screen.dart';
import '../world_radio/world_radio_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  // ეს ცარიელი screens მერე ჩაანაცვლდება რეალური implementations-ით
  static const List<Widget> _screens = [
    MyRadioScreen(),
    WorldRadioScreen(),
    _PlaceholderScreen(title: 'ფავორიტები', subtitle: 'Phase 5-ში'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.radio_outlined),
            selectedIcon: Icon(Icons.radio),
            label: 'ჩემი რადიო',
          ),
          NavigationDestination(
            icon: Icon(Icons.public_outlined),
            selectedIcon: Icon(Icons.public),
            label: 'მსოფლიო',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_outline),
            selectedIcon: Icon(Icons.favorite),
            label: 'ფავორიტები',
          ),
        ],
      ),
    );
  }
}

class _PlaceholderScreen extends StatelessWidget {
  final String title;
  final String subtitle;

  const _PlaceholderScreen({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(subtitle, style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      ),
    );
  }
}
