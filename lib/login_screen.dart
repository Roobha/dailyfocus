import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import '../models/task_model.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  User? user;
  final Box<Task> taskBox = Hive.box<Task>('tasks');

  Future<void> syncFirestoreToHive(User user) async {
    final uid = user.uid;
    final firestoreTasks = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('tasks')
        .get();

    for (var doc in firestoreTasks.docs) {
      final data = doc.data();

      // ✅ Safely parse dueDate
      late DateTime firestoreDueDate;
      try {
        firestoreDueDate = DateTime.parse(data['dueDate']);
      } catch (e) {
        print('❌ Invalid dueDate format in Firestore: $e');
        continue;
      }

      // ✅ Handle updatedAt (nullable fallback)
      DateTime firestoreUpdatedAt;
      try {
        firestoreUpdatedAt = data['updatedAt'] != null
            ? DateTime.parse(data['updatedAt'])
            : DateTime.now();
      } catch (e) {
        print('❌ Invalid updatedAt format in Firestore: $e');
        firestoreUpdatedAt = DateTime.now(); // fallback
      }

      final existingKey = taskBox.keys.firstWhere(
        (key) {
          final task = taskBox.get(key);
          return task != null &&
              task.title == data['title'] &&
              task.description == data['description'] &&
              task.dueDate.isAtSameMomentAs(firestoreDueDate);
        },
        orElse: () => null,
      );

      if (existingKey != null) {
        final existingTask = taskBox.get(existingKey);
        if (existingTask != null &&
            firestoreUpdatedAt.isAfter(existingTask.updatedAt)) {
          final updatedTask = Task(
            title: data['title'],
            description: data['description'],
            dueDate: firestoreDueDate,
            isCompleted: data['isCompleted'] ?? false,
            isSynced: true,
            updatedAt: firestoreUpdatedAt,
          );
          taskBox.put(existingKey, updatedTask);
        }
      } else {
        final syncedTask = Task(
          title: data['title'],
          description: data['description'],
          dueDate: firestoreDueDate,
          isCompleted: data['isCompleted'] ?? false,
          isSynced: true,
          updatedAt: firestoreUpdatedAt,
        );
        taskBox.add(syncedTask);
      }
    }
  }



  // ✅ Upload unsynced Hive tasks to Firestore
  Future<void> syncHiveToFirestore(User user) async {
    final uid = user.uid;
    final taskCollection = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('tasks');

    final unsyncedTasks = taskBox.values
        .where((task) => task.isSynced == false)
        .toList();

    for (final task in unsyncedTasks) {
      final docRef = taskCollection.doc(); // auto-id
      await docRef.set({
        'title': task.title,
        'description': task.description,
        'dueDate': task.dueDate.toIso8601String(),
        'isCompleted': task.isCompleted,
        'updatedAt': task.updatedAt.toIso8601String(),
      });

      // ✅ Mark as synced in Hive
      final key = taskBox.keys.firstWhere((k) => taskBox.get(k) == task, orElse: () => null);
      if (key != null) {
        final updatedTask = Task(
          title: task.title,
          description: task.description,
          dueDate: task.dueDate,
          isCompleted: task.isCompleted,
          isSynced: true,
          updatedAt: task.updatedAt,
        );
        taskBox.put(key, updatedTask);
      }
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);

      user = userCredential.user;

      if (user != null) {
        await syncFirestoreToHive(user!);
        await syncHiveToFirestore(user!); // ✅ Upload unsynced tasks
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      print('Login error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Sign-in failed")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/icon/dailyfocus.jpg',
                  height: 80,
                ),
                const SizedBox(height: 16),
                Text(
                  'DailyFocus',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Organize your tasks and stay focused',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: textColor.withOpacity(0.7),
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: signInWithGoogle,
                  icon: Image.asset(
                    'assets/google_logo.png',
                    height: 24,
                  ),
                  label: const Text(
                    'Sign in with Google',
                    style: TextStyle(fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 24,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 2,
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    Navigator.pushReplacementNamed(context, '/home');
                  },
                  child: const Text(
                    'Continue Offline',
                    style: TextStyle(decoration: TextDecoration.underline),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
