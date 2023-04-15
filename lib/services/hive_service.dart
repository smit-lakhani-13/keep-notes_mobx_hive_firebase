import 'package:cloud_firestore/cloud_firestore.dart';
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
    required bool synced,
  }) async {
    final box = await openBox();
    final note = Note(
      title: title,
      description: description,
      createdTime: createdTime,
      key: key,
      synced: synced, // added this line
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
    required bool synced,
  }) async {
    final box = await openBox();
    final note = Note(
      title: title,
      description: description,
      createdTime: createdTime,
      key: key,
      synced: synced, // added this line
    );
    await box.putAt(index, note);
  }

  Future<void> editNoteAt({
    required int index,
    required String title,
    required String description,
    required DateTime createdTime,
    required String key,
    required bool synced,
  }) async {
    final box = await openBox();
    final note = Note(
      title: title,
      description: description,
      createdTime: createdTime,
      key: key,
      synced: synced, // added this line
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

  Future<Note?> removeNoteByKey(String key) async {
    final box = await openBox();
    final noteIndex = box.keys.toList().indexOf(key);
    if (noteIndex == -1) {
      return null;
    }
    final note = box.getAt(noteIndex);
    await box.delete(key);
    return note;
  }

  Future<void> syncNotes() async {
    final box = await openBox();
    final notes = box.values.toList();
    final unsyncedNotes = notes.where((note) => !note.synced).toList();

    final batch = FirebaseFirestore.instance.batch();
    final notesRef = FirebaseFirestore.instance.collection('notes');

    for (final note in unsyncedNotes) {
      batch.set(notesRef.doc(note.key), note.toMap());
    }

    await batch.commit();

    for (final note in unsyncedNotes) {
      final index = notes.indexOf(note);
      final updatedNote = note.copyWith(synced: true);
      await box.putAt(index, updatedNote);
    }
  }

  Future<List<Note>> getUnsyncedNotes() async {
    final box = await openBox();
    final notes = box.values.toList();
    final unsyncedNotes = notes.where((note) => !note.synced).toList();
    return unsyncedNotes;
  }

  Future<List<Note>> getNotes() async {
    final box = await openBox();
    final notes = box.values.toList().cast<Note>();
    return notes;
  }

  Future<void> setNoteSynced(String key) async {
    final box = await openBox();
    final noteIndex = box.keys.toList().indexOf(key);
    if (noteIndex == -1) {
      return;
    }
    final note = box.getAt(noteIndex) as Note?;
    if (note != null) {
      final updatedNote = note.copyWith(synced: true);
      await box.putAt(noteIndex, updatedNote);
    }
  }

  Future<List<Note>> getSyncedNotes() async {
    final Box<Note> notesBox = await openBox();
    final List<Note> notes = notesBox.values
        .where((note) => note.synced == true)
        .toList()
        .cast<Note>();
    return notes;
  }

  Future<void> clearAllNotes() async {
    final box = await openBox();
    await box.clear();
  }
}
