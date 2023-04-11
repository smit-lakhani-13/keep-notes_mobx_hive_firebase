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

  Note({
    required this.title,
    required this.description,
    required this.createdTime,
    required this.key,
  });

  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      title: map['title'],
      description: map['description'],
      createdTime: (map['created'] as Timestamp).toDate(),
      key: map['id'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'created': createdTime,
      'id': key,
    };
  }
}
