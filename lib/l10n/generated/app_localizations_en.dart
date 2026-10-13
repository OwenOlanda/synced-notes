// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get languageName => 'English';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsSectionGeneral => 'General';

  @override
  String get settingsSectionSaving => 'Saving';

  @override
  String get settingsSectionNotesLocation => 'Notes location';

  @override
  String get settingsSectionAbout => 'About';

  @override
  String get languageTitle => 'Language';

  @override
  String get languageSystem => 'System language';

  @override
  String languageSystemWithCurrent(String language) {
    return 'System language ($language)';
  }

  @override
  String get autosaveTitle => 'Autosave';

  @override
  String get autosaveDescription =>
      'Automatically saves the note after you stop typing, when you leave it and when you close the app. The save button is always available.';

  @override
  String get notesLocationWindows =>
      'Each note is a .txt file inside this folder.';

  @override
  String get notesLocationAndroid =>
      'Notes are stored inside the app. For now they can\'t be seen from the phone\'s file manager.';

  @override
  String get openInExplorer => 'Open in File Explorer';

  @override
  String openFolderError(String error) {
    return 'Couldn\'t open the folder: $error';
  }

  @override
  String version(String version) {
    return 'Version $version';
  }

  @override
  String get versionLoading => 'Version…';

  @override
  String get versionUnknown => 'Unknown version';

  @override
  String get license => 'License';

  @override
  String get licenseDescription => 'GPL-3.0: free and open-source software.';

  @override
  String get sourceCode => 'Source code';

  @override
  String browserOpenError(String url) {
    return 'Couldn\'t open the browser. The address is $url';
  }

  @override
  String get thirdPartyLicenses => 'Third-party licenses';

  @override
  String get thirdPartyLicensesDescription =>
      'Open-source packages used by the app';

  @override
  String get untitled => 'Untitled';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get save => 'Save';

  @override
  String get discard => 'Discard';

  @override
  String get refreshList => 'Refresh list';

  @override
  String get newNote => 'New note';

  @override
  String get noteDeleted => 'Note deleted';

  @override
  String deleteError(String error) {
    return 'Couldn\'t delete: $error';
  }

  @override
  String notesFolderError(String path, String error) {
    return 'Couldn\'t open the notes folder:\n$path\n\n$error';
  }

  @override
  String get retry => 'Try again';

  @override
  String get emptyNotes =>
      'You don\'t have any notes yet.\nTap + to create one.';

  @override
  String get noPreview => 'No text';

  @override
  String get deleteNoteQuestion => 'Delete note?';

  @override
  String deleteNoteWarning(String title) {
    return '\"$title\" will be deleted from the notes folder. This can\'t be undone.';
  }

  @override
  String get statusSaving => 'Saving…';

  @override
  String get statusSaveError => 'Error saving';

  @override
  String get statusNewNote => 'New note';

  @override
  String get statusUnsaved => 'Not saved';

  @override
  String get statusSaved => 'Saved';

  @override
  String saveError(String error) {
    return 'Couldn\'t save: $error';
  }

  @override
  String get emptyNoteNotSaved =>
      'Write a title or some text to save the note.';

  @override
  String get noteSaved => 'Note saved';

  @override
  String get unsavedChangesQuestion => 'Save changes?';

  @override
  String get unsavedChangesMessage => 'This note has unsaved changes.';

  @override
  String get saveFailedTitle => 'Couldn\'t save';

  @override
  String get leaveWithoutSaving => 'Leave without saving';

  @override
  String get stay => 'Stay';

  @override
  String get saveTooltip => 'Save (Ctrl+S)';

  @override
  String get moreOptions => 'More options';

  @override
  String get deleteNote => 'Delete note';

  @override
  String get titleHint => 'Title';

  @override
  String get contentHint => 'Write here…';

  @override
  String errorTitleTooLong(int max) {
    return 'The title can\'t be longer than $max characters.';
  }

  @override
  String get errorTitleForbiddenChars =>
      'The title can\'t contain: / \\ : * ? \" < > |';

  @override
  String get errorTitleControlChars =>
      'The title contains characters that aren\'t allowed.';

  @override
  String get errorNoteNotFound => 'The note is no longer in the folder.';

  @override
  String get errorDuplicateName => 'Another note already has that name.';

  @override
  String get dateYesterday => 'Yesterday';

  @override
  String get dateMonthsShort =>
      'Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec';

  @override
  String dateDayMonth(String day, String month) {
    return '$month $day';
  }

  @override
  String dateDayMonthYear(String day, String month, String year) {
    return '$month $day, $year';
  }

  @override
  String timeOfDay(String hour12, String hour24, String minute, String period) {
    return '$hour12:$minute $period';
  }

  @override
  String get timeAm => 'AM';

  @override
  String get timePm => 'PM';

  @override
  String get errorCollectionNameEmpty => 'Write a name for the collection.';

  @override
  String errorCollectionNameTooLong(int max) {
    return 'The collection name can\'t be longer than $max characters.';
  }

  @override
  String get errorCollectionNameForbiddenChars =>
      'The collection name can\'t contain: / \\ : * ? \" < > |';

  @override
  String get errorCollectionNameReserved =>
      'That name can\'t be used for a collection: it\'s reserved by the system, or it starts or ends with a period.';

  @override
  String get errorCollectionExists =>
      'A collection with that name already exists.';

  @override
  String get errorCollectionNotFound => 'The collection no longer exists.';

  @override
  String get errorPermissionDenied =>
      'The app doesn\'t have permission to change this file or folder.';

  @override
  String get collectionsAll => 'All';

  @override
  String get collectionsNone => 'No collection';

  @override
  String get newCollection => 'New collection';

  @override
  String get collectionNameHint => 'Name';

  @override
  String get create => 'Create';

  @override
  String get rename => 'Rename';

  @override
  String get renameCollection => 'Rename collection';

  @override
  String get collectionColor => 'Color';

  @override
  String get colorNone => 'No color';

  @override
  String deleteCollectionQuestion(String name) {
    return 'Delete the collection \"$name\"?';
  }

  @override
  String get deleteEmptyCollectionMessage => 'The collection is empty.';

  @override
  String deleteCollectionWithNotes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'It has $count notes. What do you want to do with them?',
      one: 'It has 1 note. What do you want to do with it?',
    );
    return '$_temp0';
  }

  @override
  String get moveNotesToNone => 'Move to \"No collection\"';

  @override
  String get deleteNotesToo => 'Delete the notes too';

  @override
  String get collectionDeleted => 'Collection deleted';

  @override
  String get emptyFilter => 'No notes here yet.\nTap + to create one.';

  @override
  String get moveTo => 'Move to…';

  @override
  String get moveNoteTitle => 'Move note to';

  @override
  String get newCollectionEllipsis => 'New collection…';

  @override
  String noteMovedTo(String name) {
    return 'Note moved to \"$name\"';
  }

  @override
  String get noteMovedToNone => 'Note moved to \"No collection\"';

  @override
  String newNoteIn(String name) {
    return 'New note in \"$name\"';
  }

  @override
  String get themeTitle => 'Theme';

  @override
  String get themeSystem => 'System default';

  @override
  String themeSystemWithCurrent(String theme) {
    return 'System default ($theme)';
  }

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';
}
