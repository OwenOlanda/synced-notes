import '../models/note.dart';
import '../services/app_settings.dart' show NoteOrder;
import '../services/note_storage.dart';
import 'note_search.dart';

/// Ordena notas según [order].
///
/// - [opened]: cuándo se abrió cada nota en este dispositivo (id →
///   milisegundos, ver `AppSettings.noteOpenedTimes`). Una nota cuenta como
///   abierta al menos cuando se editó por última vez (editarla es abrirla):
///   así las que nunca se abrieron aquí también quedan en un lugar lógico.
/// - [groupOrder]: los grupos en su orden (para [NoteOrder.byGroup]); las
///   notas sin grupo van al final.
///
/// Los empates se resuelven por la edición más reciente y luego por la
/// fecha de creación: el orden nunca "baila" entre una vez y otra.
List<Note> sortNotes(
  Iterable<Note> notes,
  NoteOrder order, {
  Map<String, int> opened = const {},
  List<String> groupOrder = const [],
}) {
  final list = notes.toList();

  int edited(Note a, Note b) {
    final byEdit = b.modifiedAt.compareTo(a.modifiedAt);
    return byEdit != 0 ? byEdit : b.createdAt.compareTo(a.createdAt);
  }

  int openedAt(Note n) {
    final edit = n.modifiedAt.millisecondsSinceEpoch;
    final open = opened[NoteStorage.noteId(n)] ?? 0;
    return open > edit ? open : edit;
  }

  final titles = <Note, String>{
    if (order == NoteOrder.titleAz || order == NoteOrder.titleZa)
      for (final n in list) n: NoteSearch.normalize(n.title.trim()),
  };
  int byTitle(Note a, Note b, {required bool reverse}) {
    final ta = titles[a]!, tb = titles[b]!;
    // Sin título: siempre al final.
    if (ta.isEmpty != tb.isEmpty) return ta.isEmpty ? 1 : -1;
    final c = reverse ? tb.compareTo(ta) : ta.compareTo(tb);
    return c != 0 ? c : edited(a, b);
  }

  int groupRank(Note n) {
    final g = n.group;
    if (g == null) return groupOrder.length + 1; // Sin grupo, al final
    final i = groupOrder.indexOf(g);
    return i < 0 ? groupOrder.length : i;
  }

  final int Function(Note, Note) compare = switch (order) {
    NoteOrder.edited => edited,
    NoteOrder.opened => (a, b) {
        final c = openedAt(b).compareTo(openedAt(a));
        return c != 0 ? c : edited(a, b);
      },
    NoteOrder.created => (a, b) {
        final c = b.createdAt.compareTo(a.createdAt);
        return c != 0 ? c : edited(a, b);
      },
    NoteOrder.byGroup => (a, b) {
        final c = groupRank(a).compareTo(groupRank(b));
        if (c != 0) return c;
        final byName = (a.group ?? '').compareTo(b.group ?? '');
        return byName != 0 ? byName : edited(a, b);
      },
    NoteOrder.titleAz => (a, b) => byTitle(a, b, reverse: false),
    NoteOrder.titleZa => (a, b) => byTitle(a, b, reverse: true),
  };
  list.sort(compare);
  return list;
}
