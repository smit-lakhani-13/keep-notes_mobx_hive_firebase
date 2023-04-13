import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
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
    String? key,
  }) async {
    final note = Note(
      title: title,
      description: description,
      createdTime: createdTime,
      key: key ?? '',
    );
    if (await _firebaseService.hasInternetConnection()) {
      final String? docId = await _firebaseService.addNote(note);
      note.key = docId!;
      // Clear the Hive database if the internet connection is restored
      await _hiveService.clearNotes();
    } else {
      await _hiveService.addNote(
        title: title,
        description: description,
        createdTime: createdTime,
        key: note.key,
      );
    }
    notesList.add(note);
  }

  @action
  Future<void> removeNoteAt(int index) async {
    final note = notesList[index];
    notesList.removeAt(index);
    if (await _firebaseService.hasInternetConnection()) {
      await _firebaseService.deleteNote(note.key);
      await _hiveService.clearNotes();
    } else {
      await _hiveService.removeNoteAt(index);
    }
    _notesListReaction();
  }

  @action
  Future<void> updateNoteAt({
    required int index,
    required String title,
    required String description,
    required DateTime createdTime,
    required String key,
  }) async {
    final note = notesList[index];
    if (await _firebaseService.hasInternetConnection()) {
      await _firebaseService.updateNote(
        note,
        title,
        description,
        createdTime,
      );
      await _hiveService.clearNotes();
    } else {
      await _hiveService.editNoteAt(
        index: index,
        title: title,
        description: description,
        createdTime: createdTime,
        key: note.key,
      );
    }
    notesList[index] = note.copyWith(
      title: title,
      description: description,
      createdTime: createdTime,
      key: note.key,
    );
    _notesListReaction();
  }

  Future<void> init() async {
    await Firebase.initializeApp();
    await _hiveService.init();

    final notes = await _firebaseService.getAllNotesFromFirestore();
    if (notes != null) {
      notesList.addAll(notes);
    }

    final localNotes = await _hiveService.getAllNotes();
    if (localNotes != null) {
      notesList.addAll(localNotes);
    }
  }

  void _notesListReaction() {
    print(notesList);
  }
}
