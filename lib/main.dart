import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'providers/project_provider.dart';
import 'providers/bill_provider.dart';
import 'providers/auth_provider.dart';
import 'screens/home_screen.dart';
import 'screens/sign_in_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('projects');
  await Hive.openBox('bills');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ProjectProvider()),
        ChangeNotifierProvider(create: (_) => BillProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: MaterialApp(
        title: 'Rotaract Expense Report',
        theme: ThemeData(colorSchemeSeed: Colors.deepOrange, useMaterial3: true),
        home: Consumer<AuthProvider>(
          builder: (context, auth, _) {
            return auth.isSignedIn ? const HomeScreen() : const SignInScreen();
          },
        ),
      ),
    );
  }
}