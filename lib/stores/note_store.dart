import 'package:firebase_core/firebase_core.dart';
import 'package:keep_notes/services/connectivity_service.dart' as connectivity;
import 'package:mobx/mobx.dart';
import 'package:keep_notes/models/note_model.dart';
import 'package:keep_notes/services/firebase_service.dart' as firebase;
import 'package:keep_notes/services/hive_service.dart';

part 'note_store.g.dart';

class NoteStore = _NoteStore with _$NoteStore;

abstract class _NoteStore with Store {
  final firebase.FirebaseService _firebaseService = firebase.FirebaseService();
  final HiveService _hiveService = HiveService();
  final connectivity.ConnectivityService _connectivityService =
      connectivity.ConnectivityService();

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
      await _hiveService.clearNotes();
    } else {
      await _hiveService.addNote(
        title: title,
        description: description,
        createdTime: createdTime,
        key: note.key,
        synced: false,
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
        synced: true,
      );
    }
    notesList[index] = note.copyWith(
      title: title,
      description: description,
      createdTime: createdTime,
      key: note.key,
      synced: false,
    );
    _notesListReaction();
  }

  @action
  Future<void> uploadNotesFromHiveToFirebase() async {
    final List<Note> notes = await _hiveService.getAllNotes();
    for (final note in notes) {
      if (note.synced == false) {
        await _firebaseService.addNote(note);
      } else {
        await _firebaseService.updateNote(
          note,
          note.title,
          note.description,
          note.createdTime,
        );
      }
      await _hiveService.removeNoteByKey(note.key);
    }
  }

  @action
  Future<void> syncNotesWithFirebase() async {
    final unsyncedNotes = await _hiveService.getUnsyncedNotes();
    for (final note in unsyncedNotes) {
      final String? docId = await _firebaseService.addNote(note);
      if (docId != null) {
        await _hiveService.setNoteSynced(note.key);
      }
    }
    final List<Note> localNotes = await _hiveService.getAllNotes();

    final List<Note> cloudNotes =
        await _firebaseService.getAllNotesFromFirestore();

    final List<Note> newNotes = localNotes.where((note) {
      return note.synced == false &&
          !cloudNotes.any((cloudNote) => cloudNote.key == note.key);
    }).toList();
    for (final note in newNotes) {
      final String? docId = await _firebaseService.addNote(note);
      if (docId != null) {
        await _hiveService.setNoteSynced(note.key);
      }
    }
  }

  @action
  Future<void> onSyncButtonPressed() async {
    await uploadNotesFromHiveToFirebase();
    await syncNotesWithFirebase();
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
