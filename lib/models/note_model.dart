import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

part 'note_model.g.dart';

@HiveType(typeId: 0)
class Note {
  @HiveField(0)
  String title;

  @HiveField(1)
  String description;

  @HiveField(2)
  DateTime createdTime;

  @HiveField(3)
  String key;

  @HiveField(4)
  bool synced; // added synced property

  Note({
    required this.title,
    required this.description,
    required this.createdTime,
    required this.key,
    this.synced = false, // initialized to false
  });

  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      title: map['title'],
      description: map['description'],
      createdTime: (map['created'] as Timestamp).toDate(),
      key: map['id'] ?? '',
      synced: map['synced'] ?? false, // added synced property
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'created': createdTime,
      'id': key,
      'synced': synced, // added synced property
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'createdTime': createdTime,
      'key': key,
    };
  }

  Note copyWith({
    String? title,
    String? description,
    DateTime? createdTime,
    String? key,
    bool? synced, // added synced property
  }) {
    return Note(
      title: title ?? this.title,
      description: description ?? this.description,
      createdTime: createdTime ?? this.createdTime,
      key: key ?? this.key,
      synced: synced ?? this.synced, // added synced property
    );
  }
}
