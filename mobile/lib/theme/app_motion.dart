import 'package:flutter/material.dart';

/// Motion in the app: few, short and meaningful. Animations are used only where
/// they tell the LHW something: a new screen or step, the app opening, a wrong
/// PIN, a beat counted, a record saved. Lists, cards and headers do not move.
///
/// Every duration goes through [of], so a phone with "Remove animations" on
/// (Android accessibility) gets none, and slow phones never wait on motion.
abstract final class AppMotion {
  /// Small state changes: a dot filling, a colour, a button swapping.
  static const Duration short = Duration(milliseconds: 150);

  /// A step of a wizard, a card turning red.
  static const Duration medium = Duration(milliseconds: 250);

  /// Moving to another stage of the app (unlocked, locked).
  static const Duration long = Duration(milliseconds: 350);

  /// Things that arrive: decelerate into place.
  static const Curve enter = Curves.easeOutCubic;

  /// Things that change in place.
  static const Curve standard = Curves.easeInOutCubic;

  /// [duration], or none when the phone asks for no animations.
  static Duration of(BuildContext context, Duration duration) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false ? Duration.zero : duration;
}

/// Fades its child in (with a short slide when [offset] is given) the first time
/// it is built. Give it a new [key] to play it again, for example per wizard
/// step. Only the new content moves; the old content is gone at once, so no
/// screen is ever built twice.
class EnterTransition extends StatelessWidget {
  const EnterTransition({
    super.key,
    required this.child,
    this.offset = Offset.zero,
    this.duration = AppMotion.medium,
  });

  final Widget child;

  /// Where the child starts, in logical pixels.
  final Offset offset;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppMotion.of(context, duration),
      curve: AppMotion.enter,
      child: child,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: offset * (1 - t), child: child),
      ),
    );
  }
}
