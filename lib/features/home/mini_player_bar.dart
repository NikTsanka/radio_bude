import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../main.dart';
import '../my_radio/equalizer_bars.dart';

class MiniPlayerBar extends StatelessWidget {
  final VoidCallback onTap;

  const MiniPlayerBar({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PlaybackState>(
      stream: audioHandler.playbackState,
      builder: (context, playbackSnapshot) {
        final state = playbackSnapshot.data;
        final processingState =
            state?.processingState ?? AudioProcessingState.idle;

        if (processingState == AudioProcessingState.idle) {
          return const SizedBox.shrink();
        }

        return StreamBuilder<MediaItem?>(
          stream: audioHandler.mediaItem,
          builder: (context, mediaSnapshot) {
            final item = mediaSnapshot.data;
            if (item == null) return const SizedBox.shrink();

            final playing = state?.playing ?? false;
            final isLoading =
                processingState == AudioProcessingState.loading ||
                processingState == AudioProcessingState.buffering;

            return _MiniPlayerContent(
              item: item,
              playing: playing,
              isLoading: isLoading,
              onTap: onTap,
            );
          },
        );
      },
    );
  }
}

class _MiniPlayerContent extends StatelessWidget {
  final MediaItem item;
  final bool playing;
  final bool isLoading;
  final VoidCallback onTap;

  const _MiniPlayerContent({
    required this.item,
    required this.playing,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 68,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          border: Border(
            top: BorderSide(
              color: colorScheme.outline.withValues(alpha: 0.15),
            ),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            _Artwork(item: item, playing: playing),
            const SizedBox(width: 12),
            Expanded(child: _TrackInfo(item: item)),
            const SizedBox(width: 8),
            _PlayPauseButton(playing: playing, isLoading: isLoading),
          ],
        ),
      ),
    );
  }
}

class _Artwork extends StatelessWidget {
  final MediaItem item;
  final bool playing;

  const _Artwork({required this.item, required this.playing});

  @override
  Widget build(BuildContext context) {
    final artUri = item.artUri;

    Widget image;
    if (artUri == null) {
      image = _placeholder(context);
    } else if (artUri.scheme == 'asset') {
      image = Image.asset(
        artUri.path.replaceFirst('/', ''),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _placeholder(context),
      );
    } else {
      image = CachedNetworkImage(
        imageUrl: artUri.toString(),
        fit: BoxFit.cover,
        placeholder: (_, _) => _placeholder(context),
        errorWidget: (_, _, _) => _placeholder(context),
      );
    }

    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(width: 44, height: 44, child: image),
          ),
          if (playing)
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: EqualizerBars(
                  isPlaying: true,
                  height: 18,
                  width: 28,
                  barCount: 3,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary, cs.tertiary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.radio, size: 22, color: Colors.white),
    );
  }
}

class _TrackInfo extends StatelessWidget {
  final MediaItem item;

  const _TrackInfo({required this.item});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return StreamBuilder<String?>(
      stream: audioHandler.currentSong,
      builder: (context, snapshot) {
        final song = snapshot.data;
        final primaryText = song ?? item.title;
        final secondaryText = item.album ?? '';

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              primaryText,
              style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (secondaryText.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                secondaryText,
                style: tt.bodySmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.55),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        );
      },
    );
  }
}

class _PlayPauseButton extends StatelessWidget {
  final bool playing;
  final bool isLoading;

  const _PlayPauseButton({required this.playing, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return SizedBox(
        width: 40,
        height: 40,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );
    }

    return IconButton(
      iconSize: 36,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      onPressed: () {
        HapticFeedback.lightImpact();
        if (playing) {
          audioHandler.pause();
        } else {
          audioHandler.play();
        }
      },
      icon: Icon(
        playing ? Icons.pause_circle_filled : Icons.play_circle_filled,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}
