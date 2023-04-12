import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:keep_notes/stores/note_store.dart';
import 'package:intl/intl.dart';

class NotesView extends StatefulWidget {
  const NotesView({Key? key}) : super(key: key);

  @override
  _NotesViewState createState() => _NotesViewState();
}

class _NotesViewState extends State<NotesView>
    with SingleTickerProviderStateMixin {
  final NoteStore _noteStore = NoteStore();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  bool _isEditMode = false;
  int _editIndex = -1;

  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _noteStore.init();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _startAnimation() {
    _animationController.reset();
    _animationController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notes'),
      ),
      body: Observer(builder: (_) {
        if (_noteStore.notesList.isEmpty) {
          return const Center(
            child: Text('No notes found.'),
          );
        } else {
          return ListView.builder(
            itemCount: _noteStore.notesList.length,
            itemBuilder: (_, index) {
              final note = _noteStore.notesList[index];
              return InkWell(
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
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                note.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18.0,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                note.description,
                                style: const TextStyle(
                                  fontSize: 14.0,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Created: ${DateFormat.yMd().add_jm().format(note.createdTime)}',
                                style:
                                    TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          color: Colors.black,
                          onPressed: () {
                            _noteStore.removeNoteAt(index);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        }
      }),
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
        backgroundColor: Colors.indigo.shade400,
      ),
    );
  }

  Widget _buildAddNoteDialog() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: MediaQuery.of(context).size.width,
      height: _isEditMode ? 300.0 : 220.0,
      child: AlertDialog(
        title: Text(
          _isEditMode ? 'Edit note' : 'Add note',
          style: const TextStyle(
            color: Colors.blue,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  labelStyle: TextStyle(color: Colors.blue),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.blue),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                maxLines: null,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  labelStyle: TextStyle(color: Colors.blue),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.blue),
                  ),
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
      ),
    );
  }
}
