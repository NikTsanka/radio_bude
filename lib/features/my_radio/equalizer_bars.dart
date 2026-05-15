import 'dart:math';
import 'package:flutter/material.dart';

class EqualizerBars extends StatefulWidget {
  final bool isPlaying;
  final Color? color;
  final int barCount;
  final double height;
  final double width;

  const EqualizerBars({
    super.key,
    required this.isPlaying,
    this.color,
    this.barCount = 5,
    this.height = 28,
    this.width = 32,
  });

  @override
  State<EqualizerBars> createState() => _EqualizerBarsState();
}

class _EqualizerBarsState extends State<EqualizerBars>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _animations;
  final _rng = Random();

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      widget.barCount,
      (_) => AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 350 + _rng.nextInt(350)),
      ),
    );
    _animations =
        _controllers
            .map(
              (c) => Tween<double>(begin: 0.15, end: 1.0).animate(
                CurvedAnimation(parent: c, curve: Curves.easeInOut),
              ),
            )
            .toList();

    if (widget.isPlaying) _startAll();
  }

  void _startAll() {
    for (var i = 0; i < _controllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 90), () {
        if (mounted) _controllers[i].repeat(reverse: true);
      });
    }
  }

  void _stopAll() {
    for (final c in _controllers) {
      c.stop();
      c.animateTo(0.15, duration: const Duration(milliseconds: 300));
    }
  }

  @override
  void didUpdateWidget(EqualizerBars old) {
    super.didUpdateWidget(old);
    if (widget.isPlaying != old.isPlaying) {
      widget.isPlaying ? _startAll() : _stopAll();
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    final barW = (widget.width - (widget.barCount - 1) * 3) / widget.barCount;

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(
          widget.barCount,
          (i) => AnimatedBuilder(
            animation: _animations[i],
            builder:
                (_, _) => Container(
                  width: barW,
                  height: widget.height * _animations[i].value,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(barW / 2),
                  ),
                ),
          ),
        ),
      ),
    );
  }
}
