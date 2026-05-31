import 'package:viecnow/screens/employer/employer_notifications_screen.dart';
import 'package:viecnow/screens/employer/employer_search_screen.dart';
import 'package:viecnow/screens/employer/employer_reviews_screen.dart';
import 'package:viecnow/screens/employer/employer_login_history_screen.dart';
import 'package:viecnow/screens/employer/employer_candidates_screen.dart';
import 'package:viecnow/screens/auth/forget_password_screen.dart';
import 'package:viecnow/screens/employer/employer_main_navigation_screen.dart';
import 'package:viecnow/screens/post/post_management_screen.dart';
import 'package:viecnow/screens/post/create_post_screen.dart';
import 'package:viecnow/screens/post/create_fulltime_post_screen.dart';
import 'package:viecnow/screens/menu_employer/employer_messages_screen.dart';
import 'package:viecnow/screens/menu_employer/attendance_tool_screen.dart';
import 'package:viecnow/screens/menu_employer/schedule_tool_screen.dart';
import 'package:viecnow/screens/menu_employer/rating_tool_screen.dart';
import 'package:viecnow/screens/menu_employer/employer_report_screen.dart';
import 'package:viecnow/screens/chat/employer_groups_screen.dart';
import 'package:viecnow/screens/chat/group_chat_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:viecnow/screens/messaging/chat_room_screen.dart';
import 'package:viecnow/data/models/group_chat_model.dart';
import 'package:viecnow/screens/chat/group_management_screen.dart';
import 'package:viecnow/screens/chat/work_schedule_screen.dart';
import 'package:viecnow/screens/chat/complaint_screen.dart';
import 'package:viecnow/screens/chat/search_messages_screen.dart';
import 'package:viecnow/screens/employer/attendance_screen.dart' as att_screen;
import 'package:viecnow/screens/employer/job_day_end_flow_screen.dart';
import 'package:viecnow/screens/employer/job_attendance_summary_screen.dart';
import 'package:viecnow/screens/attendance/candidate_attendance_screen.dart';
import 'package:viecnow/screens/candidate/candidate_job_complaint_screen.dart';
import 'package:viecnow/screens/shared/post_dissolution_complaint_screen.dart';
import 'package:viecnow/screens/shared/complaints_catalog_screen.dart';
import 'package:viecnow/screens/admin/admin_home_screen.dart';
import 'package:viecnow/screens/admin/admin_disbursement_screen.dart';
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
import 'package:viecnow/screens/search/search_screen.dart';
import 'package:viecnow/screens/search/search_results_screen.dart';
import 'package:viecnow/screens/stats/candidate_stats_screen.dart';
import 'package:viecnow/screens/profile/profile_screen.dart';
import 'package:viecnow/screens/reference/market_rate_screen.dart';
import 'package:viecnow/screens/schedule/candidate_schedule_screen.dart';
import 'package:viecnow/screens/job/job_detail_screen.dart';
import 'package:viecnow/screens/profile/change_password_screen.dart';
import 'package:viecnow/screens/profile/change_phonenumber_screen.dart';
import 'package:viecnow/screens/profile/change_username_screen.dart';
import 'package:viecnow/screens/profile/job_criteria_screen.dart';
import 'package:viecnow/screens/profile/my_profile_screen.dart';
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
  static const String search = '/search';
  static const String searchResults = '/search_results';
  static const String reference = '/reference';
  static const String jobDetail = '/job-detail';
  static const String stats = '/stats';
  static const String schedule = '/schedule';
  static const String publisher = '/publisher';
  static const String updateAccount = '/update-account';
  static const String myProfile = '/my-profile';
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
  static const String createFulltimePost = '/create-fulltime-post';
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
  static const String groupChat = '/group-chat';
  static const String groupManagement = '/group-management';
  static const String attendance = '/attendance';
  static const String candidateAttendance = '/candidate-attendance';
  static const String workSchedule = '/work-schedule';
  static const String complaint = '/complaint';
  static const String jobDayEndFlow = '/job-day-end-flow';
  static const String jobAttendanceSummary = '/job-attendance-summary';
  static const String candidateJobComplaint = '/candidate-job-complaint';
  static const String postDissolutionComplaint = '/post-dissolution-complaint';
  static const String complaintsCatalog = '/complaints-catalog';
  static const String adminHome = '/admin-home';
  static const String adminDisbursements = '/admin-disbursements';
  static const String searchMessages = '/search-messages';
  static const String employerNotifications = '/employer-notifications';
  static const String employerSearch = '/employer-search';
  static const String jobCriteria = '/job-criteria';
  static Map<String, WidgetBuilder> routes = {
    splash: (context) => const SplashScreen(),
    onboarding: (context) => const OnboardingScreen(),
    home: (context) => const MainNavigationScreen(),
    search: (context) => const SearchScreen(),
    searchResults: (context) => const SearchResultsScreen(),
    reference: (context) => const MarketRateScreen(),
    jobDetail: (context) => const JobDetailScreen(),
    stats: (context) => const CandidateStatsScreen(),
    schedule: (context) => const CandidateScheduleScreen(),
    profile: (context) => const ProfileScreen(),
    register: (context) => const RegisterScreen(),
    login: (context) => const LoginScreen(),
    forgetPassword: (context) => ForgetPasswordScreen(),
    updateAccount: (context) => const UpdateAccountScreen(),
    myProfile: (context) => const MyProfileScreen(),
    changeName: (context) => const ChangeNameScreen(),
    changeUsername: (context) => const ChangeUsernameScreen(),
    changePassword: (context) => const ChangePasswordScreen(),
    changeEmail: (context) => const ChangeEmailScreen(),
    changePhoneNumber: (context) => const ChangePhoneNumberScreen(),
    changeGender: (context) => const ChangeGenderScreen(),
    changeDateofBirth: (context) => const ChangeDateOfBirthScreen(),
    jobCriteria: (context) => const JobCriteriaScreen(),
    myShippingAddressview: (context) => MyShippingAddressScreen(),
    myBankAccountview: (context) => MyBankAccountScreen(),
    employerHome: (context) => const EmployerMainNavigationScreen(),
    postManagement: (context) => const PostManagementScreen(),
    createPost: (context) => const CreatePostScreen(initialJobType: 'part_time'),
    createFulltimePost: (context) => const CreateFulltimePostScreen(),
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
    AppRoutes.groupChat: (context) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is GroupChatModel) {
        final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
        return ChatRoomScreen(
          groupId: args.groupId,
          isEmployer: uid.isNotEmpty && uid == args.employerId,
        );
      }
      return const GroupChatScreen();
    },
    AppRoutes.groupManagement: (context) => const GroupManagementScreen(),
    AppRoutes.attendance: (context) => const att_screen.AttendanceScreen(),
    AppRoutes.candidateAttendance: (context) =>
        const CandidateAttendanceScreen(),
    AppRoutes.workSchedule: (context) => const WorkScheduleScreen(),
    AppRoutes.complaint: (context) => const ComplaintScreen(),
    AppRoutes.jobDayEndFlow: (context) => const JobDayEndFlowScreen(),
    AppRoutes.jobAttendanceSummary: (context) =>
        const JobAttendanceSummaryScreen(),
    AppRoutes.candidateJobComplaint: (context) =>
        const CandidateJobComplaintScreen(),
    AppRoutes.postDissolutionComplaint: (context) =>
        const PostDissolutionComplaintScreen(),
    AppRoutes.complaintsCatalog: (context) => const ComplaintsCatalogScreen(),
    AppRoutes.adminHome: (context) => const AdminHomeScreen(),
    AppRoutes.adminDisbursements: (context) => const AdminDisbursementScreen(),
    AppRoutes.searchMessages: (context) => const SearchMessagesScreen(),
    AppRoutes.employerNotifications: (context) =>
        const EmployerNotificationsScreen(),
    AppRoutes.employerSearch: (context) => const EmployerSearchScreen(),
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
