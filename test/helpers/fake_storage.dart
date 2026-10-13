import 'dart:io';

import 'package:synced_notes/models/note_group.dart';
import 'package:synced_notes/models/note.dart';
import 'package:synced_notes/services/note_storage.dart';

/// Almacenamiento de mentira, todo en memoria: no toca el disco.
/// Sirve para las pruebas de pantallas (las pruebas de widgets no se llevan
/// bien con archivos reales). Las reglas de verdad se prueban aparte, con
/// NoteStorage real, en note_storage_test y groups_test.
class FakeStorage extends NoteStorage {
  FakeStorage({List<Note>? notes, List<NoteGroup>? groups})
      : notes = [...?notes],
        groups = [...?groups],
        super(Directory('no-se-usa'));

  final List<Note> notes;
  final List<NoteGroup> groups;

  @override
  Future<List<Note>> listNotes() async => [...notes];

  @override
  Future<List<NoteGroup>> listGroups() async => [...groups]
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  @override
  Future<void> deleteNote(String fileName, {String? group}) async {
    notes.removeWhere(
        (n) => n.fileName == fileName && n.group == group);
  }

  @override
  Future<Note> saveNote(Note note) async {
    final saved = note.copyWith(
      fileName: NoteStorage.fileNameFor(note.title, note.createdAt),
      modifiedAt: DateTime.now(),
    );
    final index = notes.indexWhere(
        (n) => n.fileName == note.fileName && n.group == note.group);
    if (note.isSaved && index >= 0) {
      notes[index] = saved;
    } else {
      notes.add(saved);
    }
    return saved;
  }

  @override
  Future<Note> moveNote(Note note, String? toGroup) async {
    final moved = note.withGroup(toGroup);
    final index = notes.indexWhere(
        (n) => n.fileName == note.fileName && n.group == note.group);
    if (index >= 0) notes[index] = moved;
    return moved;
  }

  @override
  Future<NoteGroup> createGroup(String name,
      {GroupColor? color}) async {
    final error = NoteStorage.validateGroupName(name);
    if (error != null) throw NoteStorageException(error);
    final trimmed = name.trim();
    if (groups
        .any((c) => c.name.toLowerCase() == trimmed.toLowerCase())) {
      throw NoteStorageException(NoteError.groupExists);
    }
    final created = NoteGroup(name: trimmed, color: color);
    groups.add(created);
    return created;
  }

  @override
  Future<NoteGroup> renameGroup(String oldName, String newName) async {
    final index = groups.indexWhere((c) => c.name == oldName);
    final renamed =
        NoteGroup(name: newName.trim(), color: groups[index].color);
    groups[index] = renamed;
    for (var i = 0; i < notes.length; i++) {
      if (notes[i].group == oldName) {
        notes[i] = notes[i].withGroup(renamed.name);
      }
    }
    return renamed;
  }

  @override
  Future<void> setGroupColor(String name, GroupColor? color) async {
    final index = groups.indexWhere((c) => c.name == name);
    groups[index] = NoteGroup(name: name, color: color);
  }

  @override
  Future<void> deleteGroup(String name,
      {required bool deleteNotes}) async {
    groups.removeWhere((c) => c.name == name);
    if (deleteNotes) {
      notes.removeWhere((n) => n.group == name);
    } else {
      for (var i = 0; i < notes.length; i++) {
        if (notes[i].group == name) notes[i] = notes[i].withGroup(null);
      }
    }
  }
}
