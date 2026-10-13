import 'dart:io';

import 'package:synced_notes/models/collection.dart';
import 'package:synced_notes/models/note.dart';
import 'package:synced_notes/services/note_storage.dart';

/// Almacenamiento de mentira, todo en memoria: no toca el disco.
/// Sirve para las pruebas de pantallas (las pruebas de widgets no se llevan
/// bien con archivos reales). Las reglas de verdad se prueban aparte, con
/// NoteStorage real, en note_storage_test y collections_test.
class FakeStorage extends NoteStorage {
  FakeStorage({List<Note>? notes, List<Collection>? collections})
      : notes = [...?notes],
        collections = [...?collections],
        super(Directory('no-se-usa'));

  final List<Note> notes;
  final List<Collection> collections;

  @override
  Future<List<Note>> listNotes() async => [...notes];

  @override
  Future<List<Collection>> listCollections() async => [...collections]
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  @override
  Future<void> deleteNote(String fileName, {String? collection}) async {
    notes.removeWhere(
        (n) => n.fileName == fileName && n.collection == collection);
  }

  @override
  Future<Note> moveNote(Note note, String? toCollection) async {
    final moved = note.withCollection(toCollection);
    final index = notes.indexWhere(
        (n) => n.fileName == note.fileName && n.collection == note.collection);
    if (index >= 0) notes[index] = moved;
    return moved;
  }

  @override
  Future<Collection> createCollection(String name,
      {CollectionColor? color}) async {
    final error = NoteStorage.validateCollectionName(name);
    if (error != null) throw NoteStorageException(error);
    final trimmed = name.trim();
    if (collections
        .any((c) => c.name.toLowerCase() == trimmed.toLowerCase())) {
      throw NoteStorageException(NoteError.collectionExists);
    }
    final created = Collection(name: trimmed, color: color);
    collections.add(created);
    return created;
  }

  @override
  Future<Collection> renameCollection(String oldName, String newName) async {
    final index = collections.indexWhere((c) => c.name == oldName);
    final renamed =
        Collection(name: newName.trim(), color: collections[index].color);
    collections[index] = renamed;
    for (var i = 0; i < notes.length; i++) {
      if (notes[i].collection == oldName) {
        notes[i] = notes[i].withCollection(renamed.name);
      }
    }
    return renamed;
  }

  @override
  Future<void> setCollectionColor(String name, CollectionColor? color) async {
    final index = collections.indexWhere((c) => c.name == name);
    collections[index] = Collection(name: name, color: color);
  }

  @override
  Future<void> deleteCollection(String name,
      {required bool deleteNotes}) async {
    collections.removeWhere((c) => c.name == name);
    if (deleteNotes) {
      notes.removeWhere((n) => n.collection == name);
    } else {
      for (var i = 0; i < notes.length; i++) {
        if (notes[i].collection == name) notes[i] = notes[i].withCollection(null);
      }
    }
  }
}
