import 'user_session.dart';

class ProfileData {
  String employeeId;
  String fullName;
  String mobile;
  String email;
  String address;
  String department;
  String designation;
  String reportingManager;
  String dateOfJoining;

  ProfileData({
    this.employeeId = '',
    this.fullName = '',
    this.mobile = '',
    this.email = '',
    this.address = '',
    this.department = '',
    this.designation = '',
    this.reportingManager = '',
    this.dateOfJoining = '',
  });

  bool get isEmpty => fullName.isEmpty && employeeId.isEmpty;
}

class ProfileStore {
  static final Map<String, ProfileData> _data   = {};
  static final Set<String>              _locked = {};

  static ProfileData forId(String id) =>
      _data.putIfAbsent(id, () => ProfileData(employeeId: id));

  static ProfileData get current {
    final id = UserSession.employeeId;
    return id.isEmpty ? ProfileData() : forId(id);
  }

  static List<ProfileData> get all => List.unmodifiable(_data.values);

  // Returns true once an employee/manager has saved their profile the first time.
  static bool isLocked(String id) => _locked.contains(id);

  // Saves a profile. Locks it on first save (only HR can call saveByHr to update later).
  static void save(ProfileData data) {
    if (data.employeeId.isEmpty) return;
    _data[data.employeeId] = data;
    _locked.add(data.employeeId);
    UserSession.employeeId = data.employeeId;
    if (data.fullName.isNotEmpty) UserSession.name = data.fullName;
  }

  // HR-only update — does not change lock state.
  static void saveByHr(ProfileData data) {
    if (data.employeeId.isEmpty) return;
    _data[data.employeeId] = data;
    if (data.fullName.isNotEmpty &&
        UserSession.employeeId == data.employeeId) {
      UserSession.name = data.fullName;
    }
  }
}
