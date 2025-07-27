import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/task_model.dart';
// import '../notifications/notification_service.dart'; // ✅ Import

class AddTaskScreen extends StatefulWidget {
  const AddTaskScreen({super.key});

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final titleController = TextEditingController();
  final descController = TextEditingController();
  DateTime? selectedDate;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Task")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (val) => val!.isEmpty ? "Enter title" : null,
              ),
              TextFormField(
                controller: descController,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      selectedDate == null
                          ? 'No date selected'
                          : 'Due: ${selectedDate!.toLocal().toString().split(' ')[0]}',
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final now = DateTime.now();
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: now,
                        firstDate: now,
                        lastDate: DateTime(now.year + 5),
                      );
                      if (picked != null) {
                        setState(() {
                          selectedDate = picked;
                        });
                      }
                    },
                    icon: const Icon(Icons.calendar_today),
                    label: const Text('Pick Date'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  if (_formKey.currentState!.validate() &&
                      selectedDate != null) {
                    final now = DateTime.now();
                    final task = Task(
                      title: titleController.text.trim(),
                      description: descController.text.trim(),
                      dueDate: selectedDate!,
                      isCompleted: false,
                      isSynced: false,
                      updatedAt: now,
                    );

                    await Hive.box<Task>('tasks').add(task);

                    // ✅ Schedule Notification 1 hour before
                    final reminderTime =
                        task.dueDate.subtract(const Duration(hours: 1));
                    if (reminderTime.isAfter(now)) {
                      // await NotificationService.scheduleNotification(
                      //   id: now.millisecondsSinceEpoch ~/ 1000,
                      //   title: 'Task Reminder: ${task.title}',
                      //   body: task.description,
                      //   scheduledTime: reminderTime,
                      // );
                    }

                    Navigator.pop(context);
                  } else if (selectedDate == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Please select a due date"),
                      ),
                    );
                  }
                },
                child: const Text("Add Task"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
