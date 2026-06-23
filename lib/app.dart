import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'theme/app_theme.dart';
import 'models/user_session.dart';
import 'widgets/app_shell.dart';
import 'widgets/employee_shell.dart';
import 'pages/login_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/summary_detail_page.dart';
import 'pages/employee_profile_page.dart';
import 'pages/add_employee_page.dart';
import 'pages/check_in_page.dart';
import 'pages/check_out_page.dart';
import 'pages/gps_tracking_page.dart';
import 'pages/late_coming_page.dart';
import 'pages/leave_management_page.dart';
import 'pages/apply_leave_page.dart';
import 'pages/leave_approvals_page.dart';
import 'pages/leave_balance_page.dart';
import 'pages/task_management_page.dart';
import 'pages/add_task_page.dart';
import 'pages/performance_management_page.dart';
import 'pages/salary_hike_engine_page.dart';
import 'pages/payroll_management_page.dart';
import 'pages/interview_process_page.dart';
import 'pages/employee_onboarding_page.dart';
import 'pages/ads_management_page.dart';
import 'pages/lead_management_page.dart';
import 'pages/maintenance_management_page.dart';
import 'pages/approvals_page.dart';
import 'pages/notifications_page.dart';
import 'pages/reports_analytics_page.dart';
import 'pages/administration_page.dart';
import 'pages/employee_dashboard_page.dart';
import 'pages/my_attendance_page.dart';
import 'pages/my_tasks_page.dart';
import 'pages/my_payslips_page.dart';
import 'pages/my_profile_page.dart';
import 'pages/my_details_page.dart';
import 'pages/employee_attendance_page.dart';
import 'pages/hr_attendance_records_page.dart';
import 'pages/hr_attendance_detail_page.dart';
import 'pages/hr_employee_records_page.dart';
import 'pages/employee_leave_page.dart';
import 'pages/my_leave_approvals_page.dart';
import 'pages/my_leave_balance_page.dart';
import 'pages/hr_leave_records_page.dart';
import 'widgets/manager_shell.dart';
import 'pages/manager_dashboard_page.dart';
import 'pages/manager_leave_page.dart';
import 'pages/team_leave_approvals_page.dart';
import 'widgets/management_shell.dart';
import 'pages/management_dashboard_page.dart';

String? _guard(GoRouterState state) {
  final path = state.uri.path;
  if (path == '/login') return null;

  if (!UserSession.loggedIn) return '/login';

  final role = UserSession.role;

  // Root path: send to the role's home
  if (path == '/' || path.isEmpty) {
    if (role == UserRole.hr) return '/dashboard';
    if (role == UserRole.employee) return '/employee/dashboard';
    if (role == UserRole.management) return '/management/dashboard';
    return '/manager/dashboard';
  }

  // Management can access all routes — no redirect needed
  if (role == UserRole.management) return null;

  if (path.startsWith('/management/')) return '/dashboard';

  if (path.startsWith('/employee/') && role != UserRole.employee) {
    return role == UserRole.hr ? '/dashboard' : '/manager/dashboard';
  }
  if (path.startsWith('/manager/') && role != UserRole.reportingManager) {
    return role == UserRole.hr ? '/dashboard' : '/employee/dashboard';
  }
  if (!path.startsWith('/employee/') && !path.startsWith('/manager/') &&
      path != '/login' && role != UserRole.hr) {
    return role == UserRole.employee ? '/employee/dashboard' : '/manager/dashboard';
  }

  return null;
}

