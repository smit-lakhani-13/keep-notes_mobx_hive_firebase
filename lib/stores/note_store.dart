// ignore_for_file: prefer_const_constructors

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity/connectivity.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:keep_notes/services/connectivity_service.dart' as connectivity;
import 'package:keep_notes/services/connectivity_service.dart';
import 'package:mobx/mobx.dart';
import 'package:keep_notes/models/note_model.dart';
import 'package:keep_notes/services/firebase_service.dart' as firebase;
import 'package:keep_notes/services/hive_service.dart';
import 'package:path_provider/path_provider.dart';

part 'note_store.g.dart';

class NoteStore = _NoteStore with _$NoteStore;

abstract class _NoteStore with Store {
  late Box _noteBox;
  late StreamSubscription<ConnectivityResult> _connectivitySubscription;
  int _unsyncedNotesCount = 0;

  final firebase.FirebaseService _firebaseService = firebase.FirebaseService();
  final HiveService _hiveService = HiveService();
  // final connectivity.ConnectivityService _connectivityService =
  //     connectivity.ConnectivityService();
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final ConnectivityService _connectivityService = ConnectivityService();

  late StreamSubscription<ConnectivityResult> connectivitySubscription;

  @observable
  ObservableList<Note> notesList = ObservableList<Note>();

  @observable
  bool loading = false;

  @observable
  bool hasOfflineNotes = false;

  _NoteStore() {
    // Initialize FlutterLocalNotificationsPlugin
    final AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('app_icon');
    final IOSInitializationSettings initializationSettingsIOS =
        IOSInitializationSettings();
    final initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    flutterLocalNotificationsPlugin.initialize(initializationSettings,
        onSelectNotification: onSelectNotification);

    void _openBoxes() async {
      final directory = await getApplicationDocumentsDirectory();
      await Hive.initFlutter(directory.path);
      final notesBox = await Hive.openBox<Note>('notes');
      _noteBox = notesBox;

      notesList = ObservableList<Note>.of(notesBox.values.toList());

      notesBox.watch().listen((event) {
        notesList = ObservableList<Note>.of(notesBox.values.toList());
      });
    }

    _openBoxes();

    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((result) {
      if (result == ConnectivityResult.wifi ||
          result == ConnectivityResult.mobile) {
        syncNotesWithFirebase();
      }
    });
  }

  Future<void> syncNotes() async {
    final connectivityResult = await _connectivityService.checkConnectivity();

    if (connectivityResult == ConnectivityResult.none) {
      return;
    }

    final unsyncedNoteCount = await getUnsyncedNoteCount();
    if (unsyncedNoteCount == 0) {
      return;
    }

    final androidDetails = AndroidNotificationDetails(
      'sync_channel_id',
      'Sync Notes',
      'Displays notifications for notes synchronization',
      importance: Importance.high,
      priority: Priority.high,
      ticker: 'ticker',
    );

    final platformDetails = NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.show(
      0,
      'Sync Notes',
      'There are $unsyncedNoteCount notes remaining to sync.',
      platformDetails,
      payload: 'sync',
    );

    await syncNotesWithFirebase();
  }

  Future<void> onSelectNotification(String? payload) async {
    if (payload != null) {
      print('Notification payload: $payload');
    }
  }

  Future<void> onDidReceiveLocalNotification(
      int id, String title, String body, String payload) async {
    // Handle notification when received
  }

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
      note.key = docId!.toString();
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

  Future<void> showSyncNotification() async {
    final unsyncedNoteCount = await getUnsyncedNoteCount();
    if (unsyncedNoteCount == 0) {
      return;
    }

    final androidDetails = AndroidNotificationDetails(
      'channel_id',
      'Channel Name',
      'Channel Description',
      importance: Importance.high,
      priority: Priority.high,
      ticker: 'ticker',
    );

    final platformDetails = NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.show(
      0,
      'Sync Notes',
      'There are $unsyncedNoteCount notes remaining to sync.',
      platformDetails,
      payload: 'sync',
    );
  }

