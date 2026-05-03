import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'services/auth_service.dart';
import 'models/user_model.dart';
import 'utils/constants.dart';

void main() {
  runApp(const KondoKoApp());
}

class KondoKoApp extends StatelessWidget {
  const KondoKoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KondoKo Inventory',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(AppConstants.primaryColorValue),
        ),
        scaffoldBackgroundColor:
            const Color(AppConstants.backgroundColorValue),
        fontFamily: 'Roboto',
        useMaterial3: true,
      ),
      home: const SplashGate(),
    );
  }
}

/// Checks for a saved session and routes to Dashboard or Login accordingly.
class SplashGate extends StatefulWidget {
  const SplashGate({super.key});

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final token = await AuthService.getToken();
    final user  = await AuthService.getSavedUser();

    if (!mounted) return;

    if (token != null && user != null) {
  
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DashboardScreen(
            firstName: user.firstName,
            token: token,
          ),
        ),
      );
    } else {
      
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}