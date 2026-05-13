import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../station_model.dart';

class StationTile extends StatelessWidget {
  final Station station;
  final VoidCallback onTap;
  final bool isPlaying;

  const StationTile({
    super.key,
    required this.station,
    required this.onTap,
    this.isPlaying = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: theme.colorScheme.outline.withOpacity(0.1),
              ),
            ),
            color: isPlaying
                ? theme.colorScheme.primary.withOpacity(0.1)
                : null,
          ),
          child: Row(
            children: [
              _buildFavicon(theme),
              const SizedBox(width: 12),
              Expanded(child: _buildInfo(theme)),
              const SizedBox(width: 8),
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
                placeholder: (_, __) => _buildFallbackIcon(theme),
                errorWidget: (_, __, ___) => _buildFallbackIcon(theme),
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
            theme.colorScheme.primary.withOpacity(0.7),
            theme.colorScheme.tertiary.withOpacity(0.7),
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
        Text(
          station.description,
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildTrailing(ThemeData theme) {
    if (isPlaying) {
      return Icon(Icons.graphic_eq, color: theme.colorScheme.primary, size: 24);
    }

    return Icon(
      Icons.play_circle_outline,
      color: theme.colorScheme.onSurface.withOpacity(0.4),
      size: 28,
    );
  }
}
