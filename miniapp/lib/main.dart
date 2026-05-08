import 'package:flutter/material.dart';
import 'auth_state.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const CustomerApp());
}

class CustomerApp extends StatelessWidget {
  const CustomerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '青青旅拍',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF006B7D)),
      ),
      home: const _AuthWrapper(),
    );
  }
}

class _AuthWrapper extends StatefulWidget {
  const _AuthWrapper();

  @override
  State<_AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<_AuthWrapper> {
  bool _restoring = true;
  bool _loggedIn = false;

  @override
  void initState() {
    super.initState();
    _tryRestore();
  }

  Future<void> _tryRestore() async {
    final restored = await customerAuth.restore();
    if (!mounted) return;
    setState(() {
      _restoring = false;
      _loggedIn = restored && customerAuth.isLoggedIn;
    });
  }

  void _onLoginSuccess() {
    setState(() => _loggedIn = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_restoring) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (!_loggedIn) {
      return LoginScreen(onLoginSuccess: _onLoginSuccess);
    }
    return const HomeScreen();
  }
}
