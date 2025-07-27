// unchanged imports
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/task_model.dart'; // ✅ Import your Task model
// import '../notifications/notification_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    syncHiveToFirestore();
  }

  /// Sync local unsynced Hive tasks → Firestore
  Future<void> syncHiveToFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final uid = user.uid;
    final tasks = taskBox.values.toList();

    for (var task in tasks) {
      if (!task.isSynced) {
        final taskRef = FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('tasks')
            .doc(_generateTaskId(task));

        final snapshot = await taskRef.get();

        if (!snapshot.exists ||
            task.updatedAt.isAfter(
                DateTime.tryParse(snapshot.data()?['updatedAt'] ?? '') ??
                    DateTime.fromMillisecondsSinceEpoch(0))) {
          await taskRef.set({
            'title': task.title,
            'description': task.description,
            'dueDate': task.dueDate.toIso8601String(),
            'isCompleted': task.isCompleted,
            'updatedAt': task.updatedAt.toIso8601String(),
          });

          // Update local task as synced
          final key = taskBox.keys.firstWhere((k) => taskBox.get(k) == task);
          final updated = Task(
            title: task.title,
            description: task.description,
            dueDate: task.dueDate,
            isCompleted: task.isCompleted,
            isSynced: true,
            updatedAt: task.updatedAt,
          );
          taskBox.put(key, updated);
        }
      }
    }
  }

  String _generateTaskId(Task task) {
    return '${task.title}_${task.dueDate.toIso8601String()}';
  }
  final taskBox = Hive.box<Task>('tasks');
  final TextEditingController _searchController = TextEditingController();
  String searchQuery = '';
  String filterStatus = 'All';
  bool sortAsc = true;

  List<Task> _filteredSortedTasks(Box<Task> box) {
    List<Task> tasks = box.values.toList();

    // Filter by status
    if (filterStatus == 'Completed') {
      tasks = tasks.where((task) => task.isCompleted).toList();
    } else if (filterStatus == 'Pending') {
      tasks = tasks.where((task) => !task.isCompleted).toList();
    }

    // Filter by search query
    if (searchQuery.isNotEmpty) {
        tasks = tasks.where((task) =>
        task.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
        task.description.toLowerCase().contains(searchQuery.toLowerCase())
        ).toList();
    }

    // Sort
    tasks.sort((a, b) => sortAsc
        ? a.dueDate.compareTo(b.dueDate)
        : b.dueDate.compareTo(a.dueDate));

    return tasks;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Todo List"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              await GoogleSignIn().signOut();
              Navigator.pushReplacementNamed(context, '/');
            },
          )
        ],
      ),
      body: Column(
        children: [
          // Filter & Sort Controls
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                DropdownButton<String>(
                  value: filterStatus,
                  items: ['All', 'Completed', 'Pending']
                      .map((status) => DropdownMenuItem(
                            value: status,
                            child: Text(status),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => filterStatus = value);
                    }
                  },
                ),
                const SizedBox(width: 16),
                TextButton.icon(
                onPressed: () {
                    setState(() => sortAsc = !sortAsc);
                },
                icon: Icon(sortAsc ? Icons.arrow_upward : Icons.arrow_downward),
                label: Text(
                    sortAsc ? 'Sort: Due Date ↑' : 'Sort: Due Date ↓',
                    style: const TextStyle(fontSize: 14),
                ),
                style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    foregroundColor: Theme.of(context).primaryColor,
                ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Search tasks...',
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                            _searchController.clear();
                            setState(() => searchQuery = '');
                        },
                        )
                    : null,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                ),
                ),
                onChanged: (value) {
                setState(() => searchQuery = value.trim());
                },
            ),
            ),
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: taskBox.listenable(),
              builder: (context, Box<Task> box, _) {
                final tasks = _filteredSortedTasks(box);

                if (tasks.isEmpty) {
                  return const Center(child: Text("No tasks found."));
                }

                return RefreshIndicator(
                onRefresh: () async {
                    await Future.delayed(const Duration(milliseconds: 500));
                    setState(() {}); // triggers rebuild
                },
                child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: tasks.length,
                    itemBuilder: (context, index) {
                    final task = tasks[index];

                    return Dismissible(
                    key: Key(task.title + task.dueDate.toIso8601String()), // ensure uniqueness
                    direction: DismissDirection.endToStart,
                    background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        color: Colors.redAccent,
                        child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    confirmDismiss: (direction) async {
                        return await showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                            title: const Text("Confirm Delete"),
                            content: const Text("Are you sure you want to delete this task?"),
                            actions: [
                            TextButton(
                                onPressed: () => Navigator.of(context).pop(false),
                                child: const Text("Cancel"),
                            ),
                            TextButton(
                                onPressed: () => Navigator.of(context).pop(true),
                                child: const Text("Delete", style: TextStyle(color: Colors.red)),
                            ),
                            ],
                        ),
                        );
                    },
                    onDismissed: (direction) {
                        final key = box.keys.firstWhere((k) => box.get(k) == task, orElse: () => null);
                        if (key != null) {
                        box.delete(key);
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Task '${task.title}' deleted")),
                        );
                        }
                    },
                    child: Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        elevation: 3,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 4, horizontal: 4),
                          leading: Checkbox(
                            value: task.isCompleted,
                            onChanged: (value) async {
                              final updatedTask = Task(
                                title: task.title,
                                description: task.description,
                                dueDate: task.dueDate,
                                isCompleted: value ?? false,
                                isSynced: false,
                                updatedAt: DateTime.now(),
                              );

                              final key = box.keys.firstWhere((k) => box.get(k) == task, orElse: () => null);
                              if (key != null) {
                                await box.put(key, updatedTask);

                                // 🔔 Cancel old and schedule new notification
                                final id = task.dueDate.millisecondsSinceEpoch ~/ 1000;
                                // await NotificationService.cancelNotification(id);
                                if (!(value ?? false)) {
                                  // await NotificationService.scheduleNotification(
                                  //   id: id,
                                  //   title: 'Task Reminder: ${task.title}',
                                  //   body: task.description,
                                  //   scheduledTime: task.dueDate.subtract(const Duration(hours: 1)),
                                  // );
                                }
                              }
                            },
                          ),
                          title: Text(
                            task.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              decoration: task.isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (task.description.isNotEmpty)
                                  Text(task.description),
                                const SizedBox(height: 4),
                                Text(
                                  "Due: ${task.dueDate.toLocal().toString().split(' ')[0]}",
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                          trailing: Wrap(
                            spacing: 4.0,
                            children: [
                              Tooltip(
                                message: 'Edit Task',
                                child: IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () {
                                    final titleController =
                                        TextEditingController(text: task.title);
                                    final descController =
                                        TextEditingController(
                                            text: task.description);
                                    DateTime selectedDate = task.dueDate;

                                    showDialog(
                                      context: context,
                                      builder: (context) {
                                        return StatefulBuilder(
                                            builder: (context, setState) {
                                          return AlertDialog(
                                            title: const Text('Edit Task'),
                                            content: SingleChildScrollView(
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  TextField(
                                                    controller: titleController,
                                                    decoration:
                                                        const InputDecoration(
                                                            labelText: 'Title'),
                                                  ),
                                                  TextField(
                                                    controller: descController,
                                                    decoration:
                                                        const InputDecoration(
                                                            labelText:
                                                                'Description'),
                                                  ),
                                                  const SizedBox(height: 10),
                                                  Row(
                                                    children: [
                                                      const Text('Due Date: '),
                                                      TextButton(
                                                        onPressed: () async {
                                                          final pickedDate =
                                                              await showDatePicker(
                                                            context: context,
                                                            initialDate:
                                                                selectedDate,
                                                            firstDate:
                                                                DateTime(2000),
                                                            lastDate:
                                                                DateTime(2100),
                                                          );
                                                          if (pickedDate !=
                                                              null) {
                                                            setState(() {
                                                              selectedDate =
                                                                  pickedDate;
                                                            });
                                                          }
                                                        },
                                                        child: Text(
                                                          "${selectedDate.toLocal()}".split(' ')[0],
                                                          style: const TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(context),
                                                child: const Text('Cancel'),
                                              ),
                                              ElevatedButton(
                                                onPressed: () async {
                                                  final updatedTask = Task(
                                                    title: titleController.text.trim(),
                                                    description: descController.text.trim(),
                                                    dueDate: selectedDate,
                                                    isCompleted: task.isCompleted,
                                                    isSynced: false,
                                                    updatedAt: DateTime.now(),
                                                  );

                                                  final key = box.keys.firstWhere((k) => box.get(k) == task, orElse: () => null);
                                                  if (key != null) {
                                                    await box.put(key, updatedTask);

                                                    // 🔔 Cancel old and schedule updated notification
                                                    final id = task.dueDate.millisecondsSinceEpoch ~/ 1000;
                                                    // await NotificationService.cancelNotification(id);
                                                    // await NotificationService.scheduleNotification(
                                                    //   id: updatedTask.dueDate.millisecondsSinceEpoch ~/ 1000,
                                                    //   title: 'Task Reminder: ${updatedTask.title}',
                                                    //   body: updatedTask.description,
                                                    //   scheduledTime: updatedTask.dueDate.subtract(const Duration(hours: 1)),
                                                    // );
                                                  }

                                                  Navigator.pop(context);
                                                },
                                                child: const Text('Save'),
                                              ),
                                            ],
                                          );
                                        });
                                      },
                                    );
                                  },
                                ),
                              ),
                              Tooltip(
                                message: 'Delete Task',
                                child: IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () async {
                                    final key = box.keys.firstWhere(
                                        (k) => box.get(k) == task,
                                        orElse: () => null);
                                    if (key != null) {
                                      // await NotificationService.cancelNotification(task.dueDate.millisecondsSinceEpoch ~/ 1000);
                                      box.delete(key);
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    );
                  },
                ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, '/add'),
        child: const Icon(Icons.add),
      ),
    );
  }
}
