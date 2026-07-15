import '../models/language_notifier.dart';

/// Staff Portal translation table (English / Hindi / Tamil). Keyed by a
/// stable English key so callers read `st('tab_home')` rather than raw text.
/// Only the Staff Portal (Housekeeping/Support Staff) is translated — every
/// other shell in the app stays English-only.
const Map<String, Map<AppLanguage, String>> _staffStrings = {
  // ── Shell / nav ──────────────────────────────────────────────────────
  'tab_home':        {AppLanguage.en: 'Home',       AppLanguage.hi: 'होम',            AppLanguage.ta: 'முகப்பு'},
  'tab_leave':       {AppLanguage.en: 'Leave',      AppLanguage.hi: 'छुट्टी',          AppLanguage.ta: 'விடுப்பு'},
  'tab_permission':  {AppLanguage.en: 'Permission', AppLanguage.hi: 'अनुमति',          AppLanguage.ta: 'அனுமதி'},
  'tab_profile':     {AppLanguage.en: 'Profile',    AppLanguage.hi: 'प्रोफ़ाइल',       AppLanguage.ta: 'சுயவிவரம்'},
  'logout_tooltip':  {AppLanguage.en: 'Log out',    AppLanguage.hi: 'लॉग आउट',         AppLanguage.ta: 'வெளியேறு'},
  'logout_title':    {AppLanguage.en: 'Log out?',   AppLanguage.hi: 'लॉग आउट करें?',   AppLanguage.ta: 'வெளியேறவா?'},
  'logout_body':     {AppLanguage.en: 'You will need to sign in again to continue.',
                       AppLanguage.hi: 'जारी रखने के लिए आपको फिर से साइन इन करना होगा।',
                       AppLanguage.ta: 'தொடர மீண்டும் உள்நுழைய வேண்டும்.'},
  'cancel':          {AppLanguage.en: 'Cancel',     AppLanguage.hi: 'रद्द करें',       AppLanguage.ta: 'ரத்து செய்'},
  'log_out':         {AppLanguage.en: 'Log Out',    AppLanguage.hi: 'लॉग आउट',         AppLanguage.ta: 'வெளியேறு'},
  'language':        {AppLanguage.en: 'Language',   AppLanguage.hi: 'भाषा',            AppLanguage.ta: 'மொழி'},
  'choose_language': {AppLanguage.en: 'Choose your language',
                       AppLanguage.hi: 'अपनी भाषा चुनें',
                       AppLanguage.ta: 'உங்கள் மொழியைத் தேர்ந்தெடுக்கவும்'},

  // ── Home ─────────────────────────────────────────────────────────────
  'check_in':               {AppLanguage.en: 'Check In',  AppLanguage.hi: 'चेक इन',       AppLanguage.ta: 'செக் இன்'},
  'check_out':              {AppLanguage.en: 'Check Out', AppLanguage.hi: 'चेक आउट',      AppLanguage.ta: 'செக் அவுட்'},
  'checked_in_success':     {AppLanguage.en: 'Checked In Successfully',
                              AppLanguage.hi: 'सफलतापूर्वक चेक इन किया गया',
                              AppLanguage.ta: 'வெற்றிகரமாக செக் இன் செய்யப்பட்டது'},
  'shift_completed':        {AppLanguage.en: 'Shift Completed Successfully',
                              AppLanguage.hi: 'शिफ्ट सफलतापूर्वक पूरी हुई',
                              AppLanguage.ta: 'ஷிஃப்ட் வெற்றிகரமாக முடிந்தது'},
  'checked_in_at':          {AppLanguage.en: 'Checked in at',  AppLanguage.hi: 'चेक इन समय',   AppLanguage.ta: 'செக் இன் நேரம்'},
  'checked_out_at':         {AppLanguage.en: 'Checked out at', AppLanguage.hi: 'चेक आउट समय',  AppLanguage.ta: 'செக் அவுட் நேரம்'},

  // ── Leave ────────────────────────────────────────────────────────────
  'apply_leave':            {AppLanguage.en: 'Apply Leave', AppLanguage.hi: 'छुट्टी के लिए आवेदन करें', AppLanguage.ta: 'விடுப்புக்கு விண்ணப்பிக்கவும்'},
  'leave_date':             {AppLanguage.en: 'Leave Date',  AppLanguage.hi: 'छुट्टी की तारीख',           AppLanguage.ta: 'விடுப்பு தேதி'},
  'select_date':            {AppLanguage.en: 'Select date', AppLanguage.hi: 'तारीख चुनें',               AppLanguage.ta: 'தேதியைத் தேர்ந்தெடுக்கவும்'},
  'apply':                  {AppLanguage.en: 'Apply',       AppLanguage.hi: 'आवेदन करें',                 AppLanguage.ta: 'விண்ணப்பிக்கவும்'},
  'select_leave_date_err':  {AppLanguage.en: 'Please select a leave date.',
                              AppLanguage.hi: 'कृपया छुट्टी की तारीख चुनें।',
                              AppLanguage.ta: 'தயவுசெய்து விடுப்பு தேதியைத் தேர்ந்தெடுக்கவும்.'},
  'leave_submitted':        {AppLanguage.en: 'Leave Request Submitted Successfully.',
                              AppLanguage.hi: 'छुट्टी का अनुरोध सफलतापूर्वक भेजा गया।',
                              AppLanguage.ta: 'விடுப்பு கோரிக்கை வெற்றிகரமாக சமர்ப்பிக்கப்பட்டது.'},

  // ── Permission ───────────────────────────────────────────────────────
  'apply_permission':       {AppLanguage.en: 'Apply Permission', AppLanguage.hi: 'अनुमति के लिए आवेदन करें', AppLanguage.ta: 'அனுமதிக்கு விண்ணப்பிக்கவும்'},
  'permission_date':        {AppLanguage.en: 'Permission Date',  AppLanguage.hi: 'अनुमति की तारीख',           AppLanguage.ta: 'அனுமதி தேதி'},
  'permission_duration':    {AppLanguage.en: 'Permission Duration', AppLanguage.hi: 'अनुमति की अवधि',        AppLanguage.ta: 'அனுமதி காலம்'},
  'duration_30m':           {AppLanguage.en: '30 Minutes',       AppLanguage.hi: '30 मिनट',                    AppLanguage.ta: '30 நிமிடங்கள்'},
  'duration_1h':            {AppLanguage.en: '1 Hour',           AppLanguage.hi: '1 घंटा',                     AppLanguage.ta: '1 மணி நேரம்'},
  'duration_1h30m':         {AppLanguage.en: '1 Hour 30 Minutes',AppLanguage.hi: '1 घंटा 30 मिनट',             AppLanguage.ta: '1 மணி 30 நிமிடங்கள்'},
  'duration_2h':            {AppLanguage.en: '2 Hours',          AppLanguage.hi: '2 घंटे',                     AppLanguage.ta: '2 மணி நேரம்'},
  'select_permission_date_err': {AppLanguage.en: 'Please select a permission date.',
                              AppLanguage.hi: 'कृपया अनुमति की तारीख चुनें।',
                              AppLanguage.ta: 'தயவுசெய்து அனுமதி தேதியைத் தேர்ந்தெடுக்கவும்.'},
  'permission_submitted':   {AppLanguage.en: 'Permission Request Submitted Successfully.',
                              AppLanguage.hi: 'अनुमति का अनुरोध सफलतापूर्वक भेजा गया।',
                              AppLanguage.ta: 'அனுமதி கோரிக்கை வெற்றிகரமாக சமர்ப்பிக்கப்பட்டது.'},
  'permission_limit_reached': {AppLanguage.en: 'You have already used your maximum 2 permissions for this month.',
                              AppLanguage.hi: 'आपने इस महीने अपनी अधिकतम 2 अनुमतियों का उपयोग कर लिया है।',
                              AppLanguage.ta: 'இந்த மாதத்திற்கான உங்கள் அதிகபட்ச 2 அனுமதிகளை ஏற்கனவே பயன்படுத்திவிட்டீர்கள்.'},

  // ── History (leave/permission status) ───────────────────────────────
  'history':                {AppLanguage.en: 'History',   AppLanguage.hi: 'इतिहास',        AppLanguage.ta: 'வரலாறு'},
  'status_approved':        {AppLanguage.en: 'Approved',  AppLanguage.hi: 'स्वीकृत',       AppLanguage.ta: 'அங்கீகரிக்கப்பட்டது'},
  'status_denied':          {AppLanguage.en: 'Denied',    AppLanguage.hi: 'अस्वीकृत',      AppLanguage.ta: 'நிராகரிக்கப்பட்டது'},
  'status_pending':         {AppLanguage.en: 'Pending',   AppLanguage.hi: 'लंबित',         AppLanguage.ta: 'நிலுவையில்'},
  'no_leave_history':       {AppLanguage.en: 'No leave requests yet',
                              AppLanguage.hi: 'अभी तक कोई छुट्टी अनुरोध नहीं',
                              AppLanguage.ta: 'இதுவரை விடுப்பு கோரிக்கைகள் இல்லை'},
  'no_permission_history':  {AppLanguage.en: 'No permission requests yet',
                              AppLanguage.hi: 'अभी तक कोई अनुमति अनुरोध नहीं',
                              AppLanguage.ta: 'இதுவரை அனுமதி கோரிக்கைகள் இல்லை'},

  // ── Profile ──────────────────────────────────────────────────────────
  'employee_id':   {AppLanguage.en: 'Employee ID',   AppLanguage.hi: 'कर्मचारी आईडी',      AppLanguage.ta: 'பணியாளர் அடையாள எண்'},
  'department':    {AppLanguage.en: 'Department',    AppLanguage.hi: 'विभाग',              AppLanguage.ta: 'துறை'},
  'designation':   {AppLanguage.en: 'Designation',   AppLanguage.hi: 'पदनाम',              AppLanguage.ta: 'பதவி'},
  'manager':       {AppLanguage.en: 'Manager',       AppLanguage.hi: 'प्रबंधक',            AppLanguage.ta: 'மேலாளர்'},
  'phone_number':  {AppLanguage.en: 'Phone Number',  AppLanguage.hi: 'फ़ोन नंबर',          AppLanguage.ta: 'தொலைபேசி எண்'},
  'joining_date':  {AppLanguage.en: 'Joining Date',  AppLanguage.hi: 'शामिल होने की तारीख', AppLanguage.ta: 'சேர்ந்த தேதி'},
};

/// Looks up [key] in the current staff-portal language; falls back to
/// English, then to the raw key if the entry itself is missing.
String st(String key) {
  final entry = _staffStrings[key];
  if (entry == null) return key;
  return entry[staffLanguageNotifier.value] ?? entry[AppLanguage.en] ?? key;
}

const _languageNames = {
  AppLanguage.en: 'English',
  AppLanguage.hi: 'हिन्दी',
  AppLanguage.ta: 'தமிழ்',
};

/// A language's own display name, always shown in its own script
/// regardless of the currently active language.
String languageDisplayName(AppLanguage lang) => _languageNames[lang]!;
