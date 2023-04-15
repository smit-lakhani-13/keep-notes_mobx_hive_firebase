import 'package:firebase_core/firebase_core.dart';
import 'package:keep_notes/services/connectivity_service.dart' as connectivity;
import 'package:mobx/mobx.dart';
import 'package:keep_notes/models/note_model.dart';
import 'package:keep_notes/services/firebase_service.dart' as firebase;
import 'package:keep_notes/services/hive_service.dart';
import 'package:collection/collection.dart';

part 'note_store.g.dart';

class NoteStore = _NoteStore with _$NoteStore;

abstract class _NoteStore with Store {
  final firebase.FirebaseService _firebaseService = firebase.FirebaseService();
  final HiveService _hiveService = HiveService();
  final connectivity.ConnectivityService _connectivityService =
      connectivity.ConnectivityService();

  @observable
  ObservableList<Note> notesList = ObservableList<Note>();

  @observable
  bool loading = false;

  @observable
  bool hasOfflineNotes = false;

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
      await _hiveService.clearNotes();
      hasOfflineNotes = false;
    } else {
      await _hiveService.addNote(
        title: title,
        description: description,
        createdTime: createdTime,
        key: note.key,
        synced: false,
      );
      hasOfflineNotes = true;
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
    note.synced = false;
    notesList.removeAt(index);
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
        synced: true,
      );
    }
    notesList[index] = note.copyWith(
      title: title,
      description: description,
      createdTime: createdTime,
      key: note.key,
      synced: false, // set synced to false before updating the note in the list
    );
    await _hiveService.updateNoteAt(
      index: index,
      title: title,
      description: description,
      createdTime: createdTime,
      key: note.key,
      synced: false, // set synced to false before updating the note in Hive
    );
    _notesListReaction();
  }

  Future<void> syncNotesWithFirebase() async {
    final hiveNotes = await _hiveService.getAllNotes();
    final cloudNotes = await _firebaseService.getAllNotesFromFirestore();

    final offlineNotes = <Note>[];
    final onlineNotes = <Note>[];

    // Check if there are any offline notes in Hive
    for (final note in hiveNotes) {
      if (!note.synced) {
        offlineNotes.add(note);
      } else {
        onlineNotes.add(note);
      }
    }

    // If there are offline notes, add them to Firestore and clear Hive notes
    if (offlineNotes.isNotEmpty) {
      for (final note in offlineNotes) {
        final String? docId = await _firebaseService.addNote(note);
        if (docId != null) {
          await _hiveService.setNoteSynced(note.key);
        }
      }
      await _hiveService.clearAllNotes();
    }

    // Sync online notes between Firestore and Hive
    for (final note in onlineNotes) {
      final existingNote =
          cloudNotes.firstWhereOrNull((n) => n.key == note.key);
      if (existingNote != null) {
        await _firebaseService.updateNote(
          existingNote,
          note.title,
          note.description,
          note.createdTime,
        );
        await _hiveService.setNoteSynced(note.key);
      } else {
        final String? docId = await _firebaseService.addNote(note);
        if (docId != null) {
          await _hiveService.setNoteSynced(note.key);
        }
      }
    }
  }

  @action
  Future<void> onSyncButtonPressed() async {
    await syncNotesWithFirebase();
  }

  Future<void> init() async {
    loading = true;

    await Firebase.initializeApp();
    await _hiveService.init();

    final notes = await _firebaseService.getAllNotesFromFirestore();
    if (notes != null) {
      notesList.addAll(notes);
    }
    final localNotes = await _hiveService.getAllNotes();
    if (localNotes != null) {
      notesList.addAll(localNotes);
      hasOfflineNotes = localNotes.any((note) => !note.synced);
    }
    loading = false;
  }

  void _notesListReaction() {
    print(notesList);
  }
}
