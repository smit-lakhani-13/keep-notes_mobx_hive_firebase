import 'dart:async';
import 'package:connectivity/connectivity.dart';
import 'package:flutter/material.dart';
import 'package:keep_notes/stores/note_store.dart';
import 'package:workmanager/workmanager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

const String syncNotesTaskName = 'sync_notes_task';

class BackgroundSync {
  static void initialize() {
    Workmanager().initialize(
      _callbackDispatcher,
      isInDebugMode: false,
    );
  }

  static const String _syncNotesTask = "syncNotesTask";
  static const String _networkStatusTask = "networkStatusTask";

  static Future<bool> _syncNotesTaskHandler(
      String task, Map<String, dynamic>? inputData) async {
    if (task == _syncNotesTask) {
      final noteStore = NoteStore();
      await noteStore.syncNotesWithFirebase();
      await noteStore.showSyncNotification();
    }
    return true;
  }

  static Future<bool> _networkStatusTaskHandler(
      String task, Map<String, dynamic>? inputData) async {
    if (task == _networkStatusTask) {
      final ConnectivityResult connectivityResult =
          await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.mobile ||
          connectivityResult == ConnectivityResult.wifi) {
        await Workmanager().cancelByUniqueName(_networkStatusTask);
        executeTask();
      }
    }
    return true;
  }

  static void registerOneOffTask() {
    Workmanager().registerOneOffTask(
      _syncNotesTask,
      _syncNotesTask,
      initialDelay: Duration(seconds: 30),
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresCharging: false,
        requiresDeviceIdle: true,
      ),
    );
  }

  static void registerPeriodicTask() {
    Workmanager().registerPeriodicTask(
      'syncNotes',
      _syncNotesTask,
      frequency: Duration(seconds: 1),
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresCharging: false,
        requiresDeviceIdle: true,
      ),
    );
  }

  static void registerNetworkStatusTask() {
    Workmanager().registerPeriodicTask(
      _networkStatusTask,
      _networkStatusTask,
      frequency: const Duration(seconds: 1),
      constraints: Constraints(
        networkType: NetworkType.not_required,
        requiresCharging: false,
        requiresDeviceIdle: false,
      ),
    );
  }

  static void _callbackDispatcher() async {
    Workmanager().executeTask(_syncNotesTaskHandler);
    Workmanager().executeTask(_networkStatusTaskHandler);
  }

  static void executeTask() {
    Workmanager().executeTask(_syncNotesTaskHandler);
  }

  static void startConnectivityListener() {
    Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      if (result == ConnectivityResult.mobile ||
          result == ConnectivityResult.wifi) {
        executeTask();
      }
    });
  }

  static void initializeNotifications() {
    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    final androidInitializationSettings =
        AndroidInitializationSettings('app_icon');
    final iosInitializationSettings = IOSInitializationSettings();
    final initializationSettings = InitializationSettings(
        android: androidInitializationSettings, iOS: iosInitializationSettings);
    flutterLocalNotificationsPlugin.initialize(initializationSettings,
        onSelectNotification: (String? payload) async {});
  }
}
