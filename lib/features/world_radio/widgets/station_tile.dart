import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../favorites/favorites_service.dart';
import '../station_model.dart';

class StationTile extends StatelessWidget {
  final Station station;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isPlaying;

  /// თუ true — heart icon ცარიერდება არ ცარიერდება (Favorites tab-ში გვაქვს უკვე heart-ი)
  final bool hideFavoriteButton;

  const StationTile({
    super.key,
    required this.station,
    required this.onTap,
    this.onLongPress,
    this.isPlaying = false,
    this.hideFavoriteButton = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        onLongPress: onLongPress,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: theme.colorScheme.outline.withValues(alpha: 0.1),
              ),
            ),
            color: isPlaying
                ? theme.colorScheme.primary.withValues(alpha: 0.1)
                : null,
          ),
          child: Row(
            children: [
              _buildFavicon(theme),
              const SizedBox(width: 12),
              Expanded(child: _buildInfo(theme)),
              const SizedBox(width: 8),
              if (!hideFavoriteButton) _buildFavoriteButton(),
              _buildTrailing(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFavicon(ThemeData theme) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 48,
        height: 48,
        child: station.favicon.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: station.favicon,
                fit: BoxFit.cover,
                placeholder: (_, _) => _buildFallbackIcon(theme),
                errorWidget: (_, _, _) => _buildFallbackIcon(theme),
              )
            : _buildFallbackIcon(theme),
      ),
    );
  }

  Widget _buildFallbackIcon(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.7),
            theme.colorScheme.tertiary.withValues(alpha: 0.7),
          ],
        ),
      ),
      child: const Icon(Icons.radio, color: Colors.white, size: 24),
    );
  }

  Widget _buildInfo(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          station.name,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: isPlaying
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            if (station.bitrate > 0) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${station.bitrate}k',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const SizedBox(width: 5),
            ],
            Expanded(
              child: Text(
                station.description,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFavoriteButton() {
    final favService = FavoritesService();
    return AnimatedBuilder(
      animation: favService,
      builder: (context, _) {
        final isFav = favService.isFavorite(station.stationUuid);

        return IconButton(
          onPressed: () async {
            final added = await favService.toggleFavorite(station);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    added ? '💖 Added to favorites' : 'Removed from favorites',
                  ),
                  duration: const Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, animation) =>
                ScaleTransition(scale: animation, child: child),
            child: Icon(
              isFav ? Icons.favorite : Icons.favorite_outline,
              key: ValueKey(isFav),
              color: isFav
                  ? Colors.pink[300]
                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTrailing(ThemeData theme) {
    if (isPlaying) {
      return Padding(
        padding: const EdgeInsets.only(left: 8),
        child: Icon(
          Icons.graphic_eq,
          color: theme.colorScheme.primary,
          size: 24,
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
