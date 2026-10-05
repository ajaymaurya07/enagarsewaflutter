import 'package:flutter/widgets.dart';

/// Anchor rect for the iOS share sheet (`sharePositionOrigin`).
///
/// share_plus throws a PlatformException on iOS 26+ and iPad when the origin
/// is missing or zero-sized. Uses the widget behind [context] when it is laid
/// out on screen, otherwise falls back to a small rect at the screen centre.
Rect shareOriginFor(BuildContext context) {
  final screenSize = MediaQuery.sizeOf(context);
  final screen = Offset.zero & screenSize;

  final renderObject = context.findRenderObject();
  if (renderObject is RenderBox && renderObject.hasSize) {
    final box = renderObject.localToGlobal(Offset.zero) & renderObject.size;
    if (!box.isEmpty && screen.overlaps(box)) {
      return box.intersect(screen);
    }
  }

  return Rect.fromCenter(center: screen.center, width: 1, height: 1);
}
