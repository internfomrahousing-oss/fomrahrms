/// Shared route map: draws a road-snapped route (via OSRM) between recorded
/// GPS points, falling back to a straight polyline if OSRM fails.
/// Web uses a Leaflet iframe; native (Android/iOS/desktop) uses flutter_map.
export 'route_map_view_native.dart'
  if (dart.library.html) 'route_map_view_web.dart';
