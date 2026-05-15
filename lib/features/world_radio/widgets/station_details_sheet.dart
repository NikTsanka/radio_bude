import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../station_model.dart';

class StationDetailsSheet extends StatelessWidget {
  final Station station;

  const StationDetailsSheet({super.key, required this.station});

  /// Returns the station if "Play" was tapped, otherwise null.
  static Future<Station?> show(BuildContext context, Station station) {
    return showModalBottomSheet<Station>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StationDetailsSheet(station: station),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header: favicon + name + country
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 64,
                    height: 64,
                    child: station.favicon.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: station.favicon,
                            fit: BoxFit.cover,
                            errorWidget: (_, _, _) => _fallback(cs),
                          )
                        : _fallback(cs),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        station.name,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (station.country.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          station.country,
                          style: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.55),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          const Divider(indent: 20, endIndent: 20, height: 1),
          const SizedBox(height: 16),

          // Info badges
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (station.codec.isNotEmpty)
                  _InfoChip(
                    icon: Icons.audiotrack,
                    label: station.codec.toUpperCase(),
                    color: cs.primary,
                  ),
                if (station.bitrate > 0)
                  _InfoChip(
                    icon: Icons.speed,
                    label: '${station.bitrate} kbps',
                    color: cs.secondary,
                  ),
                if (station.language.isNotEmpty)
                  _InfoChip(
                    icon: Icons.translate,
                    label: _capitalize(station.language),
                    color: cs.tertiary,
                  ),
                if (station.votes > 0)
                  _InfoChip(
                    icon: Icons.thumb_up_outlined,
                    label: '${station.votes}',
                    color: cs.onSurface,
                  ),
                if (station.clickCount > 0)
                  _InfoChip(
                    icon: Icons.headphones,
                    label: '${station.clickCount} listeners',
                    color: cs.onSurface,
                  ),
              ],
            ),
          ),

          // Genre tags
          if (station.tags.isNotEmpty) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'GENRES',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.45),
                  letterSpacing: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: station.tags.take(8).length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (_, i) => Chip(
                  label: Text(
                    station.tags[i],
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSecondaryContainer,
                    ),
                  ),
                  backgroundColor: cs.secondaryContainer,
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Play button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.pop(context, station),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Play Station'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallback(ColorScheme cs) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cs.primary.withValues(alpha: 0.7),
            cs.tertiary.withValues(alpha: 0.7),
          ],
        ),
      ),
      child: const Icon(Icons.radio, color: Colors.white, size: 32),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: cs.onSurface.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}
