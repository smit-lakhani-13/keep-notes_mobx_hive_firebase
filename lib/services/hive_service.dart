import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:keep_notes/models/note_model.dart';
import 'package:path_provider/path_provider.dart';

class HiveService {
  static const String _boxName = 'notesBox';

  Future<void> init() async {
    final appDocumentDir = await getApplicationDocumentsDirectory();
    Hive.initFlutter(appDocumentDir.path);
    Hive.registerAdapter(NoteAdapter());
  }

  Future<Box<Note>> openBox() async {
    final box = await Hive.openBox<Note>(_boxName);
    return box;
  }

  Future<void> addNote({
    required String title,
    required String description,
    required DateTime createdTime,
    required String key,
  }) async {
    final box = await openBox();
    final note = Note(
      title: title,
      description: description,
      createdTime: createdTime,
      key: key,
    );
    await box.add(note);
  }

  Future<void> removeNoteAt(int index) async {
    final box = await openBox();
    await box.deleteAt(index);
  }

  Future<void> updateNoteAt({
    required int index,
    required String title,
    required String description,
    required DateTime createdTime,
    required String key,
  }) async {
    final box = await openBox();
    final note = Note(
      title: title,
      description: description,
      createdTime: createdTime,
      key: key,
    );
    await box.putAt(index, note);
  }

  Future<void> editNoteAt({
    required int index,
    required String title,
    required String description,
    required DateTime createdTime,
    required String key,
  }) async {
    final box = await openBox();
    final note = Note(
      title: title,
      description: description,
      createdTime: createdTime,
      key: key,
    );
    await box.putAt(index, note);
  }

  Future<List<Note>> getAllNotes() async {
    final box = await openBox();
    final notes = box.values.toList();
    return notes;
  }

  Future<void> clearNotes() async {
    final box = await openBox();
    await box.clear();
  }
}
