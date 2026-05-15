import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:marquee/marquee.dart';
import 'package:palette_generator/palette_generator.dart';
import '../../core/constants.dart';
import '../../core/theme/theme_service.dart';
import '../../main.dart';
import 'equalizer_bars.dart';

class MyRadioScreen extends StatefulWidget {
  const MyRadioScreen({super.key});

  @override
  State<MyRadioScreen> createState() => _MyRadioScreenState();
}

class _MyRadioScreenState extends State<MyRadioScreen> {
  Color? _paletteColor;
  StreamSubscription<MediaItem?>? _mediaSub;
  Uri? _lastArtUri;

  @override
  void initState() {
    super.initState();
    _mediaSub = audioHandler.mediaItem.listen(_onMediaItemChanged);
  }

  @override
  void dispose() {
    _mediaSub?.cancel();
    super.dispose();
  }

  void _onMediaItemChanged(MediaItem? item) {
    final artUri = item?.artUri;
    if (artUri == null || artUri == _lastArtUri) return;
    _lastArtUri = artUri;
    _extractPalette(artUri);
  }

  Future<void> _extractPalette(Uri artUri) async {
    try {
      final ImageProvider provider = artUri.scheme == 'asset'
          ? AssetImage(artUri.path.replaceFirst('/', ''))
          : CachedNetworkImageProvider(artUri.toString());
      final palette = await PaletteGenerator.fromImageProvider(
        provider,
        maximumColorCount: 8,
      );
      final color = palette.vibrantColor?.color ??
          palette.mutedColor?.color ??
          palette.dominantColor?.color;
      if (color != null && mounted) setState(() => _paletteColor = color);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    final accentColor = _paletteColor ?? Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: Stack(
        children: [
          // Palette-driven ambient background
          Positioned.fill(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeInOut,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.6),
                  radius: 1.3,
                  colors: [
                    accentColor.withValues(
                        alpha: _paletteColor != null ? 0.20 : 0.06),
                    scaffoldBg,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
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
        ],
      ),
    );
  }
}

// ─────────────────────────── Theme Toggle ────────────────────────────

class _ThemeToggleButton extends StatelessWidget {
  const _ThemeToggleButton();

  static final _theme = ThemeService();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _theme,
      builder: (context, _) => IconButton(
            icon: Icon(
              _theme.isDark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
            ),
            tooltip: _theme.isDark ? 'Light mode' : 'Dark mode',
            onPressed: _theme.toggle,
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
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Custom...'),
            onTap: () => _openCustomPicker(context),
          ),
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

  Future<void> _openCustomPicker(BuildContext context) async {
    final controller = TextEditingController();
    final minutes = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Custom timer'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Minutes',
            suffixText: 'min',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(controller.text.trim());
              Navigator.pop(ctx, value);
            },
            child: const Text('Set'),
          ),
        ],
      ),
    );

    if (minutes != null && minutes > 0 && context.mounted) {
      audioHandler.setSleepTimer(Duration(minutes: minutes));
      Navigator.pop(context);
    }
  }
}

// ─────────────────────────── Album Art (Vinyl) ────────────────────────────

class _AlbumArtSection extends StatefulWidget {
  const _AlbumArtSection();

  @override
  State<_AlbumArtSection> createState() => _AlbumArtSectionState();
}

class _AlbumArtSectionState extends State<_AlbumArtSection>
    with TickerProviderStateMixin {
  late AnimationController _glowCtrl;
  late AnimationController _rotationCtrl;
  late Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _glow = Tween<double>(begin: 12, end: 42).animate(
      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut),
    );
    _rotationCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    );
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    _rotationCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return StreamBuilder<PlaybackState>(
      stream: audioHandler.playbackState,
      builder: (context, snap) {
        final playing = snap.data?.playing ?? false;

        if (playing) {
          if (!_glowCtrl.isAnimating) _glowCtrl.repeat(reverse: true);
          if (!_rotationCtrl.isAnimating) _rotationCtrl.repeat();
        } else {
          if (_glowCtrl.isAnimating) {
            _glowCtrl.stop();
            _glowCtrl.animateTo(0);
          }
          if (_rotationCtrl.isAnimating) _rotationCtrl.stop();
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final size = (constraints.maxWidth * 0.82).clamp(200.0, 320.0);
            return Center(
              child: AnimatedBuilder(
                animation: _glow,
                builder: (_, child) => Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: playing
                        ? [
                            BoxShadow(
                              color: cs.primary.withValues(alpha: 0.50),
                              blurRadius: _glow.value,
                              spreadRadius: 4,
                            ),
                          ]
                        : [],
                  ),
                  child: child,
                ),
                child: RotationTransition(
                  turns: _rotationCtrl,
                  child: _VinylDisk(size: size),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ─── Vinyl disk widget ───────────────────────────────────────────────────────

class _VinylDisk extends StatelessWidget {
  final double size;
  const _VinylDisk({required this.size});

  @override
  Widget build(BuildContext context) {
    final labelSize = size * 0.62;

    return Stack(
      alignment: Alignment.center,
      children: [
        // Vinyl body
        Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFF141414),
          ),
        ),
        // Groove rings
        SizedBox(
          width: size,
          height: size,
          child: CustomPaint(painter: _VinylGroovesPainter()),
        ),
        // Sheen highlight
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              center: const Alignment(-0.3, -0.45),
              radius: 0.85,
              colors: [
                Colors.white.withValues(alpha: 0.07),
                Colors.transparent,
              ],
            ),
          ),
        ),
        // Album art label
        ClipOval(
          child: _AlbumArtImage(size: labelSize),
        ),
        // Center spindle hole
        Container(
          width: 13,
          height: 13,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF080808),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 1,
            ),
          ),
        ),
      ],
    );
  }
}

