import 'dart:typed_data';

class OnboardingData {
  final String employeeId;
  final String employeeName;
  final Uint8List aadhaarDoc;
  final Uint8List panDoc;
  final Uint8List resume;
  final Uint8List educationalCertificates;
  final Uint8List experienceLetters;
  final String bankAccount;
  final String ifscCode;
  final Uint8List passportPhoto;
  final DateTime submittedAt;

  OnboardingData({
    required this.employeeId,
    required this.employeeName,
    required this.aadhaarDoc,
    required this.panDoc,
    required this.resume,
    required this.educationalCertificates,
    required this.experienceLetters,
    required this.bankAccount,
    required this.ifscCode,
    required this.passportPhoto,
    required this.submittedAt,
  });
}

class OnboardingStore {
  static final Map<String, OnboardingData> _data = {};

  static OnboardingData? forId(String id) => _data[id];

  static void save(OnboardingData data) {
    _data[data.employeeId] = data;
  }

  static List<OnboardingData> get all => List.unmodifiable(_data.values);
}