final _router = GoRouter(
  initialLocation: '/login',
  redirect: (_, state) => _guard(state),
  errorBuilder: (context, state) => Scaffold(
    body: Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.error_outline, size: 48, color: Color(0xFF0D47A1)),
        const SizedBox(height: 16),
        const Text('Page not found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () => context.go('/login'),
          child: const Text('Go to Login'),
        ),
      ]),
    ),
  ),
  routes: [
    // ── Login ──────────────────────────────────────────────────────────────
    GoRoute(path: '/login', builder: (_, __) => const LoginPage()),

    // ── HR Shell ───────────────────────────────────────────────────────────
    ShellRoute(
      builder: (context, state, child) =>
          AppShell(child: child, location: state.uri.path),
      routes: [
        GoRoute(path: '/dashboard', builder: (_, __) => const DashboardPage()),
        GoRoute(
          path: '/summary/:sectionId',
          builder: (_, state) => SummaryDetailPage(
            sectionId: state.pathParameters['sectionId'] ?? '',
          ),
        ),
        GoRoute(path: '/employee-management',             builder: (_, __) => const HrEmployeeRecordsPage()),
        GoRoute(path: '/employee-management/add',         builder: (_, __) => const AddEmployeePage()),
        GoRoute(path: '/employee-management/profile',     builder: (_, __) => const EmployeeProfilePage()),
        GoRoute(path: '/attendance-management',           builder: (_, __) => const HrAttendanceRecordsPage()),
        GoRoute(path: '/attendance/check-in',             builder: (_, __) => const CheckInPage()),
        GoRoute(path: '/attendance/check-out',            builder: (_, __) => const CheckOutPage()),
        GoRoute(path: '/attendance/gps-tracking',         builder: (_, __) => const GpsTrackingPage()),
        GoRoute(path: '/attendance/late-coming',           builder: (_, __) => const LateComingPage()),
        GoRoute(path: '/attendance/employee-records', builder: (_, __) => const HrAttendanceRecordsPage()),
        GoRoute(path: '/attendance/hr/check-in',      builder: (_, __) => const HrAttendanceDetailPage(
          title: 'Check In', icon: Icons.login_rounded, color: Color(0xFF0D47A1),
          columns: ['Employee', 'Date', 'Check-In Time', 'GPS Location', 'Status'],
        )),
        GoRoute(path: '/attendance/hr/check-out',     builder: (_, __) => const HrAttendanceDetailPage(
          title: 'Check Out', icon: Icons.logout_rounded, color: Color(0xFF1565C0),
          columns: ['Employee', 'Date', 'Check-Out Time', 'GPS Location', 'Status'],
        )),
        GoRoute(path: '/attendance/hr/gps-tracking',  builder: (_, __) => const HrAttendanceDetailPage(
          title: 'GPS Tracking', icon: Icons.location_on_rounded, color: Color(0xFF0288D1),
          columns: ['Employee', 'Date', 'Last Location', 'Route Points', 'Time'],
        )),
        GoRoute(path: '/attendance/hr/late-coming',   builder: (_, __) => const HrAttendanceDetailPage(
          title: 'Late Coming', icon: Icons.watch_later_rounded, color: Color(0xFF283593),
          columns: ['Employee', 'Date', 'Arrival Time', 'Late By', 'Deduction'],
        )),
        GoRoute(path: '/employee-management/records', builder: (_, __) => const HrEmployeeRecordsPage()),
        GoRoute(path: '/leave-management',                builder: (_, __) => const LeaveManagementPage()),
        GoRoute(path: '/leave/apply',                     builder: (_, __) => const ApplyLeavePage()),
        GoRoute(path: '/leave/approvals',                 builder: (_, __) => const LeaveApprovalsPage()),
        GoRoute(path: '/leave/balance',                   builder: (_, __) => const LeaveBalancePage()),
        GoRoute(path: '/leave/employee-records',          builder: (_, __) => const HrLeaveRecordsPage()),
        GoRoute(path: '/task-management',                 builder: (_, __) => const TaskManagementPage()),
        GoRoute(path: '/task-management/add',             builder: (_, __) => const AddTaskPage()),
        GoRoute(path: '/performance-management',          builder: (_, __) => const PerformanceManagementPage()),
        GoRoute(path: '/salary-hike-engine',              builder: (_, __) => const SalaryHikeEnginePage()),
        GoRoute(path: '/payroll-management',              builder: (_, __) => const PayrollManagementPage()),
        GoRoute(path: '/interview-process',               builder: (_, __) => const InterviewProcessPage()),
        GoRoute(path: '/employee-onboarding',             builder: (_, __) => const EmployeeOnboardingPage()),
        GoRoute(path: '/ads-management',                  builder: (_, __) => const AdsManagementPage()),
        GoRoute(path: '/lead-management',                 builder: (_, __) => const LeadManagementPage()),
        GoRoute(path: '/maintenance-management',          builder: (_, __) => const MaintenanceManagementPage()),
        GoRoute(path: '/approvals',                       builder: (_, __) => const ApprovalsPage()),
        GoRoute(path: '/notifications',                   builder: (_, __) => const NotificationsPage()),
        GoRoute(path: '/reports-analytics',               builder: (_, __) => const ReportsAnalyticsPage()),
      ],
    ),

    // ── Employee Shell ─────────────────────────────────────────────────────
    ShellRoute(
      builder: (context, state, child) =>
          EmployeeShell(child: child, location: state.uri.path),
      routes: [
        GoRoute(path: '/employee/dashboard',               builder: (_, __) => const EmployeeDashboardPage()),
        GoRoute(path: '/employee/my-details',              builder: (_, __) => const MyDetailsPage()),
        GoRoute(path: '/employee/attendance-management',   builder: (_, __) => const EmployeeAttendancePage()),
        GoRoute(path: '/employee/attendance/check-in',     builder: (_, __) => const CheckInPage()),
        GoRoute(path: '/employee/attendance/check-out',    builder: (_, __) => const CheckOutPage()),
        GoRoute(path: '/employee/attendance/gps-tracking', builder: (_, __) => const GpsTrackingPage()),
        GoRoute(path: '/employee/attendance/late-coming',  builder: (_, __) => const LateComingPage()),
        GoRoute(path: '/employee/attendance',              builder: (_, __) => const MyAttendancePage()),
        GoRoute(path: '/employee/leave-management',        builder: (_, __) => const EmployeeLeavePage()),
        GoRoute(path: '/employee/leave/apply',             builder: (_, __) => const ApplyLeavePage()),
        GoRoute(path: '/employee/leave/approvals',         builder: (_, __) => const MyLeaveApprovalsPage()),
        GoRoute(path: '/employee/leave/balance',           builder: (_, __) => const MyLeaveBalancePage()),
        GoRoute(path: '/employee/leave',                   builder: (_, __) => const ApplyLeavePage()),
        GoRoute(path: '/employee/tasks',                    builder: (_, __) => const MyTasksPage()),
        GoRoute(path: '/employee/payslips',                 builder: (_, __) => const MyPayslipsPage()),
        GoRoute(path: '/employee/profile',                  builder: (_, __) => const MyProfilePage()),
        GoRoute(path: '/employee/maintenance-management',   builder: (_, __) => const MaintenanceManagementPage()),
        GoRoute(path: '/employee/employee-onboarding',      builder: (_, __) => const EmployeeOnboardingPage()),
        GoRoute(path: '/employee/notifications',            builder: (_, __) => const NotificationsPage()),
      ],
    ),

    // ── Reporting Manager Shell ────────────────────────────────────────────
    ShellRoute(
      builder: (context, state, child) =>
          ManagerShell(child: child, location: state.uri.path),
      routes: [
        GoRoute(path: '/manager/dashboard',               builder: (_, __) => const ManagerDashboardPage()),
        // HR-side pages
        GoRoute(path: '/manager/employee-management',     builder: (_, __) => const HrEmployeeRecordsPage()),
        GoRoute(path: '/manager/attendance-management',   builder: (_, __) => const HrAttendanceRecordsPage()),
        GoRoute(path: '/manager/leave-management',        builder: (_, __) => const ManagerLeavePage()),
        GoRoute(path: '/manager/leave/apply',             builder: (_, __) => const ApplyLeavePage()),
        GoRoute(path: '/manager/leave/approvals',         builder: (_, __) => const MyLeaveApprovalsPage()),
        GoRoute(path: '/manager/leave/balance',           builder: (_, __) => const MyLeaveBalancePage()),
        GoRoute(path: '/manager/leave/team-approvals',   builder: (_, __) => const TeamLeaveApprovalsPage()),
        GoRoute(path: '/manager/task-management',         builder: (_, __) => const TaskManagementPage()),
        GoRoute(path: '/manager/task-management/add',     builder: (_, __) => const AddTaskPage()),
        GoRoute(path: '/manager/performance-management',  builder: (_, __) => const PerformanceManagementPage()),
        GoRoute(path: '/manager/salary-hike-engine',      builder: (_, __) => const SalaryHikeEnginePage()),
        GoRoute(path: '/manager/payroll-management',      builder: (_, __) => const PayrollManagementPage()),
        GoRoute(path: '/manager/interview-process',       builder: (_, __) => const InterviewProcessPage()),
        GoRoute(path: '/manager/employee-onboarding',     builder: (_, __) => const EmployeeOnboardingPage()),
        GoRoute(path: '/manager/ads-management',          builder: (_, __) => const AdsManagementPage()),
        GoRoute(path: '/manager/lead-management',         builder: (_, __) => const LeadManagementPage()),
        GoRoute(path: '/manager/maintenance-management',  builder: (_, __) => const MaintenanceManagementPage()),
        GoRoute(path: '/manager/approvals',               builder: (_, __) => const ApprovalsPage()),
        GoRoute(path: '/manager/notifications',           builder: (_, __) => const NotificationsPage()),
        GoRoute(path: '/manager/reports-analytics',       builder: (_, __) => const ReportsAnalyticsPage()),
        // Personal pages
        GoRoute(path: '/manager/my-details',              builder: (_, __) => const MyDetailsPage()),
        GoRoute(path: '/manager/my-attendance',           builder: (_, __) => const EmployeeAttendancePage()),
        GoRoute(path: '/manager/my-leave',                builder: (_, __) => const EmployeeLeavePage()),
        GoRoute(path: '/manager/my-tasks',                builder: (_, __) => const MyTasksPage()),
        GoRoute(path: '/manager/my-payslips',             builder: (_, __) => const MyPayslipsPage()),
        GoRoute(path: '/manager/my-profile',              builder: (_, __) => const MyProfilePage()),
      ],
    ),
    // ── Management Shell ──────────────────────────────────────────────────────
    ShellRoute(
      builder: (context, state, child) =>
          ManagementShell(child: child, location: state.uri.path),
      routes: [
        GoRoute(path: '/management/dashboard',              builder: (_, __) => const ManagementDashboardPage()),
        GoRoute(path: '/management/employee-management',    builder: (_, __) => const HrEmployeeRecordsPage()),
        GoRoute(path: '/management/employee-management/add',builder: (_, __) => const AddEmployeePage()),
        GoRoute(path: '/management/employee-management/profile', builder: (_, __) => const EmployeeProfilePage()),
        GoRoute(path: '/management/attendance-management',  builder: (_, __) => const HrAttendanceRecordsPage()),
        GoRoute(path: '/management/attendance/check-in',    builder: (_, __) => const CheckInPage()),
        GoRoute(path: '/management/attendance/check-out',   builder: (_, __) => const CheckOutPage()),
        GoRoute(path: '/management/attendance/gps-tracking',builder: (_, __) => const GpsTrackingPage()),
        GoRoute(path: '/management/attendance/late-coming', builder: (_, __) => const LateComingPage()),
        GoRoute(path: '/management/leave-management',       builder: (_, __) => const LeaveManagementPage()),
        GoRoute(path: '/management/leave/apply',            builder: (_, __) => const ApplyLeavePage()),
        GoRoute(path: '/management/leave/approvals',        builder: (_, __) => const LeaveApprovalsPage()),
        GoRoute(path: '/management/leave/balance',          builder: (_, __) => const LeaveBalancePage()),
        GoRoute(path: '/management/leave/team-approvals',   builder: (_, __) => const TeamLeaveApprovalsPage()),
        GoRoute(path: '/management/leave/employee-records', builder: (_, __) => const HrLeaveRecordsPage()),
        GoRoute(path: '/management/task-management',        builder: (_, __) => const TaskManagementPage()),
        GoRoute(path: '/management/task-management/add',    builder: (_, __) => const AddTaskPage()),
        GoRoute(path: '/management/performance-management', builder: (_, __) => const PerformanceManagementPage()),
        GoRoute(path: '/management/salary-hike-engine',     builder: (_, __) => const SalaryHikeEnginePage()),
        GoRoute(path: '/management/payroll-management',     builder: (_, __) => const PayrollManagementPage()),
        GoRoute(path: '/management/interview-process',      builder: (_, __) => const InterviewProcessPage()),
        GoRoute(path: '/management/employee-onboarding',    builder: (_, __) => const EmployeeOnboardingPage()),
        GoRoute(path: '/management/ads-management',         builder: (_, __) => const AdsManagementPage()),
        GoRoute(path: '/management/lead-management',        builder: (_, __) => const LeadManagementPage()),
        GoRoute(path: '/management/maintenance-management', builder: (_, __) => const MaintenanceManagementPage()),
        GoRoute(path: '/management/approvals',              builder: (_, __) => const ApprovalsPage()),
        GoRoute(path: '/management/notifications',          builder: (_, __) => const NotificationsPage()),
        GoRoute(path: '/management/reports-analytics',      builder: (_, __) => const ReportsAnalyticsPage()),
        GoRoute(path: '/management/administration',         builder: (_, __) => const AdministrationPage()),
        GoRoute(path: '/management/my-details',             builder: (_, __) => const MyDetailsPage()),
        GoRoute(path: '/management/my-attendance',          builder: (_, __) => const EmployeeAttendancePage()),
        GoRoute(path: '/management/my-leave',               builder: (_, __) => const EmployeeLeavePage()),
        GoRoute(path: '/management/my-tasks',               builder: (_, __) => const MyTasksPage()),
        GoRoute(path: '/management/my-payslips',            builder: (_, __) => const MyPayslipsPage()),
        GoRoute(path: '/management/my-profile',             builder: (_, __) => const MyProfilePage()),
      ],
    ),
  ],
);

class FomraHrmsApp extends StatelessWidget {
  const FomraHrmsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'FOMRA HRMS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: _router,
    );
  }
}