class _VinylGroovesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2 - 2;
    final innerRadius = size.width * 0.31; // matches label radius

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;

    double r = maxRadius;
    int i = 0;
    while (r > innerRadius) {
      paint.color = Colors.white.withValues(alpha: i.isEven ? 0.05 : 0.02);
      canvas.drawCircle(center, r, paint);
      r -= 4.5;
      i++;
    }
  }

  @override
  bool shouldRepaint(_VinylGroovesPainter old) => false;
}

// ─── Album art image (inner label content) ──────────────────────────────────

class _AlbumArtImage extends StatelessWidget {
  final double size;
  const _AlbumArtImage({required this.size});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MediaItem?>(
      stream: audioHandler.mediaItem,
      builder: (context, snapshot) {
        final artUri = snapshot.data?.artUri;
        if (artUri == null) return _placeholder(context);

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: artUri.scheme == 'asset'
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
    );
  }

  Widget _placeholder(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cs.primary, cs.tertiary],
        ),
      ),
      child: const Icon(Icons.radio, size: 64, color: Colors.white),
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

class _OnAirDot extends StatefulWidget {
  const _OnAirDot();

  @override
  State<_OnAirDot> createState() => _OnAirDotState();
}

class _OnAirDotState extends State<_OnAirDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) => Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.red.withValues(alpha: 0.4 + _ctrl.value * 0.6),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withValues(alpha: _ctrl.value * 0.4),
              blurRadius: 4,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }
}

class _SongInfo extends StatelessWidget {
  const _SongInfo();

  static const _songStyle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  Widget _buildSongTitle(BuildContext context, String text) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tp = TextPainter(
          text: TextSpan(text: text, style: _songStyle),
          maxLines: 1,
          textDirection: TextDirection.ltr,
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: constraints.maxWidth);

        if (tp.didExceedMaxLines) {
          return SizedBox(
            height: 28,
            child: Marquee(
              text: text,
              style: _songStyle,
              blankSpace: 48,
              velocity: 40,
              startAfter: const Duration(seconds: 2),
              pauseAfterRound: const Duration(seconds: 3),
            ),
          );
        }
        return Text(text, style: _songStyle, textAlign: TextAlign.center);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return StreamBuilder<String?>(
      stream: audioHandler.currentSong,
      builder: (context, snapshot) {
        final song = snapshot.data;

        return Column(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _OnAirDot(),
                const SizedBox(width: 7),
                Text(
                  'ON AIR',
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.primary,
                    letterSpacing: 3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _buildSongTitle(context, song ?? 'Connecting to stream...'),
            const SizedBox(height: 6),
            StreamBuilder<MediaItem?>(
              stream: audioHandler.mediaItem,
              builder: (context, snap) {
                final name = snap.data?.title;
                return Text(
                  name ?? Constants.radioBudeName,
                  style: TextStyle(
                    fontSize: 14,
                    color: cs.onSurface.withValues(alpha: 0.45),
                    letterSpacing: 0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                );
              },
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

// ─────────────────────────── Play Button (with pulse ring) ────────────────────────────

class _PlayButton extends StatefulWidget {
  const _PlayButton();

  @override
  State<_PlayButton> createState() => _PlayButtonState();
}

class _PlayButtonState extends State<_PlayButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseScale;
  late Animation<double> _pulseOpacity;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _pulseScale = Tween<double>(begin: 1.0, end: 1.6).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOut),
    );
    _pulseOpacity = Tween<double>(begin: 0.6, end: 0.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

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

        if (playing && !isLoading) {
          if (!_pulseCtrl.isAnimating) _pulseCtrl.repeat();
        } else {
          if (_pulseCtrl.isAnimating) {
            _pulseCtrl.stop();
            _pulseCtrl.reset();
          }
        }

        return AnimatedBuilder(
          animation: _pulseCtrl,
          builder: (context, child) {
            return SizedBox(
              width: 140,
              height: 140,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (playing && !isLoading)
                    Container(
                      width: 80 * _pulseScale.value,
                      height: 80 * _pulseScale.value,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: cs.primary.withValues(
                              alpha: _pulseOpacity.value),
                          width: 2.5,
                        ),
                      ),
                    ),
                  child!,
                ],
              ),
            );
          },
          child: _ButtonBody(cs: cs, playing: playing, isLoading: isLoading),
        );
      },
    );
  }
}

class _ButtonBody extends StatelessWidget {
  final ColorScheme cs;
  final bool playing;
  final bool isLoading;

  const _ButtonBody({
    required this.cs,
    required this.playing,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: cs.primary,
        boxShadow: [
          BoxShadow(
            color: cs.primary.withValues(alpha: 0.40),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: isLoading
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
                HapticFeedback.lightImpact();
                if (playing) {
                  audioHandler.pause();
                } else {
                  audioHandler.play();
                }
              },
              icon: Icon(playing ? Icons.pause : Icons.play_arrow),
            ),
    );
  }
}