  Future<void> syncNotesWithFirebase() async {
    // Get all notes from Firebase
    final firebaseNotes = await _firebaseService.getAllNotesFromFirestore();

    // Get all notes locally
    final localNotes = await _hiveService.getAllNotes();

    final offlineNotes = <Note>[];
    final onlineNotes = <Note>[];

    // Check if there are any offline notes in Hive
    for (final note in localNotes) {
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

    // Find notes to add/update in Firebase
    final firebaseNotesToAddOrUpdate = <Note>[];
    for (final localNote in onlineNotes) {
      final firebaseNoteIndex =
          firebaseNotes.indexWhere((note) => note.key == localNote.key);
      if (firebaseNoteIndex == -1) {
        // Local note doesn't exist in Firebase, add it
        firebaseNotesToAddOrUpdate.add(localNote);
      } else {
        final firebaseNote = firebaseNotes[firebaseNoteIndex];
        // Update Firebase note if it's older than local note
        if (firebaseNote.createdTime.isBefore(localNote.createdTime)) {
          firebaseNotesToAddOrUpdate.add(localNote);
        }
      }
    }

    // Add/update notes in Firebase
    for (final note in firebaseNotesToAddOrUpdate) {
      await _firebaseService.updateNote(
        note,
        note.title,
        note.description,
        note.createdTime,
      );
      await _hiveService.setNoteSynced(note.key);
    }

    // Find notes to delete from Firebase
    final firebaseNotesToDelete = <Note>[];
    for (final firebaseNote in firebaseNotes) {
      final localNoteIndex =
          onlineNotes.indexWhere((note) => note.key == firebaseNote.key);
      if (localNoteIndex == -1) {
        // Firebase note doesn't exist locally, delete it
        firebaseNotesToDelete.add(firebaseNote);
      }
    }

    print("Synced notes with Firebase");
  }

  @action
  Future<void> onSyncButtonPressed() async {
    await syncNotesWithFirebase();
  }

  @action
  Future<void> syncNotesFromNotification() async {
    await syncNotesWithFirebase();
  }

  Future<void> init() async {
    await Hive.openBox<Note>('notes');
    _noteBox = Hive.box<Note>('notes');
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((result) {
      if (result == ConnectivityResult.wifi ||
          result == ConnectivityResult.mobile) {
        syncAllNotesFromFirestoreToHive();
      }
    });
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

  Future<int> getUnsyncedNoteCount() async {
    final unsyncedNotes = await _hiveService.getUnsyncedNotes();
    return unsyncedNotes.length;
  }

  Future<void> listenForConnectivityChanges() async {
    _connectivityService.onConnectivityChanged.listen((result) async {
      if (result == ConnectivityResult.mobile ||
          result == ConnectivityResult.wifi) {
        await showSyncNotification();
      }
    });
  }

  Future<void> dispose() async {
    await _connectivitySubscription.cancel();
    await _noteBox.close();
  }

  Future<List> getAllNotes() async {
    return _noteBox.values.toList();
  }

  Future<void> addOrUpdateNote(Note note) async {
    await _noteBox.put(note, note);
    await syncNoteFromHiveToFirestore(note);
  }

  Future<void> deleteNoteById(String id) async {
    await _noteBox.delete(id);
    await FirebaseFirestore.instance.collection('notes').doc(id).delete();
  }

  Future<void> syncNoteFromHiveToFirestore(Note note) async {
    final noteRef =
        FirebaseFirestore.instance.collection('notes').doc(note as String?);
    await noteRef.set(note.toMap());
  }

  Future<void> syncAllNotesFromFirestoreToHive() async {
    final notesRef = FirebaseFirestore.instance.collection('notes');
    final notes = await notesRef.get().then((snapshot) => snapshot.docs);
    for (final noteDoc in notes) {
      final note = Note.fromMap(noteDoc.data());
    }
  }

  void _notesListReaction() {
    print(notesList);
  }
}
