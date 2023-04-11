// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'note_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$NoteStore on _NoteStore, Store {
  late final _$notesListAtom =
      Atom(name: '_NoteStore.notesList', context: context);

  @override
  ObservableList<Note> get notesList {
    _$notesListAtom.reportRead();
    return super.notesList;
  }

  @override
  set notesList(ObservableList<Note> value) {
    _$notesListAtom.reportWrite(value, super.notesList, () {
      super.notesList = value;
    });
  }

  late final _$addNoteAsyncAction =
      AsyncAction('_NoteStore.addNote', context: context);

  @override
  Future<void> addNote(
      {required String title,
      required String description,
      required DateTime createdTime,
      required String key}) {
    return _$addNoteAsyncAction.run(() => super.addNote(
        title: title,
        description: description,
        createdTime: createdTime,
        key: key));
  }

  late final _$removeNoteAtAsyncAction =
      AsyncAction('_NoteStore.removeNoteAt', context: context);

  @override
  Future<void> removeNoteAt(int index) {
    return _$removeNoteAtAsyncAction.run(() => super.removeNoteAt(index));
  }

  late final _$updateNoteAtAsyncAction =
      AsyncAction('_NoteStore.updateNoteAt', context: context);

  @override
  Future<void> updateNoteAt(
      {required int index,
      required String title,
      required String description,
      required DateTime createdTime}) {
    return _$updateNoteAtAsyncAction.run(() => super.updateNoteAt(
        index: index,
        title: title,
        description: description,
        createdTime: createdTime));
  }

  @override
  String toString() {
    return '''
notesList: ${notesList}
    ''';
  }
}
