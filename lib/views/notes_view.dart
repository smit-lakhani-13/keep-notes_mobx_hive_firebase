import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:keep_notes/stores/note_store.dart';

class NotesView extends StatefulWidget {
  const NotesView({Key? key}) : super(key: key);

  @override
  _NotesViewState createState() => _NotesViewState();
}

class _NotesViewState extends State<NotesView> {
  final NoteStore _noteStore = NoteStore();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  bool _isEditMode = false;
  int _editIndex = -1;

  @override
  void initState() {
    super.initState();
    _noteStore.init();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notes'),
      ),
      body: Observer(
        builder: (_) {
          if (_noteStore.notesList.isEmpty) {
            return const Center(
              child: Text('No notes found.'),
            );
          } else {
            return ListView.builder(
              itemCount: _noteStore.notesList.length,
              itemBuilder: (_, index) {
                final note = _noteStore.notesList[index];
                return Card(
                  child: ListTile(
                    title: Text(note.title),
                    subtitle: Text(note.description),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () {
                        _noteStore.removeNoteAt(index);
                      },
                    ),
                    onTap: () {
                      _isEditMode = true;
                      _editIndex = index;
                      _titleController.text = note.title;
                      _descriptionController.text = note.description;
                      showDialog(
                        context: context,
                        builder: (_) => _buildAddNoteDialog(),
                      );
                    },
                  ),
                );
              },
            );
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _isEditMode = false;
          _editIndex = -1;
          showDialog(
            context: context,
            builder: (_) => _buildAddNoteDialog(),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildAddNoteDialog() {
    return AlertDialog(
      title: Text(_isEditMode ? 'Edit note' : 'Add note'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              maxLines: null,
              decoration: const InputDecoration(
                labelText: 'Description',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () async {
            if (_titleController.text.isNotEmpty &&
                _descriptionController.text.isNotEmpty) {
              if (_isEditMode) {
                await _noteStore.updateNoteAt(
                  index: _editIndex,
                  title: _titleController.text,
                  description: _descriptionController.text,
                  createdTime: DateTime.now(),
                );
              } else {
                await _noteStore.addNote(
                  title: _titleController.text,
                  description: _descriptionController.text,
                  createdTime: DateTime.now(),
                  key: '',
                );
              }
              Navigator.pop(context);
              _titleController.clear();
              _descriptionController.clear();
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
