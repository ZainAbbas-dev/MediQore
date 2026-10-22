import 'package:flutter/material.dart';

/// Motion in the app: light, short and calm, so low-end phones never lag and
/// the battery is spared. Three kinds only:
///
/// - screen changes fade in (high contrast: the new screen is opaque and
///   arrives over the old one, which does not move);
/// - forms (registration, visit, pulse counter) and bottom sheets slide up
///   from the bottom edge, like a sheet;
/// - a card that opens a record (a woman in the list or a recent visit)
///   expands into the new screen (a container morph: the card's outline grows
///   to fill the screen while the screen fades in).
///
/// Every duration is 150–250 ms with a linear or ease-out curve; nothing is
/// 3D, parallax, springy or decorative. Every duration goes through [of], so a
/// phone with "Remove animations" on (Android accessibility) gets none.
abstract final class AppMotion {
  /// Small changes in place: a dot filling, a colour, a button swapping.
  static const Duration short = Duration(milliseconds: 150);

  /// A screen fading in, a wizard step changing.
  static const Duration medium = Duration(milliseconds: 200);

  /// A form or bottom sheet sliding up, a card expanding into a screen.
  static const Duration long = Duration(milliseconds: 250);

  /// Things that arrive: a subtle ease-out, fast at first so it feels instant.
  static const Curve enter = Curves.easeOut;

  /// Things that change in place (colours, progress).
  static const Curve standard = Curves.linear;

  /// Bottom sheets: slide up in 250 ms, down in 200 ms.
  static const AnimationStyle sheet = AnimationStyle(
    duration: long,
    reverseDuration: medium,
    curve: enter,
    reverseCurve: Curves.easeIn,
  );

  /// [duration], or none when the phone asks for no animations.
  static Duration of(BuildContext context, Duration duration) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false ? Duration.zero : duration;
}

/// Fades its child in the first time it is built. Give it a new [key] to play
/// it again, for example per wizard step. Only the new content moves; the old
/// content is gone at once, so no screen is ever built twice.
class EnterTransition extends StatelessWidget {
  const EnterTransition({super.key, required this.child, this.duration = AppMotion.medium});

  final Widget child;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppMotion.of(context, duration),
      curve: AppMotion.enter,
      child: child,
      builder: (context, t, child) => Opacity(opacity: t, child: child),
    );
  }
}

// "Remove animations" is on: screens change at once.
bool _still(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// The theme's page transition (`AppTheme`): the new screen fades in over the
/// old one in 200 ms; going back fades it out. The old screen stays still.
class FadePageTransitionsBuilder extends PageTransitionsBuilder {
  const FadePageTransitionsBuilder();

  @override
  Duration get transitionDuration => AppMotion.medium;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (_still(context)) return child;
    return FadeTransition(opacity: CurvedAnimation(parent: animation, curve: AppMotion.enter), child: child);
  }
}

/// How a screen opens: [AppRoutes.screen] fades, [AppRoutes.form] slides up
/// like a sheet, [AppRoutes.fromCard] expands from the card that was tapped.
abstract final class AppRoutes {
  /// Another screen: the theme's fade.
  static Route<T> screen<T>(Widget page) => MaterialPageRoute<T>(builder: (_) => page);

  /// A form: slides up from the bottom edge in 250 ms (200 ms back down).
  static Route<T> form<T>(Widget page) => _SlideUpRoute<T>(page);

  /// A record opened from a card: the card's outline grows into the screen.
  /// [card] is the tapped card's context; without a size it simply fades.
  static Route<T> fromCard<T>(BuildContext card, Widget page) {
    final box = card.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return screen(page);
    return _ContainerMorphRoute<T>(page, box.localToGlobal(Offset.zero) & box.size);
  }
}

class _SlideUpRoute<T> extends PageRoute<T> {
  _SlideUpRoute(this.page);

  final Widget page;

  @override
  Duration get transitionDuration => AppMotion.long;

  @override
  Duration get reverseTransitionDuration => AppMotion.medium;

  @override
  bool get maintainState => true;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) => page;

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    if (_still(context)) return child;
    final curved = CurvedAnimation(parent: animation, curve: AppMotion.enter, reverseCurve: Curves.easeIn);
    return SlideTransition(
      position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(curved),
      child: child,
    );
  }
}

class _ContainerMorphRoute<T> extends PageRoute<T> {
  _ContainerMorphRoute(this.page, this.from);

  final Widget page;

  /// The tapped card, in screen coordinates.
  final Rect from;

  /// The cards' corner radius (`AppTheme`), which becomes the screen's square corners.
  static const double _cardRadius = 20;

  @override
  Duration get transitionDuration => AppMotion.long;

  @override
  Duration get reverseTransitionDuration => AppMotion.medium;

  @override
  bool get maintainState => true;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) => page;

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    if (_still(context)) return child;
    final curved = CurvedAnimation(parent: animation, curve: AppMotion.enter, reverseCurve: Curves.easeIn);
    // The screen fades in while the outline is already half grown.
    final content = CurvedAnimation(parent: animation, curve: const Interval(0.3, 1));
    final surface = Theme.of(context).cardColor;
    return AnimatedBuilder(
      animation: curved,
      child: FadeTransition(opacity: content, child: child),
      builder: (context, child) {
        if (curved.value >= 1) return child!;
        final size = MediaQuery.sizeOf(context);
        final rect = Rect.lerp(from, Offset.zero & size, curved.value)!;
        // The screen is laid out at its full size and only clipped, never squeezed.
        return ClipRRect(
          clipper: _RectClipper(rect, Radius.circular(_cardRadius * (1 - curved.value))),
          child: ColoredBox(color: surface, child: child),
        );
      },
    );
  }
}

class _RectClipper extends CustomClipper<RRect> {
  _RectClipper(this.rect, this.radius);

  final Rect rect;
  final Radius radius;

  @override
  RRect getClip(Size size) => RRect.fromRectAndRadius(rect, radius);

  @override
  bool shouldReclip(_RectClipper oldClipper) => oldClipper.rect != rect || oldClipper.radius != radius;
}
