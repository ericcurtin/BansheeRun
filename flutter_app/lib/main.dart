import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/main_tracking_screen.dart';
import 'screens/activity_list_screen.dart';
import 'screens/personal_bests_screen.dart';
import 'services/haptic_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style for immersive dark theme
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.darkBackground,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize haptic service
  await HapticService.instance.initialize();

  runApp(const BansheeRunApp());
}

class BansheeRunApp extends StatelessWidget {
  const BansheeRunApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BansheeRun',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/': (context) => const MainTrackingScreen(),
        '/activities': (context) => const ActivityListScreen(),
        '/personal-bests': (context) => const PersonalBestsScreen(),
      },
      onGenerateRoute: (settings) {
        // Handle any routes that need arguments
        if (settings.name == '/activity-detail') {
          // Could return ActivityDetailScreen with settings.arguments
          return MaterialPageRoute(
            builder: (context) => const MainTrackingScreen(),
          );
        }
        return null;
      },
    );
  }
}
