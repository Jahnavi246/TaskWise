import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => TaskStore()..load(),
      child: const TaskWiseApp(),
    ),
  );
}

class TaskWiseApp extends StatelessWidget {
  const TaskWiseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TaskWise',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3B82F6), // TaskWise Primary Blue
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

// ==================== 1. TASK MODEL ====================
class TaskItem {
  final String title;
  final String deadline;
  final String difficulty; // Easy, Medium, Hard
  bool isDone;

  TaskItem({
    required this.title,
    required this.deadline,
    required this.difficulty,
    this.isDone = false,
  });

  factory TaskItem.fromJson(Map<String, dynamic> json) {
    return TaskItem(
      title: json['title'] as String? ?? '',
      deadline: json['deadline'] as String? ?? '',
      difficulty: json['difficulty'] as String? ?? 'Medium',
      isDone: json['isDone'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'deadline': deadline,
    'difficulty': difficulty,
    'isDone': isDone,
  };
}

// ==================== 2. SERVICE (LOCAL STORAGE) ====================
class TaskService {
  Future<List<TaskItem>> fetchAll() async {
    final prefs = await SharedPreferences.getInstance();
    final text = prefs.getString('taskwise_tasks');
    if (text == null) return [];
    final data = jsonDecode(text) as List;
    return data.map((j) => TaskItem.fromJson(j)).toList();
  }

  Future<void> saveAll(List<TaskItem> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    final list = tasks.map((t) => t.toJson()).toList();
    await prefs.setString('taskwise_tasks', jsonEncode(list));
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('taskwise_tasks');
  }

  Future<bool> getNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('notifications_enabled') ?? true;
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', enabled);
  }
}

// ==================== 3. STORE (STATE MANAGEMENT) ====================
class TaskStore extends ChangeNotifier {
  final service = TaskService();
  List<TaskItem> items = [];
  bool loading = false;
  String? error;
  bool notificationsEnabled = true;

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      items = await service.fetchAll();
      notificationsEnabled = await service.getNotificationsEnabled();
    } catch (e) {
      error = 'Could not load your tasks';
    }
    loading = false;
    notifyListeners();
  }

  void add(TaskItem task) {
    items.insert(0, task);
    notifyListeners();
    service.saveAll(items);
  }

  void toggleTaskStatus(int index) {
    items[index].isDone = !items[index].isDone;
    notifyListeners();
    service.saveAll(items);
  }

  Future<void> clearData() async {
    items.clear();
    await service.clearAll();
    notifyListeners();
  }

  Future<void> toggleNotifications(bool value) async {
    notificationsEnabled = value;
    notifyListeners();
    await service.setNotificationsEnabled(value);
  }
}

// ==================== 4. ERROR WIDGET ====================
class ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const ErrorView({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== 5. HOME / DASHBOARD SCREEN ====================
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<TaskStore>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('TaskWise — Tasks'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: buildBody(context, store),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Add Task'),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddTaskScreen(),
            ),
          );
        },
      ),
    );
  }

  Widget buildBody(BuildContext context, TaskStore store) {
    // State 1: Loading
    if (store.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    // State 2: Error
    if (store.error != null) {
      return ErrorView(
        message: store.error!,
        onRetry: () => context.read<TaskStore>().load(),
      );
    }

    // State 3: Empty
    if (store.items.isEmpty) {
      return const Center(
        child: Text(
          'No tasks added yet!\nTap + Add Task to create one.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      );
    }

    // State 4: Success / List View
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: store.items.length,
      itemBuilder: (context, index) {
        final task = store.items[index];
        return Card(
          elevation: 1.5,
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: ListTile(
            leading: Checkbox(
              value: task.isDone,
              onChanged: (_) {
                context.read<TaskStore>().toggleTaskStatus(index);
              },
            ),
            title: Text(
              task.title,
              style: TextStyle(
                decoration: task.isDone
                    ? TextDecoration.lineThrough
                    : TextDecoration.none,
              ),
            ),
            subtitle: Text('Due: ${task.deadline}'),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _getDifficultyColor(task.difficulty).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                task.difficulty,
                style: TextStyle(
                  color: _getDifficultyColor(task.difficulty),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty) {
      case 'Easy':
        return Colors.green;
      case 'Hard':
        return Colors.red;
      case 'Medium':
      default:
        return Colors.orange;
    }
  }
}

// ==================== 6. ADD TASK SCREEN ====================
class AddTaskScreen extends StatefulWidget {
  const AddTaskScreen({super.key});

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final formKey = GlobalKey<FormState>();
  final titleController = TextEditingController();
  final deadlineController = TextEditingController();
  String selectedDifficulty = 'Medium';

  @override
  void dispose() {
    titleController.dispose();
    deadlineController.dispose();
    super.dispose();
  }

  void save() {
    if (!formKey.currentState!.validate()) return;

    final task = TaskItem(
      title: titleController.text.trim(),
      deadline: deadlineController.text.trim(),
      difficulty: selectedDifficulty,
    );

    context.read<TaskStore>().add(task);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Task')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Task Title',
                  hintText: 'e.g., DSA Revision',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a task title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: deadlineController,
                decoration: const InputDecoration(
                  labelText: 'Deadline',
                  hintText: 'e.g., 20 Oct 2026',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a deadline';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              const Text('Difficulty', style: TextStyle(fontSize: 16)),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'Easy', label: Text('Easy')),
                  ButtonSegment(value: 'Medium', label: Text('Medium')),
                  ButtonSegment(value: 'Hard', label: Text('Hard')),
                ],
                selected: {selectedDifficulty},
                onSelectionChanged: (Set<String> selection) {
                  setState(() {
                    selectedDifficulty = selection.first;
                  });
                },
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: save,
                child: const Text('Save Task', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== 7. SETTINGS / PROFILE SCREEN ====================
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<TaskStore>();

    return Scaffold(
      appBar: AppBar(title: const Text('Profile & Settings')),
      body: ListView(
        children: [
          const UserAccountsDrawerHeader(
            accountName: Text('TaskWise Student'),
            accountEmail: Text('student@taskwise.app'),
            currentAccountPicture: CircleAvatar(
              child: Icon(Icons.person, size: 40),
            ),
          ),
          SwitchListTile(
            title: const Text('Enable Notifications'),
            subtitle: const Text('Reminders for pending tasks'),
            secondary: const Icon(Icons.notifications_active),
            value: store.notificationsEnabled,
            onChanged: (bool value) {
              context.read<TaskStore>().toggleNotifications(value);
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('Clear All Tasks', style: TextStyle(color: Colors.red)),
            subtitle: const Text('Reset local storage permanently'),
            onTap: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Clear All Tasks?'),
                  content: const Text(
                    'This action will wipe all your saved study tasks.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        context.read<TaskStore>().clearData();
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('All tasks cleared')),
                        );
                      },
                      child: const Text('Clear', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}