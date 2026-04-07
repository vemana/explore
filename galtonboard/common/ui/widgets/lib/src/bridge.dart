import 'package:common_math/api.dart' as common;
import 'package:flutter/material.dart' as flutter;

extension sizeToLocal on flutter.Size {
  common.Dimensions get to {
    return common.Dimensions(width, height);
  }
}

extension offsetToLocal on flutter.Offset {
  common.Position get to {
    return common.Position(dx, dy);
  }
}

extension sizeToFlutter on common.Dimensions {
  flutter.Size get to {
    return flutter.Size(width, height);
  }
}

extension offsetToFlutter on common.Position {
  flutter.Offset get to {
    return flutter.Offset(dx, dy);
  }

  common.Position unit() {
    return this / distance;
  }
}
