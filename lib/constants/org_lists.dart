/// Fixed department and designation options, used wherever HR assigns them:
/// the pre-offer letter, the onboarding hand-off to Management, and HR Employee Management.
const List<String> kDepartments = [
  'HR',
  'Admin',
  'Operation',
  'CRM',
  'Projects',
  'Land Acquisition',
  'Accounts',
  'Sales',
  'Digital Marketing',
  'Housekeeping',
  'Support Staff',
];

/// Departments routed to the simplified Staff Portal instead of the regular
/// employee portal (see UserSession.isStaffPortal and lib/app.dart's guard).
const List<String> kStaffPortalDepartments = ['Housekeeping', 'Support Staff'];

const List<String> kDesignations = [
  'Manager',
  'Assistant Manager',
  'Senior Manager',
  'Deputy Manager',
  'Executive',
  'Senior Executive',
  'Head',
  'Junior Executive',
];
