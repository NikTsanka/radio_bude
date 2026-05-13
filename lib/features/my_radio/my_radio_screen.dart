import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../main.dart';

class MyRadioScreen extends StatelessWidget {
  const MyRadioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),

                // ✓ Header
                Text(
                  Constants.radioBudeName,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'by ${Constants.radioBudeAuthor}',
                  style: TextStyle(fontSize: 16, color: Colors.grey[400]),
                ),

                const SizedBox(height: 40),

                // ✓ Album Art
                _AlbumArt(),

                const SizedBox(height: 40),

                // ✓ მიმდინარე სიმღერა (ICY metadata-დან)
                _CurrentSongDisplay(),

                const SizedBox(height: 40),

                // ✓ Play/Pause ღილაკი
                _PlayButton(),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AlbumArt extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: AspectRatio(
        aspectRatio: 1,
        child: StreamBuilder<MediaItem?>(
          stream: audioHandler.mediaItem,
          builder: (context, snapshot) {
            final artUri = snapshot.data?.artUri;

            if (artUri == null) {
              return _buildPlaceholder(context);
            }

            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: CachedNetworkImage(
                key: ValueKey(
                  artUri.toString(),
                ), // ✓ AnimatedSwitcher-ი ცარიერდება ცვლის
                imageUrl: artUri.toString(),
                fit: BoxFit.cover,
                placeholder: (_, _) => _buildPlaceholder(context),
                errorWidget: (_, _, _) => _buildPlaceholder(context),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.tertiary,
          ],
        ),
      ),
      child: const Icon(Icons.radio, size: 120, color: Colors.white),
    );
  }
}

class _CurrentSongDisplay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<String?>(
      stream: audioHandler.currentSong,
      builder: (context, snapshot) {
        final song = snapshot.data;

        return Column(
          children: [
            Text(
              'ახლა ეთერში',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              song ?? 'Connecting to stream...',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        );
      },
    );
  }
}

class _PlayButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PlaybackState>(
      stream: audioHandler.playbackState,
      builder: (context, snapshot) {
        final state = snapshot.data;
        final playing = state?.playing ?? false;
        final processingState =
            state?.processingState ?? AudioProcessingState.idle;

        final isLoading =
            processingState == AudioProcessingState.loading ||
            processingState == AudioProcessingState.buffering;

        return Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Theme.of(context).colorScheme.primary,
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.4),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: isLoading
              ? const Padding(
                  padding: EdgeInsets.all(28),
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                )
              : IconButton(
                  iconSize: 56,
                  color: Colors.white,
                  onPressed: () {
                    if (playing) {
                      audioHandler.pause();
                    } else {
                      audioHandler.play();
                    }
                  },
                  icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                ),
        );
      },
    );
  }
}
