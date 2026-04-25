import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart'; // ← 新增
import 'providers/language_provider.dart';
import 'providers/user_provider.dart';
import 'pages/auth/login_page.dart';
import 'pages/teacher/teacher_home.dart';
import 'pages/student/student_home.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized(); // ← 新增
  await Firebase.initializeApp(); // ← 新增：Android 自動讀 google-services.json

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()..loadUser()),
      ],
      child: const EduLiveApp(),
    ),
  );
}

class EduLiveApp extends StatelessWidget {
  const EduLiveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, lang, child) {
        return MaterialApp(
          title: 'EduLive+',
          debugShowCheckedModeBanner: false, 
          
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light, 
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF6366F1), 
              surface: const Color(0xFFF4F7FE),
              brightness: Brightness.light, 
            ),
            scaffoldBackgroundColor: const Color(0xFFF4F7FE),
            
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.transparent,
              elevation: 0,
              centerTitle: false,
              titleTextStyle: TextStyle(color: Color(0xFF1E293B), fontSize: 24, fontWeight: FontWeight.w700),
              iconTheme: IconThemeData(color: Color(0xFF1E293B)),
            ),

            cardTheme: CardThemeData(
              elevation: 0,
              color: Colors.white,
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.withValues(alpha: 0.1), width: 1),
              ),
            ),

            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
              ),
              labelStyle: const TextStyle(color: Colors.grey),
            ),

            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                elevation: 2,
                shadowColor: const Color(0xFF6366F1).withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            
            dialogTheme: const DialogThemeData(
              backgroundColor: Colors.white,
              titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
              contentTextStyle: TextStyle(fontSize: 16, color: Colors.black87),
            ),
          ),
          
          routes: {
            '/login': (context) => const LoginPage(),
            '/teacher': (context) => const TeacherHomePage(),
            '/student': (context) => const StudentHomePage(),
          },
          home: const LoginPage(),
        );
      },
    );
  }
}