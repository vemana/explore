import 'package:common_event/api.dart';
import 'package:flutter/widgets.dart';

import 'rebuild_on_event.dart';

/// Triggers an animation - specified by [animSpec] - that rebuilds according to [fn] when
/// [toGuard]'s state of interest - specified by [valueProvider] - changes.
///
/// When [toGuard] changes but [valueProvider] does not, the animation continues (or stays
/// completed) uninterrupted. When both change, the animation assumes the correct direction from the
/// current animation value. That is, if the animation runs for 10 secs and the value changes at 3
/// secs, the animation reverses its direction starting at 3 as opposed to snapping to 10 and then
/// reversing. This gives a more fluid effect; a running animation can be reversed from where it
/// currently is without it first needing to snap all the way to its destination. So, a drawer that
/// is opening slowly can be closed and the drawer starts closing from where it is right now.
///
/// The type parameter `<T>` indicates the animation value. Often it will just be double, but when
/// determining flex parameters, it can be int. It can also be Color, Align etc each of which have
/// lerps defined on them and hence Tweens.
///
/// If you are just interested in animating a single property like color, use something like
/// ```dart
/// animateBool(myObject,
///     object.isVisible,
///     AnimationSpec<Color>()
///       ..setDurationSecs(1)
///       ..transform(CurveTween(curv: Curves.easeInExpo))
///       ..transformLast(ColorTween(begin: Colors.black, end: Colors.white)), (color) {
///       // the variable color has the current animation value for Color.
///       return someWidget(color);
///     }
/// );
/// ```
///
/// For something like pixels, use an int for the type parameter, like so:
///
/// ```dart
/// animateBool(myObject,
///     object.isVisible,
///     AnimationSpec<int>()
///       ..setDurationSecs(1)
///       ..transform(CurveTween(curv: Curves.easeInExpo))
///       ..transformLast(IntTween(begin: 0, end: 500)), (px) {
///         // the variable px has the current animation value for pixels.
///         return someWidget(px);
///       }
/// );
/// ```
///
Widget animateBool<T>(FiresEvents toGuard, bool Function() valueProvider,
    AnimationSpec<T> animSpec, Widget Function(T) fn) {
  return guard(toGuard, () {
    return _AnimateOnEventWidget(
      eventBus: toGuard.eventBus,
      eventsToRebuildOn: [toGuard.eventIdOnUpdate],
      builder: fn,
      animSpec: animSpec,
      valueProvider: valueProvider,
    );
  });
}

/// Specifies the animation parameters.
///
/// Idiomatic usage: `[durationSecs | durationMillis]? transform* transformLast?`
///
/// That is, for idiomatic usage, set the duration, call a bunch of transforms and optionally call
/// a `transformLast` which can transform to a non-double value.
///
/// The animation value is obtained as `tLast(t3(t2(t1(x))))` where t1, t2, t3 are the calls to
/// `transform` in order. tLast represents `transformLast`. If no `transformLast` is specified,
/// identity is implied for it.
///
/// Typical values for transforms will be like `CurveTween(curve: Curves.easeInExpo)` which
/// transform a domain `[0, 1]`. Note that curves are only defined in the `[0, 1]` domain. Most
/// curves have a `[0, 1]` range. But some can return negative values. So, be cautious when
/// transforming using a bunch of curves together.
///
/// A good idea is to keep the range [0, 1] until the last transform which transforms it to the
/// desired range, like `[0, 500]` for pixels.
class AnimationSpec<T> {
  Duration duration = const Duration(seconds: 1);
  Animatable<double> _sofar = Tween<double>(begin: 0, end: 1);
  late Animatable<T> _animatable;

  durationSecs(int seconds) {
    duration = Duration(seconds: seconds);
  }

  durationMillis(int millis) {
    duration = Duration(milliseconds: millis);
  }

  transform(Animatable<double> dbl) {
    _sofar = dbl.chain(_sofar);
    if (T == double) {
      // Calling complete(Tween<T>) is optional
      _animatable = _sofar as Animatable<T>;
    }
  }

  transformLast(Tween<T> last) {
    _animatable = last.chain(_sofar);
  }
}

////////////////////////////// Private Impl Details ////////////////////////
class _AnimateOnEventWidget<T> extends StatefulWidget {
  const _AnimateOnEventWidget({
    required this.eventBus,
    required this.eventsToRebuildOn,
    required this.animSpec,
    required this.builder,
    required this.valueProvider,
  });

  final List<EventId> eventsToRebuildOn;
  final EventBus eventBus;
  final AnimationSpec<T> animSpec;
  final Widget Function(T) builder;
  final bool Function() valueProvider;

  @override
  State<_AnimateOnEventWidget<T>> createState() {
    return _AnimateOnEventWidgetState();
  }
}

// When animation completes
class _AnimateOnEventWidgetState<T> extends State<_AnimateOnEventWidget<T>>
    with SingleTickerProviderStateMixin<_AnimateOnEventWidget<T>> {
  List<EventSubscription> subs = [];
  late AnimationController animationController;
  late bool currentValue;

  @override
  void didUpdateWidget(_AnimateOnEventWidget<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _cancelEventSubs();
    _registerEventSubs();
  }

  @override
  void initState() {
    super.initState();

    animationController = AnimationController(
      duration: widget.animSpec.duration,
      lowerBound: 0,
      upperBound: 1,
      vsync: this,
    );
    animationController.addListener(() => setState(() {}));
    _syncAnimationToValue();

    _registerEventSubs();
  }

  @override
  void dispose() {
    _cancelEventSubs();

    animationController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget
        .builder(animationController.drive(widget.animSpec._animatable).value);
  }

  void _syncAnimationToValue() {
    currentValue = widget.valueProvider();
    if (currentValue) {
      animationController.forward(from: 1);
    } else {
      animationController.reverse(from: 0);
    }
  }

  void _valueChangedToTrue() {
    animationController.forward();
  }

  void _valueChangedToFalse() {
    animationController.reverse();
  }

  void _debugState(String phase) {
    print(""" $phase 
    ---------------------
        Animation duration = ${animationController.duration}
        Animation elpasedduration = ${animationController.lastElapsedDuration}
        Animation v1 = ${animationController.value}
        Animation v2 = ${animationController.drive(widget.animSpec._animatable).value}""");
  }

  void _registerEventSubs() {
    var listener = (Event event) {
      // check animation
      bool newValue = widget.valueProvider();
      if (currentValue != newValue) {
        currentValue = newValue;
        if (currentValue) {
          _valueChangedToTrue();
        } else {
          _valueChangedToFalse();
        }
      }
    };
    for (EventId eventId in widget.eventsToRebuildOn) {
      subs.add(widget.eventBus.subscribe(eventId, listener));
    }
  }

  void _cancelEventSubs() {
    for (var sub in subs) {
      sub.cancel();
    }
    subs = [];
  }
}
