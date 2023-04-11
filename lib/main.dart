import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:keep_notes/views/notes_view.dart';

void main() async {
  // Initialize Firebase
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Run the app
  Application.run();
}

class Application {
  static Future<void> run() async {
    runApp(const MyApp());
  }
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Notes App',
      theme: ThemeData(
        appBarTheme:
            const AppBarTheme(backgroundColor: Colors.black, centerTitle: true),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const NotesView(),
    );
  }
}
