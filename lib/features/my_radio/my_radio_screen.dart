import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/theme/theme_service.dart';
import '../../main.dart';
import 'equalizer_bars.dart';

class MyRadioScreen extends StatelessWidget {
  const MyRadioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const _TopBar(),
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    children: const [
                      SizedBox(height: 12),
                      _AlbumArtSection(),
                      SizedBox(height: 20),
                      _EqualizerSection(),
                      SizedBox(height: 20),
                      _SongInfo(),
                      SizedBox(height: 28),
                      _VolumeSlider(),
                      SizedBox(height: 20),
                      _PlayButton(),
                      SizedBox(height: 28),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── Theme Toggle ────────────────────────────

class _ThemeToggleButton extends StatelessWidget {
  const _ThemeToggleButton();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeService(),
      builder:
          (_, _x) => IconButton(
            icon: Icon(
              ThemeService().isDark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
            ),
            tooltip: ThemeService().isDark ? 'Light mode' : 'Dark mode',
            onPressed: ThemeService().toggle,
          ),
    );
  }
}

// ─────────────────────────── Top Bar ────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 12, 8),
      child: Row(
        children: [
          Text(
            Constants.radioBudeName,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          const _ThemeToggleButton(),
          const _SleepTimerButton(),
        ],
      ),
    );
  }
}

class _SleepTimerButton extends StatelessWidget {
  const _SleepTimerButton();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DateTime?>(
      stream: audioHandler.sleepTimerEnd,
      builder: (context, snapshot) {
        final endTime = snapshot.data;

        if (endTime != null) {
          return GestureDetector(
            onTap: () => _openSheet(context),
            child: _SleepTimerChip(endTime: endTime),
          );
        }

        return IconButton(
          icon: const Icon(Icons.bedtime_outlined),
          tooltip: 'Sleep timer',
          onPressed: () => _openSheet(context),
        );
      },
    );
  }

  void _openSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _SleepTimerSheet(),
    );
  }
}

class _SleepTimerChip extends StatefulWidget {
  final DateTime endTime;

  const _SleepTimerChip({required this.endTime});

  @override
  State<_SleepTimerChip> createState() => _SleepTimerChipState();
}

class _SleepTimerChipState extends State<_SleepTimerChip> {
  late Timer _ticker;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _update();
    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (mounted) _update();
      },
    );
  }

  void _update() {
    setState(() {
      _remaining = widget.endTime.difference(DateTime.now());
      if (_remaining.isNegative) _remaining = Duration.zero;
    });
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final m = _remaining.inMinutes;
    final s = _remaining.inSeconds % 60;
    final label = m > 0
        ? '${m}m ${s.toString().padLeft(2, '0')}s'
        : '${s}s';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.primary.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bedtime, size: 15, color: cs.primary),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: cs.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.expand_more, size: 15, color: cs.primary),
        ],
      ),
    );
  }
}

class _SleepTimerSheet extends StatelessWidget {
  const _SleepTimerSheet();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 8,
        right: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: cs.onSurface.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Sleep Timer',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          // Cancel current timer option (if active)
          StreamBuilder<DateTime?>(
            stream: audioHandler.sleepTimerEnd,
            builder: (context, snap) {
              if (snap.data == null) return const SizedBox.shrink();
              return Column(
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.stop_circle_outlined,
                      color: Colors.red,
                    ),
                    title: const Text('Cancel timer'),
                    onTap: () {
                      audioHandler.cancelSleepTimer();
                      Navigator.pop(context);
                    },
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                ],
              );
            },
          ),
          _option(context, '15 minutes', const Duration(minutes: 15)),
          _option(context, '30 minutes', const Duration(minutes: 30)),
          _option(context, '45 minutes', const Duration(minutes: 45)),
          _option(context, '1 hour', const Duration(minutes: 60)),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _option(BuildContext context, String label, Duration duration) {
    return ListTile(
      leading: const Icon(Icons.timer_outlined),
      title: Text(label),
      onTap: () {
        audioHandler.setSleepTimer(duration);
        Navigator.pop(context);
      },
    );
  }
}

// ─────────────────────────── Album Art ────────────────────────────

class _AlbumArtSection extends StatefulWidget {
  const _AlbumArtSection();

  @override
  State<_AlbumArtSection> createState() => _AlbumArtSectionState();
}

