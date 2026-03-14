import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit/media_kit.dart';

import 'config/theme.dart';
import 'services/local_notification_service.dart';
import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/diet_screen.dart';
import 'screens/community_screen.dart';
import 'screens/leaderboard_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/workout_screen.dart';
import 'screens/trainer/trainer_home_screen.dart';
import 'screens/trainer/trainer_dashboard_screen.dart';
import 'screens/trainer/trainer_workouts_screen.dart';
import 'screens/trainer/trainer_schedule_screen.dart';
import 'screens/trainer/trainer_settings_screen.dart';
import 'screens/trainer/trainer_courses_screen.dart';
import 'screens/owner/owner_home_screen.dart';
import 'screens/owner/owner_dashboard_screen.dart';
import 'screens/owner/owner_crm_screen.dart';
import 'screens/owner/owner_facilities_screen.dart';
import 'screens/owner/owner_settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await LocalNotificationService().init();
  runApp(const ProviderScope(child: GymApp()));
}

class GymApp extends ConsumerWidget {
  const GymApp({super.key});

  static String _homeForRole(String? role) {
    if (role == 'trainer') return '/trainer';
    if (role == 'owner') return '/owner';
    return '/home';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    final router = GoRouter(
      initialLocation: '/login',
      redirect: (context, state) {
        final isAuth = authState.status == AuthStatus.authenticated;
        final isAuthRoute = state.matchedLocation == '/login' ||
            state.matchedLocation == '/register';

        if (authState.status == AuthStatus.initial ||
            authState.status == AuthStatus.loading) {
          return null;
        }

        if (!isAuth && !isAuthRoute) return '/login';

        if (isAuth && isAuthRoute) {
          return _homeForRole(authState.user?.role);
        }

        return null;
      },
      routes: [
        GoRoute(
          path: '/',
          redirect: (_, __) => _homeForRole(authState.user?.role),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/register',
          builder: (context, state) => const RegisterScreen(),
        ),
        GoRoute(
          path: '/leaderboard',
          builder: (context, state) => const LeaderboardScreen(),
        ),
        GoRoute(
          path: '/workouts',
          builder: (context, state) => WorkoutScreen(
            coopPartnerId: state.uri.queryParameters['partner_id'],
            coopPartnerName: state.uri.queryParameters['partner_name'],
            coopPartnerPicture: state.uri.queryParameters['partner_picture'],
          ),
        ),

        // ── Client Shell ───────────────────────────────
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return HomeScreen(navigationShell: navigationShell);
          },
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/home',
                  builder: (context, state) => const DashboardScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/diet',
                  builder: (context, state) => const DietScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/community',
                  builder: (context, state) => const CommunityScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/profile',
                  builder: (context, state) => const ProfileScreen(),
                ),
              ],
            ),
          ],
        ),

        GoRoute(
          path: '/trainer/active-workout',
          builder: (context, state) => WorkoutScreen(
            isTrainer: true,
            initialWorkout: state.extra as Map<String, dynamic>?,
          ),
        ),

        // ── Owner Shell ───────────────────────────────
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return OwnerHomeScreen(navigationShell: navigationShell);
          },
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/owner',
                  builder: (context, state) => const OwnerDashboardScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/owner/crm',
                  builder: (context, state) => const OwnerCrmScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/owner/facilities',
                  builder: (context, state) => const OwnerFacilitiesScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/owner/settings',
                  builder: (context, state) => const OwnerSettingsScreen(),
                ),
              ],
            ),
          ],
        ),

        // ── Trainer Shell ──────────────────────────────
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return TrainerHomeScreen(navigationShell: navigationShell);
          },
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/trainer',
                  builder: (context, state) => const TrainerDashboardScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/trainer/workouts',
                  builder: (context, state) => const TrainerWorkoutsScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/trainer/courses',
                  builder: (context, state) => const TrainerCoursesScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/trainer/schedule',
                  builder: (context, state) => const TrainerScheduleScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/trainer/settings',
                  builder: (context, state) => const TrainerSettingsScreen(),
                ),
              ],
            ),
          ],
        ),
      ],
    );

    return MaterialApp.router(
      title: 'Antigravity Gym',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: router,
      scrollBehavior: const _AppScrollBehavior(),
    );
  }
}

class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };
}
