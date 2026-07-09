/// String key-value store used for the persisted login session.
/// Web uses sessionStorage (scoped to the current browser tab, so logging
/// in as a different user in another tab can't overwrite this one's session
/// on refresh); native uses SharedPreferences.
export 'kv_store_native.dart'
  if (dart.library.html) 'kv_store_web.dart';
