class CheckInRecord {
  final String employee;
  final String date;
  final String time;
  final String location;
  const CheckInRecord({required this.employee, required this.date, required this.time, required this.location});
}

class CheckOutRecord {
  final String employee;
  final String date;
  final String time;
  final String location;
  const CheckOutRecord({required this.employee, required this.date, required this.time, required this.location});
}

class LateComingRecord {
  final String employee;
  final String date;
  final String arrivalTime;
  final String reason;
  const LateComingRecord({required this.employee, required this.date, required this.arrivalTime, required this.reason});
}

class GpsRecord {
  final String employee;
  final String date;
  final String location;
  final String time;
  const GpsRecord({required this.employee, required this.date, required this.location, required this.time});
}

class AttendanceStore {
  static final List<CheckInRecord>    checkIns   = [];
  static final List<CheckOutRecord>   checkOuts  = [];
  static final List<LateComingRecord> lateComing = [];
  static final List<GpsRecord>        gpsRecords = [];

  static bool isCheckedIn = false;
}

// Persistent record loaded from / saved to Supabase
class AttendanceRecord {
  final String id;
  final String employeeName;
  final String employeeId;
  final String date;
  final String checkInTime;
  final String checkOutTime;
  final String location;
  final List<List<double>> gpsPoints; // [[lat,lng], ...] route
  final String checkInNote;
  final String checkOutNote;

  const AttendanceRecord({
    required this.id,
    required this.employeeName,
    required this.employeeId,
    required this.date,
    this.checkInTime = '',
    this.checkOutTime = '',
    this.location = '',
    this.gpsPoints = const [],
    this.checkInNote = '',
    this.checkOutNote = '',
  });
}
