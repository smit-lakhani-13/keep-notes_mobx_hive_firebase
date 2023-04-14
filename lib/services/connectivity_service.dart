import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:keep_notes/models/note_model.dart';
import 'package:keep_notes/services/hive_service.dart';

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  final HiveService _hiveService = HiveService();
  final FirebaseService _firebaseService = FirebaseService();

  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  Future<void> init() async {
    await Firebase.initializeApp();

    // get all notes from Firestore and add them to notesList
    final notes = await _firebaseService.getAllNotesFromFirestore();
    if (notes != null) {
      notesList.addAll(notes);
    }

    // get all notes from Hive and add them to notesList
    final localNotes = await _hiveService.getAllNotes();
    if (localNotes != null) {
      notesList.addAll(localNotes);
    }

    // listen for connectivity changes
    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen(_onConnectivityChanged);
  }

  final List<Note> notesList = [];

  Future<void> _onConnectivityChanged(ConnectivityResult result) async {
    if (result == ConnectivityResult.none) {
      // Handle offline behavior
      return;
    }

    try {
      final List<Note> unsyncedNotes = await _hiveService.getUnsyncedNotes();
      if (unsyncedNotes.isEmpty) {
        return;
      }

      // Initialize Firebase if it hasn't been initialized yet
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }

      await _firebaseService.syncNotes(unsyncedNotes);

      for (final note in unsyncedNotes) {
        await _hiveService.setNoteSynced(note.key);
      }
    } catch (error) {
      print('Error syncing notes: $error');
    }
  }

  Future<bool> checkConnection() async {
    var connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult == ConnectivityResult.mobile ||
        connectivityResult == ConnectivityResult.wifi) {
      return true;
    } else {
      return false;
    }
  }

  void dispose() {
    _connectivitySubscription?.cancel();
  }
}

class FirebaseService {
  Future<void> syncNotes(List<Note> unsyncedNotes) async {
    final CollectionReference notesRef =
        FirebaseFirestore.instance.collection('notes');

    final batch = FirebaseFirestore.instance.batch();

    for (final note in unsyncedNotes) {
      final noteRef = notesRef.doc(note.key);

      assert(note.key.isNotEmpty, 'Note key should not be empty.');

      final DocumentSnapshot noteSnapshot = await noteRef.get();

      if (noteSnapshot.exists) {
        await noteRef.update(note.toMap());
      } else {
        await noteRef.set(note.toMap());
      }

      batch.update(noteRef, {'synced': true});
    }

    await batch.commit();
  }

  Future<List<Note>> getAllNotesFromFirestore() async {
    final notesRef = FirebaseFirestore.instance.collection('notes');
    final querySnapshot = await notesRef.get();
    final notes =
        querySnapshot.docs.map((doc) => Note.fromMap(doc.data())).toList();
    return notes;
  }

  Future<String?> addNote(Note note) async {
    final notesRef = FirebaseFirestore.instance.collection('notes');
    final doc = await notesRef.add(note.toMap());
    return doc.id;
  }

  Future<void> updateNote(
      Note note, String title, String description, DateTime createdTime) async {
    final notesRef = FirebaseFirestore.instance.collection('notes');
    final noteRef = notesRef.doc(note.key);
    await noteRef.update({
      'title': title,
      'description': description,
      'createdTime': createdTime.toIso8601String(),
    });
  }
}
