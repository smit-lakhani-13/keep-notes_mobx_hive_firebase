import 'package:flutter/material.dart';
import 'package:mobx/mobx.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:keep_notes/models/note_model.dart';
import 'package:keep_notes/services/firebase_service.dart';
import 'package:keep_notes/services/hive_service.dart';

part 'note_store.g.dart';

class NoteStore = _NoteStore with _$NoteStore;

abstract class _NoteStore with Store {
  final FirebaseService _firebaseService = FirebaseService();
  final HiveService _hiveService = HiveService();

  @observable
  ObservableList<Note> notesList = ObservableList<Note>();

  @action
  Future<void> addNote({
    required String title,
    required String description,
    required DateTime createdTime,
    required String key,
  }) async {
    final note = Note(
      title: title,
      description: description,
      createdTime: createdTime,
      key: key,
    );
    await _firebaseService.addNote(note);
    await _hiveService.addNote(note,
        title: 'title',
        description: 'description',
        createdTime: createdTime,
        key: 'key');
    notesList.add(note);
  }

  @action
  Future<void> removeNoteAt(int index) async {
    final note = notesList[index];
    await _firebaseService.deleteNote(note.key);
    await _hiveService.removeNoteAt(index);
    notesList.removeAt(index);
  }

  @action
  Future<void> updateNoteAt({
    required int index,
    required String title,
    required String description,
    required DateTime createdTime,
  }) async {
    final note = notesList[index];
    note.title = title;
    note.description = description;
    note.createdTime = createdTime;
    await _firebaseService.updateNote(note);
    await _hiveService.updateNoteAt(
      index: index,
      title: title,
      description: description,
      createdTime: createdTime,
      key: note.key,
    );
    notesList[index] = note;
  }

  Future<void> init() async {
    _firebaseService.init();
    await _hiveService.init();
    final notes = await _firebaseService.getAllNotes();
    if (notes != null) {
      notesList.addAll(notes);
    }
  }
}
