import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:keep_notes/models/note_model.dart';
import 'package:keep_notes/notification/background_sync.dart';
import 'package:keep_notes/services/hive_service.dart';
import 'package:workmanager/workmanager.dart';

class ConnectivityService {
  static Future<void> start() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: true,
    );
    await Workmanager().registerOneOffTask(
      syncNotesTaskName,
      syncNotesTaskName,
      existingWorkPolicy: ExistingWorkPolicy.replace,
      initialDelay: Duration(seconds: 5),
    );
  }

  Stream<ConnectivityResult> get connectivityStream =>
      Connectivity().onConnectivityChanged;
  final Connectivity _connectivity = Connectivity();
  final HiveService _hiveService = HiveService();
  final FirebaseService _firebaseService = FirebaseService();
  late AppLifecycleState _lifecycleState;
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  Stream<ConnectivityResult> get onConnectivityChanged =>
      _connectivity.onConnectivityChanged;

  Stream<ConnectivityResult> get onConnectivityStream =>
      _connectivity.onConnectivityChanged;

  // add a boolean variable to track if notes are syncing
  bool isSyncingNotes = false;

  // ConnectivityService(this._lifecycleState);

  Future<void> init() async {
    // initialize FlutterLocalNotificationsPlugin
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    final InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

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
    Connectivity()
        .onConnectivityChanged
        .listen((ConnectivityResult result) async {
      if (result == ConnectivityResult.none) {
        // Handle offline behavior
        return;
      }

      try {
        final List<Note> unsyncedNotes = await _hiveService.getUnsyncedNotes();
        if (unsyncedNotes.isEmpty) {
          return;
        }

        // check if notes are already syncing
        if (isSyncingNotes) {
          return;
        }

        isSyncingNotes = true;

        // Initialize Firebase if it hasn't been initialized yet
        if (Firebase.apps.isEmpty) {
          await Firebase.initializeApp();
        }

        await _firebaseService.syncAllNotesFromHiveToFirestore();

        for (final note in unsyncedNotes) {
          await _hiveService.setNoteSynced(note.key);
        }

        // Check for device's online status and show notification if online and app is not in the foreground
        if (await checkConnection() &&
            _lifecycleState != AppLifecycleState.resumed) {
          await showSyncNotification();
        }
      } catch (error) {
        print('Error syncing notes: $error');
        isSyncingNotes = false;
      }
      // Handle connectivity changes
    });
  }

  final List<Note> notesList = [];

  Future<void> _onConnectivityChanged(ConnectivityResult result) async {}

  Future<void> showSyncNotification() async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'sync_notification_channel_id',
      'Sync Notification Channel',
      'Channel for displaying sync notifications',
      importance: Importance.high,
      priority: Priority.high,
      ticker: 'Syncing notes',
    );

    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidDetails);

    await FlutterLocalNotificationsPlugin().show(
      0,
      'Syncing notes',
      'Notes are being synced',
      notificationDetails,
    );
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

  checkConnectivity() {}

  static void callbackDispatcher() async {
    await _syncNotesTask();
    await _networkStatusTask();
  }

  static Future<void> _networkStatusTask() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult != ConnectivityResult.none) {
      Workmanager().cancelByUniqueName(syncNotesTaskName);
      if (Platform.isAndroid) {
        final androidNotificationDetails = AndroidNotificationDetails(
          'sync_channel_id',
          'Sync Notes',
          'Displays notifications for notes synchronization',
          importance: Importance.high,
          priority: Priority.high,
        );
        final notificationDetails =
            NotificationDetails(android: androidNotificationDetails);
        await FlutterLocalNotificationsPlugin().show(
          0,
          'Sync Notes',
          'Notes can now be synchronized',
          notificationDetails,
          payload: syncNotesTaskName,
        );
      }
    }
  }

  static Future<void> _syncNotesTask() async {
    Workmanager().registerOneOffTask(
      syncNotesTaskName,
      syncNotesTaskName,
      initialDelay: Duration(seconds: 5),
    );
  }
}

class FirebaseService {
  Future<void> syncAllNotesFromHiveToFirestore() async {
    final List<Note> localNotes = await HiveService().getAllNotes();
    final List<Note> unsyncedNotes =
        localNotes.where((note) => !note.synced).toList();

    if (unsyncedNotes.isEmpty) {
      return;
    }

    final batch = FirebaseFirestore.instance.batch();

    for (final note in unsyncedNotes) {
      final noteRef =
          FirebaseFirestore.instance.collection('notes').doc(note.key);

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
