import 'package:hive/hive.dart';

part 'task_model.g.dart'; // ⬅️ Required for the generated code

@HiveType(typeId: 0)
class Task {
  @HiveField(0)
  String title;

  @HiveField(1)
  String description;

  @HiveField(2)
  DateTime dueDate;

  @HiveField(3)
  bool isCompleted;

  @HiveField(4)
  bool isSynced; // ✅ New field to track if synced with Firestore

  @HiveField(5)
  DateTime updatedAt;

  Task({
    required this.title,
    required this.description,
    required this.dueDate,
    this.isCompleted = false,
    this.isSynced = false,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();
}
