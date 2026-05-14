import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import '../../main.dart';
import '../world_radio/station_model.dart';
import '../world_radio/widgets/station_tile.dart';
import 'favorites_service.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: AnimatedBuilder(
          animation: FavoritesService(),
          builder: (context, _) {
            final favorites = FavoritesService().favorites;

            return Column(
              children: [
                _buildHeader(context, favorites.length),
                const Divider(height: 1),
                Expanded(
                  child: favorites.isEmpty
                      ? _buildEmptyState(context)
                      : _buildList(context, favorites),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Favorites',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          if (count > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                '$count',
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              ),
            ),
          if (count > 0)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) => _handleMenuAction(context, value),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'clear',
                  child: Row(
                    children: [
                      Icon(Icons.delete_sweep_outlined, size: 20),
                      SizedBox(width: 12),
                      Text('Clear all'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_outline, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 24),
            Text(
              'No favorites yet',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(color: Colors.grey[400]),
            ),
            const SizedBox(height: 8),
            Text(
              'Add stations from the "World" tab.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, List<Station> favorites) {
    return StreamBuilder<MediaItem?>(
      stream: audioHandler.mediaItem,
      builder: (context, snapshot) {
        final currentlyPlayingUrl = snapshot.data?.id;

        return ReorderableListView.builder(
          itemCount: favorites.length,
          onReorder: (oldIndex, newIndex) {
            FavoritesService().reorder(oldIndex, newIndex);
          },
          itemBuilder: (context, index) {
            final station = favorites[index];

            return Dismissible(
              key: ValueKey(station.stationUuid),
              direction: DismissDirection.endToStart,
              background: Container(
                color: Colors.red[700],
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 24),
                child: const Icon(
                  Icons.delete_outline,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              onDismissed: (_) {
                FavoritesService().remove(station.stationUuid);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${station.name} removed'),
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: StationTile(
                station: station,
                isPlaying: station.url == currentlyPlayingUrl,
                hideFavoriteButton: true,
                onTap: () => _playStation(context, station),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _playStation(BuildContext context, Station station) async {
    await audioHandler.playStation(
      url: station.url,
      name: station.name,
      country: station.country,
      favicon: station.favicon,
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🎵 ${station.name}'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleMenuAction(BuildContext context, String action) async {
    if (action == 'clear') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Clear all?'),
          content: const Text(
            'All favorites will be removed. This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton.tonal(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red[700],
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        await FavoritesService().clearAll();
      }
    }
  }
}
