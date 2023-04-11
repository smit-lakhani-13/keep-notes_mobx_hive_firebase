import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:keep_notes/models/note_model.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String?> addNote(Note note) async {
    try {
      DocumentReference docRef = await _firestore.collection('notes').add({
        'title': note.title,
        'description': note.description,
        'created': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    } catch (e) {
      print(e.toString());
      return null;
    }
  }

  Future<void> updateNote(Note note) async {
    try {
      await _firestore.collection('notes').doc(note.key).update({
        'title': note.title,
        'description': note.description,
      });
    } catch (e) {
      print(e.toString());
    }
  }

  Future<void> deleteNote(String id) async {
    try {
      await _firestore.collection('notes').doc(id).delete();
    } catch (e) {
      print(e.toString());
    }
  }

  Future<List<Note>?> getAllNotes() async {
    try {
      QuerySnapshot querySnapshot = await _firestore.collection('notes').get();
      List<Note> notes = [];
      querySnapshot.docs.forEach((doc) {
        Note note = Note(
          title: doc.get('title'),
          description: doc.get('description'),
          createdTime: (doc.get('created') as Timestamp).toDate(),
          key: doc.id,
        );
        notes.add(note);
      });
      return notes;
    } catch (e) {
      print(e.toString());
      return null;
    }
  }
}
