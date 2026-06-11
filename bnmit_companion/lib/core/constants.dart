class AppConstants {
  // Base URLs
  static const String baseUrl = 'https://bnmit-students.contineo.in';
  static const String portalPath = '/parentseven/';
  static const String portalUrl = '$baseUrl$portalPath';

  static String getPortalPath(String semester) {
    return semester == 'odd' ? '/parents/' : '/parentseven/';
  }

  static String getPortalUrl(String semester) {
    return '$baseUrl${getPortalPath(semester)}';
  }

  // Login endpoints
  static const String loginStep1Task = 'loginOtp';
  static const String loginStep2Task = 'login';

  // Dashboard
  static const String dashboardParams =
      'option=com_studentdashboard&controller=studentdashboard&task=dashboard';

  // Attendance
  static const String attendanceParams =
      'option=com_studentdashboard&controller=studentdashboard&task=attendencelist';

  // CIE/Marks
  static const String cieParams =
      'option=com_studentdashboard&controller=studentdashboard&task=ciedetails';

  // Timetable
  static const String timetableParams =
      'option=com_studentdashboard&controller=studentdashboard&task=timetable';

  // Logout
  static const String logoutOption = 'com_user';
  static const String logoutTask = 'logout';

  // Storage keys
  static const String keyUsername = 'contineo_username';
  static const String keyDob = 'contineo_dob';
  static const String keyIdType = 'contineo_id_type';
  static const String keyVerificationDigits = 'contineo_verification_digits';
  static const String keySemester = 'contineo_semester';
  static const String keySessionCookie = 'contineo_session_cookie';
  static const String keyIsLoggedIn = 'contineo_is_logged_in';
  static const String keyThemeMode = 'theme_mode';

  // Verification types
  static const Map<int, String> verificationTypes = {
    1: "Father Mobile Last 4 Digits",
    2: "Mother Mobile Last 4 Digits",
    3: "ABC ID Last 4 Digits",
  };

  // Attendance threshold
  static const double attendanceThreshold = 75.0;
  static const double attendanceWarningThreshold = 80.0;

  // Session cookie name
  static const String sessionCookieName = '5bd4aa82278a9392700cda732bf3f9eb';
}
