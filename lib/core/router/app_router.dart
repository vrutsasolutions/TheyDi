import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';
import 'package:theydi/core/router/app_routes.dart';
import 'package:theydi/features/auth/screens/splash_screen.dart';
import 'package:theydi/features/auth/screens/login_screen.dart';
import 'package:theydi/features/events/models/event_model.dart';
import 'package:theydi/features/auth/models/signup_data.dart';
import 'package:theydi/features/auth/screens/signup_step1_screen.dart';
import 'package:theydi/features/auth/screens/signup_otp_screen.dart';
import 'package:theydi/features/auth/screens/signup_step2_screen.dart';
import 'package:theydi/features/auth/screens/signup_step3_screen.dart';
import 'package:theydi/features/auth/screens/signup_step4_screen.dart';
import 'package:theydi/features/auth/screens/signup_step5_screen.dart';
import 'package:theydi/features/auth/screens/forgot_password_screen.dart';
import 'package:theydi/core/router/deep_link_handlers.dart';
import 'package:theydi/features/events/screens/create_event_screen.dart';
import 'package:theydi/shared/widgets/main_shell.dart';
import 'package:theydi/features/home/screens/home_screen.dart';
import 'package:theydi/features/profile/screens/profile_screen.dart';
import 'package:theydi/features/profile/screens/verify_profile_screen.dart';
import 'package:theydi/features/profile/screens/personal_details_screen.dart';

import 'package:theydi/features/explore/screens/explore_screen.dart';
import 'package:theydi/features/events/screens/my_events_screen.dart';
import 'package:theydi/features/events/screens/event_detail_screen.dart';
import 'package:theydi/features/profile/screens/edit_profile_screen.dart';
import 'package:theydi/features/events/screens/payment_screen.dart';
import 'package:theydi/features/events/screens/payment_success_screen.dart';
import 'package:theydi/features/events/screens/payment_history_screen.dart';
import 'package:theydi/features/notifications/screens/notifications_screen.dart';
import 'package:theydi/features/settings/screens/privacy_safety_screen.dart';
import 'package:theydi/features/settings/screens/help_support_screen.dart';
import 'package:theydi/features/reviews/screens/submit_review_screen.dart';
import 'package:theydi/features/reviews/screens/my_reviews_screen.dart';
import 'package:theydi/features/host/screens/host_dashboard_screen.dart';
import 'package:theydi/features/circles/screens/circles_list_screen.dart';
import 'package:theydi/features/circles/screens/create_circle_screen.dart';
import 'package:theydi/features/circles/screens/circle_chat_screen.dart';
import 'package:theydi/features/circles/models/circle_model.dart';
import 'package:theydi/features/events/screens/host_manage_screen.dart';
import 'package:theydi/features/search/screens/search_screen.dart';
import 'package:theydi/features/events/screens/attendees_screen.dart';
import 'package:theydi/features/profile/screens/friend_requests_screen.dart';
import 'package:theydi/features/circles/screens/dm_chat_screen.dart';
import 'package:theydi/features/profile/screens/user_profile_screen.dart';
import 'package:theydi/features/circles/screens/circle_info_screen.dart';
import 'package:theydi/features/profile/screens/friend_info_screen.dart';
import 'package:theydi/features/profile/screens/friends_hub_screen.dart';
import 'package:theydi/features/profile/screens/circle_discovery_screen.dart';
import 'package:theydi/features/settings/screens/settings_screen.dart';
import 'package:theydi/features/settings/screens/blocked_users_screen.dart';
import 'package:theydi/features/settings/screens/report_problem_screen.dart';
import 'package:theydi/features/settings/screens/submit_report_screen.dart';
import 'package:theydi/features/auth/screens/face_verification_screen.dart';
import 'package:theydi/features/support/screens/darla_chat_screen.dart';
import '../../features/settings/screens/privacy_policy_screen.dart';
import '../../features/settings/screens/terms_conditions_screen.dart';

import '../../features/admin/screens/admin_verification_screen.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

