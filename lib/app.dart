import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/shared/theme/app_theme.dart';
import 'features/shared/providers/providers.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/shared/widgets/main_screen.dart';

class WorkoutApp extends ConsumerWidget {
  const WorkoutApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeColor = ref.watch(displayAccentProvider);
    final brightness = ref.watch(themeBrightnessProvider);
    return MaterialApp(
      title: 'Workout',
      theme: buildAppTheme(accentColor: themeColor, brightness: brightness),
      debugShowCheckedModeBanner: false,
      home: const AuthGate(),
    );
  }
}

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    return authState.when(
      data: (user) => user != null ? const MainScreen() : const OnboardingScreen(),
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const OnboardingScreen(),
    );
  }
}
