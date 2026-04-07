import 'package:common_event/api.dart';
import 'package:inject_annotation/inject_annotation.dart';

@singleton
@inject
class DebugPanel with FiresEventsMixin implements FiresEvents {
  DebugPanel(EventBus eventBus) {
    this.eventBus = eventBus;
  }

  bool _isShowing = false;

  void setVisible(bool isVisible) {
    _isShowing = isVisible;
    fireUpdateEvent();
  }

  bool isVisible() {
    return _isShowing;
  }
}
