import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
// import 'notifications/notification_service.dart'; 
import 'login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/add_task_screen.dart';
import 'firebase_options.dart';
import 'models/task_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  if (kIsWeb) {
    await Hive.initFlutter();
  } else {
    final appDocDir = await getApplicationDocumentsDirectory();
    await Hive.initFlutter(appDocDir.path);
  }

  Hive.registerAdapter(TaskAdapter());
  await Hive.openBox<Task>('tasks');

 
  // await NotificationService.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Todo App',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
      ),
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
      routes: {
        '/home': (context) => const HomeScreen(),
        '/add': (context) => const AddTaskScreen(),
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), () async {
      await handleNavigation();
    });
  }

  Future<void> handleNavigation() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final connectivityResult = await Connectivity().checkConnectivity();

      bool hasInternet = connectivityResult != ConnectivityResult.none;
      final taskBox = Hive.box<Task>('tasks');

      if (user != null && hasInternet) {
        final uid = user.uid;
        if (uid == null || uid.isEmpty) throw Exception("UID is null");

        final firestore = FirebaseFirestore.instance;
        final tasks = taskBox.values.toList();

        for (var task in tasks) {
          if (!task.isSynced) {
            await firestore
                .collection('users')
                .doc(uid)
                .collection('tasks')
                .add({
              'title': task.title,
              'description': task.description,
              'dueDate': task.dueDate.toIso8601String(),
              'isCompleted': task.isCompleted,
            });

            final key = taskBox.keys.firstWhere((k) => taskBox.get(k) == task);
            taskBox.put(
            key,
            Task(
              title: task.title,
              description: task.description,
              dueDate: task.dueDate,
              isCompleted: task.isCompleted,
              isSynced: true,
              updatedAt: task.updatedAt,
            ),
          );
          }
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } else if (user != null && !hasInternet) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    } catch (e) {
      debugPrint("Navigation error: $e");
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // You can reuse your animated logo or simple loader
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text(
              'DailyFocus',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
