import 'package:flutter/material.dart';

/// مجموعة انتقالات احترافية للتنقل بين الشاشات
class PremiumPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final RouteTransition transition;

  PremiumPageRoute({
    required this.page,
    this.transition = RouteTransition.slideUp,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: const Duration(milliseconds: 350),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            switch (transition) {
              case RouteTransition.slideUp:
                return _slideUp(animation, secondaryAnimation, child);
              case RouteTransition.slideRight:
                return _slideRight(animation, secondaryAnimation, child);
              case RouteTransition.fade:
                return _fade(animation, child);
              case RouteTransition.scale:
                return _scale(animation, child);
              case RouteTransition.slideFade:
                return _slideFade(animation, child);
            }
          },
        );

  static Widget _slideUp(Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    final offsetAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
    ));

    final fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: animation,
      curve: const Interval(0.0, 0.65, curve: Curves.easeOut),
    ));

    return SlideTransition(
      position: offsetAnimation,
      child: FadeTransition(
        opacity: fadeAnimation,
        child: child,
      ),
    );
  }

  static Widget _slideRight(Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    final offsetAnimation = Tween<Offset>(
      begin: const Offset(0.25, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
    ));

    final fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: animation,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    ));

    return SlideTransition(
      position: offsetAnimation,
      child: FadeTransition(
        opacity: fadeAnimation,
        child: child,
      ),
    );
  }

  static Widget _fade(Animation<double> animation, Widget child) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: animation,
        curve: Curves.easeInOut,
      ),
      child: child,
    );
  }

  static Widget _scale(Animation<double> animation, Widget child) {
    final scaleAnimation = Tween<double>(
      begin: 0.92,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
    ));

    final fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: animation,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));

    return ScaleTransition(
      scale: scaleAnimation,
      child: FadeTransition(
        opacity: fadeAnimation,
        child: child,
      ),
    );
  }

  static Widget _slideFade(Animation<double> animation, Widget child) {
    final offsetAnimation = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
    ));

    final fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: animation,
      curve: Curves.easeIn,
    ));

    return SlideTransition(
      position: offsetAnimation,
      child: FadeTransition(
        opacity: fadeAnimation,
        child: child,
      ),
    );
  }
}

enum RouteTransition {
  slideUp,
  slideRight,
  fade,
  scale,
  slideFade,
}
