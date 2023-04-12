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
    required String key,
  }) async {
    final note = Note(
      title: title,
      description: description,
      createdTime: createdTime,
      key: key,
    );
    if (await _firebaseService.hasInternetConnection()) {
      final String? docId = await _firebaseService.addNote(note);
      note.key = docId!;
    } else {
      await _hiveService.addNote(
        title: title,
        description: description,
        createdTime: createdTime,
        key: '',
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
    }
    await _hiveService.removeNoteAt(index);
    _notesListReaction();
  }

  @action
  Future<void> updateNoteAt({
    required int index,
    required String title,
    required String description,
    required DateTime createdTime,
  }) async {
    final note = notesList[index];
    if (await _firebaseService.hasInternetConnection()) {
      await _firebaseService.updateNote(
        note.key as Note,
        title,
        description,
        createdTime,
      );
    }
    await _hiveService.updateNoteAt(
      index: index,
      title: title,
      description: description,
      createdTime: createdTime,
      key: note.key,
    );
    // Update the note in the local list
    notesList[index] = note.copyWith(
      title: title,
      description: description,
      createdTime: createdTime,
      key: note.key,
    );
    // Notify the reaction that the list has changed
    _notesListReaction();
  }

  Future<void> init() async {
    _firebaseService.init();
    await _hiveService.init();
    final notes = await _firebaseService.getAllNotesFromFirestore();
    if (notes != null) {
      notesList.addAll(notes);
    }
  }

  void _notesListReaction() {
    print(notesList);
  }
}
