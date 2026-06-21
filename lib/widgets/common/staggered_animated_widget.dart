import 'package:flutter/material.dart';

class StaggeredAnimatedWidget extends StatefulWidget {
  final Widget child;
  final int index;
  final String listId;
  final Duration delay;
  final Duration duration;
  final Axis direction;
  final double offset;

  const StaggeredAnimatedWidget({
    super.key,
    required this.child,
    required this.index,
    required this.listId,
    this.delay = const Duration(milliseconds: 60),
    this.duration = const Duration(milliseconds: 250),
    this.direction = Axis.vertical,
    this.offset = 30.0,
  });

  @override
  State<StaggeredAnimatedWidget> createState() =>
      _StaggeredAnimatedWidgetState();
}

class _StaggeredAnimatedWidgetState extends State<StaggeredAnimatedWidget>
    with SingleTickerProviderStateMixin {
  static final Set<String> _animatedItems = {};

  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: widget.direction == Axis.vertical
          ? Offset(0, widget.offset / 100)
          : Offset(widget.offset / 100, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _startAnimation();
  }

  void _startAnimation() {
    final itemKey = '${widget.listId}-${widget.index}';

    // If already animated, show immediately
    if (_animatedItems.contains(itemKey)) {
      _controller.value = 1.0;
      return;
    }

    // Only stagger the first 4 visible items for a nice initial impression.
    // Everything beyond that animates immediately with no delay —
    // this eliminates the visible gap when scrolling fast.
    if (widget.index > 3) {
      _controller.forward();
      _animatedItems.add(itemKey);
      return;
    }

    final startDelay = widget.delay * widget.index;
    Future.delayed(startDelay, () {
      if (mounted) {
        _controller.forward();
        _animatedItems.add(itemKey);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacityAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}
