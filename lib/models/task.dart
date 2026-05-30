import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:material_symbols_icons/symbols.dart';

part 'task.g.dart';

// ──────────────────────────────────────────────
//  TaskType enum
//  Represents how the task was originally captured.
// ──────────────────────────────────────────────

@HiveType(typeId: 1)
enum TaskType {
  @HiveField(0)
  manual,

  @HiveField(1)
  voice,

  @HiveField(2)
  image;

  /// Human-readable label shown in the UI.
  String get label {
    switch (this) {
      case TaskType.manual:
        return 'Manual';
      case TaskType.voice:
        return 'Voice';
      case TaskType.image:
        return 'Image';
    }
  }

  /// Icon that represents this task type.
  IconData get icon {
    switch (this) {
      case TaskType.manual:
        return Symbols.edit_note;
      case TaskType.voice:
        return Symbols.mic;
      case TaskType.image:
        return Symbols.image_search;
    }
  }
}

// ──────────────────────────────────────────────
//  Task model (Hive-persisted)
// ──────────────────────────────────────────────

@HiveType(typeId: 0)
class Task extends HiveObject {
  Task({
    required this.id,
    required this.title,
    this.contentJson = '',
    required this.time,
    required this.type,
    this.isCompleted = false,
  });

  /// Unique identifier (UUID string or timestamp-based key).
  @HiveField(0)
  final String id;

  /// Short description / title of the task.
  @HiveField(1)
  String title;

  /// Rich text content stored as Quill Delta JSON string.
  /// Falls back gracefully to plain text if it isn't valid JSON.
  @HiveField(2)
  String contentJson;

  /// Human-readable time string, e.g. "09:00 AM".
  @HiveField(3)
  final String time;

  /// How the task was captured.
  @HiveField(4)
  TaskType type;

  /// Whether the task has been marked done.
  @HiveField(5)
  bool isCompleted;

  // ── Convenience factory ──────────────────────

  /// Returns a copy of this task with the given fields replaced.
  Task copyWith({
    String? id,
    String? title,
    String? contentJson,
    String? time,
    TaskType? type,
    bool? isCompleted,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      contentJson: contentJson ?? this.contentJson,
      time: time ?? this.time,
      type: type ?? this.type,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  @override
  String toString() =>
      'Task(id: $id, title: $title, time: $time, type: ${type.label}, '
      'isCompleted: $isCompleted)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Task && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