class _AlbumArtSectionState extends State<_AlbumArtSection>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowCtrl;
  late Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _glow = Tween<double>(
      begin: 8,
      end: 36,
    ).animate(CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PlaybackState>(
      stream: audioHandler.playbackState,
      builder: (context, snap) {
        final playing = snap.data?.playing ?? false;

        if (playing) {
          if (!_glowCtrl.isAnimating) _glowCtrl.repeat(reverse: true);
        } else {
          if (_glowCtrl.isAnimating) {
            _glowCtrl.stop();
            _glowCtrl.animateTo(0);
          }
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final size = (constraints.maxWidth * 0.82).clamp(200.0, 320.0);
            return Center(
              child: AnimatedBuilder(
                animation: _glow,
                builder: (_, child) {
                  return Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      boxShadow:
                          playing
                              ? [
                                  BoxShadow(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withValues(alpha: 0.45),
                                    blurRadius: _glow.value,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : [],
                    ),
                    child: child,
                  );
                },
                child: _AlbumArtImage(size: size),
              ),
            );
          },
        );
      },
    );
  }
}

class _AlbumArtImage extends StatelessWidget {
  final double size;

  const _AlbumArtImage({required this.size});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: StreamBuilder<MediaItem?>(
        stream: audioHandler.mediaItem,
        builder: (context, snapshot) {
          final artUri = snapshot.data?.artUri;

          if (artUri == null) return _placeholder(context);

          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child:
                artUri.scheme == 'asset'
                    ? Image.asset(
                        artUri.path.replaceFirst('/', ''),
                        key: ValueKey(artUri.toString()),
                        fit: BoxFit.cover,
                        width: size,
                        height: size,
                        errorBuilder: (_, _, _) => _placeholder(context),
                      )
                    : CachedNetworkImage(
                        key: ValueKey(artUri.toString()),
                        imageUrl: artUri.toString(),
                        fit: BoxFit.cover,
                        width: size,
                        height: size,
                        placeholder: (_, _) => _placeholder(context),
                        errorWidget: (_, _, _) => _placeholder(context),
                      ),
          );
        },
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    return Container(
      width: size,
      height: size,
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
      child: const Icon(Icons.radio, size: 100, color: Colors.white),
    );
  }
}

// ─────────────────────────── Equalizer ────────────────────────────

class _EqualizerSection extends StatelessWidget {
  const _EqualizerSection();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PlaybackState>(
      stream: audioHandler.playbackState,
      builder: (context, snap) {
        final state = snap.data;
        final playing = state?.playing ?? false;
        final isLoading =
            state?.processingState == AudioProcessingState.loading ||
            state?.processingState == AudioProcessingState.buffering;

        return AnimatedOpacity(
          duration: const Duration(milliseconds: 400),
          opacity: playing || isLoading ? 1.0 : 0.25,
          child: EqualizerBars(
            isPlaying: playing && !isLoading,
            height: 28,
            width: 44,
            barCount: 5,
          ),
        );
      },
    );
  }
}

// ─────────────────────────── Song Info ────────────────────────────

class _SongInfo extends StatelessWidget {
  const _SongInfo();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return StreamBuilder<String?>(
      stream: audioHandler.currentSong,
      builder: (context, snapshot) {
        final song = snapshot.data;

        return Column(
          children: [
            Text(
              'ON AIR',
              style: TextStyle(
                fontSize: 11,
                color: cs.primary,
                letterSpacing: 3,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              song ?? 'Connecting to stream...',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              Constants.radioBudeName,
              style: TextStyle(
                fontSize: 14,
                color: cs.onSurface.withValues(alpha: 0.45),
                letterSpacing: 0.5,
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────── Volume ────────────────────────────

class _VolumeSlider extends StatelessWidget {
  const _VolumeSlider();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return StreamBuilder<double>(
      stream: audioHandler.volume,
      builder: (context, snapshot) {
        final vol = snapshot.data ?? 1.0;

        return Row(
          children: [
            Icon(
              vol == 0 ? Icons.volume_off : Icons.volume_down_rounded,
              size: 20,
              color: cs.onSurface.withValues(alpha: 0.4),
            ),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 7,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 16,
                  ),
                ),
                child: Slider(
                  value: vol,
                  onChanged: audioHandler.setVolume,
                  activeColor: cs.primary,
                  inactiveColor: cs.primary.withValues(alpha: 0.2),
                ),
              ),
            ),
            Icon(
              Icons.volume_up_rounded,
              size: 20,
              color: cs.onSurface.withValues(alpha: 0.4),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────── Play Button ────────────────────────────

class _PlayButton extends StatelessWidget {
  const _PlayButton();

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
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Theme.of(context).colorScheme.primary,
            boxShadow: [
              BoxShadow(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.35),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child:
              isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    )
                  : IconButton(
                      iconSize: 48,
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
