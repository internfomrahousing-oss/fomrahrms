/// Configures hash-based URL routing on web. No-op on native, where
/// package:flutter_web_plugins isn't even resolvable (it imports dart:ui_web).
export 'url_strategy_native.dart'
  if (dart.library.html) 'url_strategy_web.dart';
