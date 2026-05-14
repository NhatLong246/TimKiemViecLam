import 'package:viecnow/screens/employer/employer_reviews_screen.dart';
import 'package:viecnow/screens/employer/employer_login_history_screen.dart';
import 'package:viecnow/screens/employer/employer_candidates_screen.dart';
import 'package:viecnow/screens/auth/forget_password_screen.dart';
import 'package:viecnow/screens/employer/employer_main_navigation_screen.dart';
import 'package:viecnow/screens/post/post_management_screen.dart';
import 'package:viecnow/screens/post/create_post_screen.dart';
import 'package:viecnow/screens/menu_employer/employer_menu_screen.dart';
import 'package:viecnow/screens/menu_employer/employer_messages_screen.dart';
import 'package:viecnow/screens/menu_employer/attendance_tool_screen.dart';
import 'package:viecnow/screens/menu_employer/schedule_tool_screen.dart';
import 'package:viecnow/screens/menu_employer/rating_tool_screen.dart';
import 'package:viecnow/screens/menu_employer/employer_report_screen.dart';
import 'package:viecnow/screens/menu_employer/employer_groups_screen.dart';
import 'package:viecnow/screens/menu_employer/employer_wallet_screen.dart';
import 'package:viecnow/screens/reference/employer_market_rate_screen.dart';
import 'package:viecnow/screens/stats/employer_stats_screen.dart';
import 'package:viecnow/screens/auth/login_screen.dart';
import 'package:viecnow/screens/auth/register_screen.dart';
import 'package:viecnow/screens/auth/register_success_screen.dart';
import 'package:viecnow/screens/auth/reset_email_sent_screen.dart';
import 'package:viecnow/screens/auth/verify_email_screen.dart';
import 'package:viecnow/screens/bank_account/my_bank_account_screen.dart';
import 'package:viecnow/screens/onboarding/onboarding_screen.dart';
import 'package:viecnow/screens/profile/change_dateofbirth_screen.dart';
import 'package:viecnow/screens/profile/change_email_screen.dart';
import 'package:viecnow/screens/profile/change_gender_screen.dart';
import 'package:viecnow/screens/profile/change_name_screen.dart';

// import 'package:app_vlxd/screens/profile/change_password_screen.dart';
import 'package:viecnow/screens/profile/change_phonenumber_screen.dart';
import 'package:viecnow/screens/profile/change_username_screen.dart';
import 'package:viecnow/screens/profile/update_account_screen.dart';
import 'package:viecnow/screens/shipping_address/my_shipping_address_screen.dart';
import 'package:flutter/material.dart';
import '../screens/home/main_navigation_screen.dart';
import '../screens/spalsh/splash_screen.dart';

class AppRoutes {
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String forgetPassword = '/forget-password';
  static const String resetEmailSent = '/reset-email-sent';
  static const String register = '/register';
  static const String verifyEmail = '/verify-email';
  static const String registerSuccess = '/register-success';
  static const String home = '/home';
  static const String profile = '/profile';
  static const String publisher = '/publisher';
  static const String updateAccount = '/update-account';
  static const String changeName = '/change-name';
  static const String changeUsername = '/change-username';
  static const String changePassword = '/change-password';
  static const String changeEmail = '/change-email';
  static const String changePhoneNumber = '/change-phonenumber';
  static const String changeGender = '/change-gender';
  static const String changeDateofBirth = '/change-datebirth';
  static const String cartOverview = '/cart-overview';
  static const String orderOverview = '/order-overview';
  static const String myOrderview = '/my-order';
  static const String myShippingAddressview = '/my_shipping_address';
  static const String myBankAccountview = '/my_bank_account';
  static const String employerHome = '/employer-home';
  static const String postManagement = '/post-management';
  static const String createPost = '/create-post';
  static const String employerMessages = '/employer-messages';
  static const String attendanceTool = '/attendance-tool';
  static const String scheduleTool = '/schedule-tool';
  static const String ratingTool = '/rating-tool';
  static const String employerReport = '/employer-report';
  static const String employerGroups = '/employer-groups';
  static const String employerWallet = '/employer-wallet';
  static const String employerReference = '/employer-reference';
  static const String employerStats = '/employer-stats';
  static const String employerReviews = '/employer-reviews';
  static const String employerLoginHistory = '/employer-login-history';
  static const String employerCandidates = '/employer-candidates';
  static Map<String, WidgetBuilder> routes = {
    splash: (context) => const SplashScreen(),
    onboarding: (context) => const OnboardingScreen(),
    home: (context) => const MainNavigationScreen(),
    register: (context) => const RegisterScreen(),
    login: (context) => const LoginScreen(),
    forgetPassword: (context) => ForgetPasswordScreen(),
    forgetPassword: (context) => ForgetPasswordScreen(),
    home: (context) => const MainNavigationScreen(),
    updateAccount: (context) => const UpdateAccountScreen(),
    changeName: (context) => const ChangeNameScreen(),
    changeUsername: (context) => const ChangeUsernameScreen(),
    // changePassword: (context) => const ChangePasswordScreen(),
    changeEmail: (context) => const ChangeEmailScreen(),
    changePhoneNumber: (context) => const ChangePhoneNumberScreen(),
    changeGender: (context) => const ChangeGenderScreen(),
    changeDateofBirth: (context) => const ChangeDateOfBirthScreen(),
    myShippingAddressview: (context) => MyShippingAddressScreen(),
    myBankAccountview: (context) => MyBankAccountScreen(),
    employerHome: (context) => const EmployerMainNavigationScreen(),
    postManagement: (context) => const PostManagementScreen(),
    createPost: (context) => const CreatePostScreen(),
    employerMessages: (context) => const EmployerMessagesScreen(),
    attendanceTool: (context) => const AttendanceToolScreen(),
    scheduleTool: (context) => const ScheduleToolScreen(),
    ratingTool: (context) => const RatingToolScreen(),
    employerReport: (context) => const EmployerReportScreen(),
    employerGroups: (context) => const EmployerGroupsScreen(),
    employerWallet: (context) => const EmployerWalletScreen(),
    employerReference: (context) => const EmployerMarketRateScreen(),
    employerStats: (context) => const EmployerStatsScreen(),
    employerReviews: (context) => const EmployerReviewsScreen(),
    employerLoginHistory: (context) => const EmployerLoginHistoryScreen(),
    employerCandidates: (context) => const EmployerCandidatesScreen(),
    verifyEmail: (context) {
      final args = ModalRoute.of(context)!.settings.arguments;
      String email = '';
      String role = 'candidate';
      if (args is Map) {
        email = args['email'] as String? ?? '';
        role = args['role'] as String? ?? 'candidate';
      } else if (args is String) {
        email = args;
      }
      return VerifyEmailScreen(email: email, role: role);
    },
    registerSuccess: (context) => const RegisterSuccessScreen(),
    resetEmailSent: (context) {
      final email = ModalRoute.of(context)!.settings.arguments as String;
      return ResetEmailSentScreen(email: email);
    },
  };
}
