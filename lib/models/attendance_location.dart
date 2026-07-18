/// A physical place (office, branch, client site, ...) employees may be
/// required to check in/out near. HR manages these from the Location
/// Management page — see lib/pages/location_management_page.dart.
class OfficeLocation {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final int radiusMeters;
  final String type; // 'Office' | 'Branch' | 'Client Site' | 'Other' (free text)
  final bool active;

  const OfficeLocation({
    required this.id,
    required this.name,
    this.address = '',
    required this.latitude,
    required this.longitude,
    this.radiusMeters = 30,
    this.type = 'Office',
    this.active = true,
  });

  factory OfficeLocation.fromJson(Map<String, dynamic> j) => OfficeLocation(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        address: j['address'] as String? ?? '',
        latitude: (j['latitude'] as num?)?.toDouble() ?? 0,
        longitude: (j['longitude'] as num?)?.toDouble() ?? 0,
        radiusMeters: (j['radius_meters'] as num?)?.toInt() ?? 30,
        type: j['type'] as String? ?? 'Office',
        active: j['active'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        if (id.isNotEmpty) 'id': id,
        'name': name,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'radius_meters': radiusMeters,
        'type': type,
        'active': active,
      };
}

enum AttendancePolicyType { singleLocation, multiLocation, unrestricted }

AttendancePolicyType _policyTypeFromString(String? s) {
  switch (s) {
    case 'multi_location':
      return AttendancePolicyType.multiLocation;
    case 'unrestricted':
      return AttendancePolicyType.unrestricted;
    case 'single_location':
    default:
      return AttendancePolicyType.singleLocation;
  }
}

String policyTypeToString(AttendancePolicyType t) {
  switch (t) {
    case AttendancePolicyType.multiLocation:
      return 'multi_location';
    case AttendancePolicyType.unrestricted:
      return 'unrestricted';
    case AttendancePolicyType.singleLocation:
      return 'single_location';
  }
}

String policyTypeLabel(AttendancePolicyType t) {
  switch (t) {
    case AttendancePolicyType.singleLocation:
      return 'Single Location';
    case AttendancePolicyType.multiLocation:
      return 'Multiple Locations';
    case AttendancePolicyType.unrestricted:
      return 'Unrestricted';
  }
}

/// A named rule set — how many locations an employee may be assigned, and
/// whether being outside all of them requires a note — that HR assigns to
/// a department or an individual employee. See AttendancePolicyStore for
/// how one is resolved for a given employee.
class AttendancePolicy {
  final String id;
  final String name;
  final AttendancePolicyType policyType;
  final bool noteRequiredOutsideRadius;

  const AttendancePolicy({
    required this.id,
    required this.name,
    required this.policyType,
    this.noteRequiredOutsideRadius = true,
  });

  /// Unrestricted policies never require a location — GPS is still always
  /// captured, but there is nothing to be "outside" of.
  bool get requiresLocation => policyType != AttendancePolicyType.unrestricted;

  factory AttendancePolicy.fromJson(Map<String, dynamic> j) => AttendancePolicy(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        policyType: _policyTypeFromString(j['policy_type'] as String?),
        noteRequiredOutsideRadius: j['note_required_outside_radius'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        if (id.isNotEmpty) 'id': id,
        'name': name,
        'policy_type': policyTypeToString(policyType),
        'note_required_outside_radius': noteRequiredOutsideRadius,
      };
}
