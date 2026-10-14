import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
runApp(
MultiProvider(
providers: [
ChangeNotifierProvider(
create: (_) => TaskStore()..load(),
),
ChangeNotifierProvider(
create: (_) => SettingsStore()..load(),
),
],
child: const MyApp(),
),
);
}

// TASK MODEL
class Task {
String title;
bool done;
DateTime? due;

Task(this.title, {this.done = false, this.due});

Map<String, dynamic> toJson() => {
'title': title,
'done': done,
'due': due?.toIso8601String(),
};

factory Task.fromJson(Map<String, dynamic> j) {
return Task(
j['title'] as String,
done: j['done'] as bool? ?? false,
due: j['due'] == null
? null
    : DateTime.parse(j['due'] as String),
);
}
}

// TASK STORE
class TaskStore extends ChangeNotifier {
final List<Task> _tasks = [];

List<Task> get tasks => List.unmodifiable(_tasks);

void add(String title, {DateTime? due}) {
_tasks.add(Task(title, due: due));
notifyListeners();
_save();
}

void toggle(Task task) {
task.done = !task.done;
notifyListeners();
_save();
}

void remove(Task task) {
_tasks.remove(task);
notifyListeners();
_save();
}

Future<void> _save() async {
final prefs = await SharedPreferences.getInstance();
final list = _tasks.map((task) => task.toJson()).toList();
await prefs.setString('tasks', jsonEncode(list));
}

Future<void> load() async {
final prefs = await SharedPreferences.getInstance();
final text = prefs.getString('tasks');

if (text == null) return;

try {
final data = jsonDecode(text) as List;
_tasks
..clear()
..addAll(
data.map(
(item) => Task.fromJson(
Map<String, dynamic>.from(item as Map),
),
),
);
notifyListeners();
} catch (e) {
// Ignore invalid saved data.
}
}
}

// SETTINGS STORE
class SettingsStore extends ChangeNotifier {
bool _dark = false;

bool get dark => _dark;

void setDark(bool value) {
_dark = value;
notifyListeners();
_save();
}

Future<void> _save() async {
final prefs = await SharedPreferences.getInstance();
await prefs.setBool('dark', _dark);
}

Future<void> load() async {
final prefs = await SharedPreferences.getInstance();
_dark = prefs.getBool('dark') ?? false;
notifyListeners();
}
}

// MAIN APP
class MyApp extends StatelessWidget {
const MyApp({super.key});

ThemeData buildTheme(Brightness brightness) {
return ThemeData(
useMaterial3: true,
fontFamily: 'Poppins',
colorScheme: ColorScheme.fromSeed(
seedColor: const Color(0xFF0B4F8A),
brightness: brightness,
),
textTheme: const TextTheme(
titleLarge: TextStyle(
fontSize: 22,
fontWeight: FontWeight.bold,
),
bodyMedium: TextStyle(fontSize: 15),
),
);
}

@override
Widget build(BuildContext context) {
final dark = context.watch<SettingsStore>().dark;

return MaterialApp(
title: 'Task Manager',
debugShowCheckedModeBanner: false,
theme: buildTheme(Brightness.light),
darkTheme: buildTheme(Brightness.dark),
themeMode: dark ? ThemeMode.dark : ThemeMode.light,
home: const HomeScreen(),
);
}
}

