class Employee {
  final String id;
  final String name;
  final String department;
  final String designation;
  final String mobile;
  final String email;
  final String address;
  final String bloodGroup;
  final String manager;
  final String joiningDate;
  final String salary;
  final String documents;
  final String emergencyName;
  final String emergencyPhone;
  final String bankAccount;
  final String ifsc;

  const Employee({
    required this.id,
    required this.name,
    required this.department,
    required this.designation,
    required this.mobile,
    required this.email,
    this.address = '',
    this.bloodGroup = '',
    this.manager = '',
    this.joiningDate = '',
    this.salary = '',
    this.documents = '',
    this.emergencyName = '',
    this.emergencyPhone = '',
    this.bankAccount = '',
    this.ifsc = '',
  });
}

class EmployeeStore {
  static final List<Employee> employees = [];
}
