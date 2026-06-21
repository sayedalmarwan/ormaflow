import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/task.dart';

// ──────────────────────────────────────────────
//  TaskProvider
//  Single source of truth for all task state.
//  All state is persisted to Hive boxes on every mutation.
//  Consumed via Provider.of<TaskProvider>(context)
//  or context.watch<TaskProvider>() / context.read<TaskProvider>().
// ──────────────────────────────────────────────

class TaskProvider extends ChangeNotifier {
  static const String _tasksBoxName = 'tasks';
  static const String _trashBoxName = 'trash';

  late Box<Task> _tasksBox;
  late Box<Task> _trashBox;

  /// Call after Hive boxes are opened (in main.dart).
  void init(Box<Task> tasksBox, Box<Task> trashBox) {
    _tasksBox = tasksBox;
    _trashBox = trashBox;

    // Seed with demo data only on first launch (empty box).
    if (_tasksBox.isEmpty) {
      _seedTasks();
    }
  }

  // ── Public read-only accessors ────────────────

  /// All active tasks (ordered by insertion / creation time).
  List<Task> get tasks => _tasksBox.values.toList();

  /// All deleted tasks in the trash.
  List<Task> get trashTasks => _trashBox.values.toList();

  /// Only tasks that are not yet completed.
  List<Task> get pendingTasks =>
      tasks.where((t) => !t.isCompleted).toList();

  /// Only tasks that have been marked as done.
  List<Task> get completedTasks =>
      tasks.where((t) => t.isCompleted).toList();

  /// Number of pending (incomplete) tasks.
  int get pendingCount => pendingTasks.length;

  // ── Mutations ─────────────────────────────────

  /// Add a new [task] to the list.
  Future<void> addTask(Task task) async {
    await _tasksBox.put(task.id, task);
    notifyListeners();
  }

  /// Toggle the [isCompleted] state of the task with [id].
  Future<void> toggleTask(String id) async {
    final task = _tasksBox.get(id);
    if (task == null) return;
    task.isCompleted = !task.isCompleted;
    await task.save();
    notifyListeners();
  }

  /// Permanently delete the task with [id] from both boxes.
  Future<void> deleteTask(String id) async {
    await _tasksBox.delete(id);
    await _trashBox.delete(id);
    notifyListeners();
  }

  /// Move task from active list to trash.
  Future<void> moveToTrash(String id) async {
    final task = _tasksBox.get(id);
    if (task == null) return;
    // Use copyWith() to create a fresh, unattached HiveObject.
    // Putting the same HiveObject instance into a different box while it is
    // still registered with the source box causes Hive to silently revert the
    // deletion on the next read.
    await _trashBox.put(id, task.copyWith());
    await _tasksBox.delete(id);
    notifyListeners();
  }

  /// Restore task from trash back to active list.
  Future<void> restoreTask(String id) async {
    final task = _trashBox.get(id);
    if (task == null) return;
    // Same fresh-copy pattern as moveToTrash.
    await _tasksBox.put(id, task.copyWith());
    await _trashBox.delete(id);
    notifyListeners();
  }

  /// Replace all fields of an existing task (matched by id).
  Future<void> updateTask(Task updated) async {
    await _tasksBox.put(updated.id, updated);
    notifyListeners();
  }

  /// Remove all completed tasks from the active list (move to trash).
  Future<void> clearCompleted() async {
    final completed = tasks.where((t) => t.isCompleted).toList();
    for (final t in completed) {
      // Use copyWith() to create a fresh, unattached HiveObject — putting the
      // same instance into a different box reverts the deletion (see moveToTrash).
      await _trashBox.put(t.id, t.copyWith());
      await _tasksBox.delete(t.id);
    }
    notifyListeners();
  }

  // ── Seed data (first launch only) ─────────────

  Future<void> _seedTasks() async {
    final seedList = [
      Task(
        id: 'task_001',
        title: 'Buy ingredients for Pizza',
        time: '09:00 AM',
        type: TaskType.manual,
      ),
      Task(
        id: 'task_002',
        title: 'Pay the electricity bill',
        time: '11:30 AM',
        type: TaskType.manual,
      ),
      Task(
        id: 'task_003',
        title: 'Note: Idea for Mom\'s birthday gift',
        time: '02:15 PM',
        type: TaskType.voice,
      ),
      Task(
        id: 'task_004',
        title: 'Scan recipe from magazine',
        time: '04:00 PM',
        type: TaskType.image,
      ),
    ];

    for (final t in seedList) {
      await _tasksBox.put(t.id, t);
    }
    notifyListeners();
  }

  // ── Hive box names (public for main.dart) ──────
  static String get tasksBoxName => _tasksBoxName;
  static String get trashBoxName => _trashBoxName;
}