final appRouterProvider = Provider<GoRouter>((ref) {
  // Routes that require the user to be signed in
  const protectedRoutes = [
    AppRoutes.home,
    AppRoutes.explore,
    AppRoutes.myEvents,
    AppRoutes.profile,
    AppRoutes.editprofile,
    AppRoutes.verifyProfile,
    AppRoutes.personalDetails,
    AppRoutes.createEvent,
    AppRoutes.hostDashboard,
    AppRoutes.circles,
  ];

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,

    // ── Catches unmatched/failed routes so a bad or stale share link
    // shows a real screen instead of a blank white page. ──
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                "This page isn't available",
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '${state.error}',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => context.go(AppRoutes.splash),
                child: const Text('Go to Home'),
              ),
            ],
          ),
        ),
      ),
    ),

    redirect: (context, state) {
      final user = FirebaseAuth.instance.currentUser;
      final isLoggedIn = user != null;
      final path = state.matchedLocation;

      // Auth-only pages (exact match — '/' would break startsWith)
      final isOnAuthPage = path == AppRoutes.splash ||
          path == AppRoutes.login ||
          path.startsWith('/signup');

      // If logged in and on an auth-only page, go home
      if (isLoggedIn && isOnAuthPage) {
        return AppRoutes.home;
      }

      // If not logged in and trying to access a protected page, go to login
      if (!isLoggedIn && protectedRoutes.any((r) => path.startsWith(r))) {
        return AppRoutes.login;
      }

      return null; // no redirect needed
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.blockedUsers,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const BlockedUsersScreen(),
      ),
      GoRoute(
        path: AppRoutes.reportProblem,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const SubmitReportScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),

      // ── Deep Links ──
      GoRoute(
        path: '/event/:id',
        builder: (context, state) {
          if (state.extra != null && state.extra is EventModel) {
            return EventDetailScreen(event: state.extra as EventModel);
          }
          final eventId = state.pathParameters['id']!;
          return DeepLinkEventScreen(eventId: eventId);
        },
      ),
      GoRoute(
        path: '/circle/:id',
        builder: (context, state) {
          final circleId = state.pathParameters['id']!;
          return DeepLinkCircleScreen(circleId: circleId);
        },
      ),
      GoRoute(
        path: '/user/:id',
        builder: (context, state) {
          final userId = state.pathParameters['id']!;
          return UserProfileScreen(uid: userId);
        },
      ),

      GoRoute(
        path: AppRoutes.privacyPolicy,
        builder: (_, __) => const PrivacyPolicyScreen(),
      ),

      GoRoute(
        path: AppRoutes.termsConditions,
        builder: (_, __) => const TermsConditionsScreen(),
      ),

      // ── Payment ─
      GoRoute(
        path: AppRoutes.payment,
        builder: (context, state) {
          final extra = state.extra;
          if (extra is Map<String, dynamic>) {
            return PaymentScreen(
              event: extra['event'] as EventModel,
              fromApproval: (extra['fromApproval'] as bool?) ?? false,
            );
          }
          if (extra is EventModel) {
            return PaymentScreen(event: extra, fromApproval: false);
          }
          return const Scaffold(
            body: Center(child: Text('Event details missing')),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.paymentsuccess,
        builder: (context, state) {
          final data = state.extra as Map<String, dynamic>?;
          if (data == null) {
            return const Scaffold(
              body: Center(child: Text('Payment details missing')),
            );
          }
          return PaymentSuccessScreen(
            eventTitle: (data['eventTitle'] as String?) ?? '',
            amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
            transactionId: (data['transactionId'] as String?) ?? '',
            dateTime: (data['dateTime'] as DateTime?) ?? DateTime.now(),
            venue: (data['venue'] as String?) ?? '',
          );
        },
      ),
      GoRoute(
        path: AppRoutes.paymenthistory,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const PaymentHistoryScreen(),
      ),
      GoRoute(
        path: AppRoutes.notifications,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: AppRoutes.privacySafety,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const PrivacySafetyScreen(),
      ),
      GoRoute(
        path: AppRoutes.helpSupport,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const HelpSupportScreen(),
      ),
      GoRoute(
        path: AppRoutes.submitReview,
        builder: (context, state) {
          final event = state.extra as EventModel?;
          if (event == null) {
            return const Scaffold(
              body: Center(child: Text('Event missing')),
            );
          }
          return SubmitReviewScreen(event: event);
        },
      ),
      GoRoute(
        path: AppRoutes.myReviews,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const MyReviewsScreen(),
      ),
      GoRoute(
        path: AppRoutes.hostDashboard,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const HostDashboardScreen(),
      ),

      GoRoute(
        path: AppRoutes.createCircle,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const CreateCircleScreen(),
      ),
      GoRoute(
        path: AppRoutes.circleChat,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final circle = state.extra as CircleModel?;
          if (circle == null) {
            return const Scaffold(
              body: Center(child: Text('Circle not found')),
            );
          }
          return CircleChatScreen(circle: circle);
        },
      ),
      GoRoute(
        path: AppRoutes.hostManage,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final eventId = state.extra as String?;
          if (eventId == null || eventId.isEmpty) {
            return const Scaffold(
              body: Center(child: Text('Event ID missing')),
            );
          }
          return HostManageScreen(eventId: eventId);
        },
      ),
      GoRoute(
        path: AppRoutes.eventAttendees,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final event = state.extra as EventModel;
          return AttendeesScreen(event: event);
        },
      ),
      GoRoute(
        path: AppRoutes.friendRequests,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const FriendRequestsScreen(),
      ),
      GoRoute(
        path: AppRoutes.dmChat,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final data = state.extra as Map<String, dynamic>;
          return DmChatScreen(
            otherUid: data['otherUid'] as String,
            otherName: data['otherName'] as String,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.userProfile,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final data = state.extra as Map<String, dynamic>;
          return UserProfileScreen(
            uid: data['uid'] as String,
            requestId: data['requestId'] as String?,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.circleInfo,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final circle = state.extra as CircleModel?;
          if (circle == null) {
            return const Scaffold(
              body: Center(child: Text('Circle not found')),
            );
          }
          return CircleInfoScreen(circle: circle);
        },
      ),
      GoRoute(
        path: AppRoutes.friendInfo,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final data = state.extra as Map<String, dynamic>;
          return FriendInfoScreen(
            uid: data['uid'] as String,
            displayName: data['displayName'] as String,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.search,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const SearchScreen(),
      ),
      GoRoute(
        path: AppRoutes.friendsHub,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final extra = state.extra;
          final initialTab = extra is Map<String, dynamic>
              ? (extra['initialTab'] as int? ?? 0)
              : 0;
          return FriendsHubScreen(initialTab: initialTab);
        },
      ),
      GoRoute(
        path: AppRoutes.reportHistory,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ReportProblemScreen(),
      ),
      GoRoute(
        path: AppRoutes.circleDiscovery,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final extra = state.extra;
          final initialTab = extra is Map<String, dynamic>
              ? (extra['initialTab'] as int? ?? 0)
              : 0;
          return CircleDiscoveryScreen(initialTab: initialTab);
        },
      ),
      GoRoute(
        path: AppRoutes.settings,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const SettingsScreen(),
      ),

      // ── Signup flow: 1 → otp → 2 → 3 → 4 → 5 ──────────────────────────────
      GoRoute(
        path: AppRoutes.signupStep1,
        builder: (context, state) => const SignupStep1Screen(),
      ),
      GoRoute(
        path: AppRoutes.signupOtp,
        builder: (context, state) => SignupOtpScreen(
          signupData: (state.extra as SignupData?) ??
              SignupData(name: '', email: '', password: ''),
        ),
      ),
      GoRoute(
        path: AppRoutes.signupStep2,
        builder: (context, state) => SignupStep2Screen(
          signupData: (state.extra as SignupData?) ??
              SignupData(name: '', email: '', password: ''),
        ),
      ),
      GoRoute(
        path: AppRoutes.signupStep3,
        builder: (context, state) => SignupStep3Screen(
          signupData: (state.extra as SignupData?) ??
              SignupData(name: '', email: '', password: ''),
        ),
      ),
      GoRoute(
        path: AppRoutes.signupStep4, // Face Verify
        builder: (context, state) {
          final extra = state.extra;
          if (extra is Map<String, dynamic> && extra['fromProfile'] == true) {
            return const SignupStep4Screen(fromProfile: true);
          }
          if (extra is SignupData) {
            return SignupStep4Screen(signupData: extra);
          }
          return const SignupStep4Screen();
        },
      ),
      GoRoute(
        path: AppRoutes.signupStep5, // Review & Complete
        builder: (context, state) => SignupStep5Screen(
          signupData: (state.extra as SignupData?) ??
              SignupData(name: '', email: '', password: ''),
        ),
      ),

      GoRoute(
        path: AppRoutes.verifyProfile,
        builder: (context, state) => const VerifyProfileScreen(),
      ),

      GoRoute(
        path: AppRoutes.adminVerification,
        builder: (context, state) => const AdminVerificationScreen(),
      ),

      GoRoute(
        path: AppRoutes.darlaChat,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const DarlaChatScreen(),
      ),

      GoRoute(
        path: AppRoutes.faceVerification,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return FaceVerificationScreen(
            userId: extra['userId'] as String,
            onComplete: () {},
          );
        },
      ),

      // ── Top-level routes (outside ShellRoute so URL updates correctly on web) ──
      GoRoute(
        path: AppRoutes.editprofile,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.personalDetails,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const PersonalDetailsScreen(),
      ),
      GoRoute(
        path: AppRoutes.createEvent,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const CreateEventScreen(),
      ),


      // ── Shell routes (StatefulShellRoute keeps bottom nav + correct web URLs) ──
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.explore,
                builder: (context, state) => const ExploreScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.myEvents,
                builder: (context, state) {
                  final args = state.extra as Map<String, dynamic>?;
                  return MyEventsScreen(
                    initialTab: args?['tab'] as int? ?? 0,
                    initialFilter: args?['filter'] as String? ?? 'All',
                  );
                },
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.circles,
                builder: (context, state) {
                  final initialTab =
                      int.tryParse(state.uri.queryParameters['tab'] ?? '0') ?? 0;
                  debugPrint('Tab from URL = $initialTab');
                  return CirclesListScreen(
                    initialTab: initialTab,
                  );
                },
              ),
            ],
          ),
        ],
      ),
    ],
  );
});