// HOME SCREEN
class HomeScreen extends StatefulWidget {
const HomeScreen({super.key});

@override
State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
int tab = 0;

@override
Widget build(BuildContext context) {
final tasks = context.watch<TaskStore>().tasks;
final dark = context.watch<SettingsStore>().dark;

return Scaffold(
appBar: AppBar(
title: const Text('Task Manager'),
actions: [
IconButton(
icon: const Icon(Icons.pending_actions),
onPressed: () {
final left = tasks.where((task) => !task.done).length;
ScaffoldMessenger.of(context).showSnackBar(
SnackBar(content: Text('$left still to do')),
);
},
),
],
),
drawer: Drawer(
child: ListView(
padding: EdgeInsets.zero,
children: [
DrawerHeader(
decoration: BoxDecoration(
color: Theme.of(context).colorScheme.primary,
),
child: Text(
'Task Manager',
style: TextStyle(
color: Theme.of(context).colorScheme.onPrimary,
fontSize: 22,
),
),
),
SwitchListTile(
secondary: const Icon(Icons.dark_mode),
title: const Text('Dark mode'),
value: dark,
onChanged: (value) {
context.read<SettingsStore>().setDark(value);
},
),
ListTile(
leading: const Icon(Icons.info),
title: const Text('About'),
onTap: () {
Navigator.pop(context);
showAboutDialog(
context: context,
applicationName: 'Task Manager',
applicationVersion: '1.0.0',
children: const [
Text('A simple task manager app.'),
],
);
},
),
],
),
),
body: SafeArea(child: buildBody(tasks)),
floatingActionButton: FloatingActionButton(
child: const Icon(Icons.add),
onPressed: () async {
final task = await showModalBottomSheet<Task>(
context: context,
isScrollControlled: true,
builder: (_) => const AddTaskSheet(),
);

if (!mounted) return;

if (task != null && task.title.trim().isNotEmpty) {
context.read<TaskStore>().add(
task.title.trim(),
due: task.due,
);
}
},
),
bottomNavigationBar: BottomNavigationBar(
currentIndex: tab,
onTap: (index) => setState(() => tab = index),
items: const [
BottomNavigationBarItem(
icon: Icon(Icons.list),
label: 'Tasks',
),
BottomNavigationBarItem(
icon: Icon(Icons.done),
label: 'Done',
),
BottomNavigationBarItem(
icon: Icon(Icons.person),
label: 'You',
),
],
),
);
}

Widget buildBody(List<Task> tasks) {
if (tab == 1) {
return buildList(tasks.where((task) => task.done).toList());
}

if (tab == 2) {
return Center(
child: Column(
mainAxisAlignment: MainAxisAlignment.center,
children: [
const Icon(Icons.person, size: 60),
const SizedBox(height: 12),
const Text(
'Your Profile',
style: TextStyle(fontSize: 22),
),
const SizedBox(height: 8),
Text('Total tasks: ${tasks.length}'),
Text(
'Completed: ${tasks.where((task) => task.done).length}',
),
Text(
'Pending: ${tasks.where((task) => !task.done).length}',
),
],
),
);
}

return buildList(tasks.where((task) => !task.done).toList());
}

Widget buildList(List<Task> shown) {
if (shown.isEmpty) {
return const Center(child: Text('Nothing here yet'));
}

return ListView.builder(
itemCount: shown.length,
itemBuilder: (context, index) {
final task = shown[index];

return ListTile(
leading: Checkbox(
value: task.done,
onChanged: (_) {
context.read<TaskStore>().toggle(task);
},
),
title: Text(
task.title,
style: TextStyle(
decoration:
task.done ? TextDecoration.lineThrough : null,
),
),
subtitle: task.due == null
? null
    : Text(
'Due ${task.due!.day}/'
'${task.due!.month}/${task.due!.year}',
),
trailing: IconButton(
icon: const Icon(Icons.delete),
onPressed: () async {
final yes = await confirmDelete(context);

if (yes && mounted) {
context.read<TaskStore>().remove(task);
}
},
),
);
},
);
}
}

// ADD TASK SHEET
class AddTaskSheet extends StatefulWidget {
const AddTaskSheet({super.key});

@override
State<AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends State<AddTaskSheet> {
final TextEditingController titleController =
TextEditingController();

DateTime? due;

@override
void dispose() {
titleController.dispose();
super.dispose();
}

Future<void> chooseDate() async {
final selected = await showDatePicker(
context: context,
initialDate: due ?? DateTime.now(),
firstDate: DateTime.now(),
lastDate: DateTime.now().add(
const Duration(days: 3650),
),
);

if (selected != null) {
setState(() => due = selected);
}
}

void saveTask() {
final title = titleController.text.trim();

if (title.isEmpty) return;

Navigator.pop(
context,
Task(title, due: due),
);
}

@override
Widget build(BuildContext context) {
return Padding(
padding: EdgeInsets.only(
left: 20,
right: 20,
top: 20,
bottom: MediaQuery.of(context).viewInsets.bottom + 20,
),
child: SingleChildScrollView(
child: Column(
mainAxisSize: MainAxisSize.min,
crossAxisAlignment: CrossAxisAlignment.stretch,
children: [
const Text(
'Add Task',
style: TextStyle(
fontSize: 22,
fontWeight: FontWeight.bold,
),
),
const SizedBox(height: 16),
TextField(
controller: titleController,
autofocus: true,
decoration: const InputDecoration(
labelText: 'Task title',
hintText: 'Enter your task',
border: OutlineInputBorder(),
),
onSubmitted: (_) => saveTask(),
),
const SizedBox(height: 12),
OutlinedButton.icon(
onPressed: chooseDate,
icon: const Icon(Icons.calendar_today),
label: Text(
due == null
? 'Choose due date (optional)'
    : 'Due ${due!.day}/${due!.month}/${due!.year}',
),
),
const SizedBox(height: 16),
ElevatedButton(
onPressed: saveTask,
child: const Text('Save Task'),
),
],
),
),
);
}
}

// DELETE CONFIRMATION
Future<bool> confirmDelete(BuildContext context) async {
final yes = await showDialog<bool>(
context: context,
builder: (context) => AlertDialog(
title: const Text('Delete Task'),
content: const Text(
'Are you sure you want to delete this task?',
),
actions: [
TextButton(
onPressed: () => Navigator.pop(context, false),
child: const Text('Cancel'),
),
TextButton(
onPressed: () => Navigator.pop(context, true),
child: const Text('Delete'),
),
],
),
);

return yes ?? false;
}