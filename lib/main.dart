import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:roommate/subpages/createnew.dart';
import 'package:roommate/findroommate.dart';
import 'package:roommate/findroom.dart';
import 'package:roommate/login.dart';
import 'package:roommate/profile.dart';
import 'package:roommate/subpages/notifications.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Roommate',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      initialRoute: '/profile',
      routes: {
        '/login': (context) => LoginPage(),
        '/profile': (context) => const ProfilePage(),
        '/findroommate': (context) => const FindRoommatePage(),
        '/findroom': (context) => const FindRoomPage(),
        '/create': (context) => const CreateNewPostPage(),
        '/notifications': (context) => const NotificationsPage(),
      },
    );
  }
}
