import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/employee_store.dart';
import '../models/profile_store.dart';
import '../models/user_session.dart';

class HrEmployeeRecordsPage extends StatefulWidget {
  const HrEmployeeRecordsPage({super.key});

  @override
  State<HrEmployeeRecordsPage> createState() => _HrEmployeeRecordsPageState();
}

class _HrEmployeeRecordsPageState extends State<HrEmployeeRecordsPage> {
  static const _color = Color(0xFF0D47A1);
  String _search = '';

  // HR sees everyone; manager sees only their assigned employees.
  List<Employee> get _baseList {
    if (UserSession.role != UserRole.reportingManager) {
      return EmployeeStore.employees;
    }
    final managerName = ProfileStore.current.fullName.trim().toLowerCase();
    if (managerName.isEmpty) return EmployeeStore.employees;
    return EmployeeStore.employees
        .where((e) => e.manager.trim().toLowerCase() == managerName)
        .toList();
  }

  List<Employee> get _filtered {
    final base = _baseList;
    if (_search.trim().isEmpty) return base;
    final q = _search.toLowerCase();
    return base.where((e) =>
        e.name.toLowerCase().contains(q) ||
        e.id.toLowerCase().contains(q) ||
        e.department.toLowerCase().contains(q) ||
        e.designation.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: _color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.people_alt_rounded, color: _color, size: 26),
              ),
              const SizedBox(width: 16),
              Text('Employee Records',
                  style: Theme.of(context).textTheme.headlineMedium),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => context.push('/employee-management/add'),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Add New'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  textStyle: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ]),
            const SizedBox(height: 24),

            // Search
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Expanded(
                    child: TextField(
                      onChanged: (v) => setState(() => _search = v),
                      decoration: InputDecoration(
                        hintText: 'Search by name, ID, department...',
                        prefixIcon: const Icon(Icons.search_rounded,
                            color: _color, size: 20),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: _color, width: 2),
                        ),
                        filled: true, fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 16),

            if (list.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Center(
                    child: Column(children: [
                      Icon(Icons.people_outline_rounded,
                          size: 52, color: Colors.grey.shade300),
                      const SizedBox(height: 10),
                      Text(
                        _baseList.isEmpty
                            ? (UserSession.role == UserRole.reportingManager
                                ? 'No employees are assigned to you yet.'
                                : 'No employee records yet. Tap "Add New" to add one.')
                            : 'No results for "$_search"',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.grey.shade400, fontSize: 14)),
                    ]),
                  ),
                ),
              )
            else
              ...list.map((emp) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _EmployeeCard(
                      employee: emp,
                      onTap: () => _showDetails(emp),
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  void _showDetails(Employee emp) {
    showDialog(
      context: context,
      builder: (_) => _EmployeeDetailDialog(employee: emp),
    );
  }
}

class _EmployeeCard extends StatelessWidget {
  final Employee employee;
  final VoidCallback onTap;
  const _EmployeeCard({required this.employee, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: const Color(0xFF0D47A1).withValues(alpha: 0.1),
              child: const Icon(Icons.person_rounded,
                  color: Color(0xFF0D47A1), size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(children: [
                  Text(employee.name,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700,
                          color: Color(0xFF1A237E))),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D47A1).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(employee.id,
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w600,
                            color: Color(0xFF0D47A1))),
                  ),
                ]),
                const SizedBox(height: 4),
                Text('${employee.department}  ·  ${employee.designation}',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF78909C))),
              ]),
            ),
            Icon(Icons.chevron_right_rounded,
                color: Colors.grey.shade400, size: 20),
          ]),
        ),
      ),
    );
  }
}

class _EmployeeDetailDialog extends StatelessWidget {
  final Employee employee;
  const _EmployeeDetailDialog({required this.employee});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: const Color(0xFF0D47A1).withValues(alpha: 0.1),
                child: const Icon(Icons.person_rounded,
                    color: Color(0xFF0D47A1), size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(employee.name,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold,
                          color: Color(0xFF1A237E))),
                  const SizedBox(height: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D47A1).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(employee.id,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600,
                            color: Color(0xFF0D47A1))),
                  ),
                ]),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: Color(0xFF78909C)),
              ),
            ]),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            _Row(Icons.account_tree_rounded,        'Department',        employee.department),
            _Row(Icons.work_rounded,                'Designation',       employee.designation),
            _Row(Icons.phone_rounded,               'Mobile',            employee.mobile),
            _Row(Icons.email_rounded,               'Email',             employee.email),
            if (employee.address.isNotEmpty)
              _Row(Icons.location_on_rounded,       'Address',           employee.address),
            if (employee.bloodGroup.isNotEmpty)
              _Row(Icons.bloodtype_rounded,         'Blood Group',       employee.bloodGroup),
            if (employee.manager.isNotEmpty)
              _Row(Icons.manage_accounts_rounded,   'Manager',           employee.manager),
            if (employee.joiningDate.isNotEmpty)
              _Row(Icons.calendar_today_rounded,    'Date of Joining',   employee.joiningDate),
            if (employee.salary.isNotEmpty)
              _Row(Icons.account_balance_wallet_rounded, 'Salary (CTC)', employee.salary),
            if (employee.emergencyName.isNotEmpty)
              _Row(Icons.contact_emergency_rounded, 'Emergency Contact', employee.emergencyName),
            if (employee.emergencyPhone.isNotEmpty)
              _Row(Icons.phone_callback_rounded,    'Emergency Phone',   employee.emergencyPhone),
            if (employee.bankAccount.isNotEmpty)
              _Row(Icons.credit_card_rounded,       'Bank Account',      employee.bankAccount),
            if (employee.ifsc.isNotEmpty)
              _Row(Icons.confirmation_number_rounded,'IFSC Code',        employee.ifsc),
          ]),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _Row(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Icon(icon, size: 16, color: const Color(0xFF0D47A1)),
        const SizedBox(width: 10),
        SizedBox(
          width: 130,
          child: Text(label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF78909C))),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w500,
                  color: Color(0xFF263238))),
        ),
      ]),
    );
  }
}
