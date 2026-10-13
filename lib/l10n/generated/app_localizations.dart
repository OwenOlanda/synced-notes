import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
  ];

  /// Name of this language written in this same language. Shown in the language picker so everyone can recognize their own language.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageName;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsSectionGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get settingsSectionGeneral;

  /// No description provided for @settingsSectionSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving'**
  String get settingsSectionSaving;

  /// No description provided for @settingsSectionNotesLocation.
  ///
  /// In en, this message translates to:
  /// **'Notes location'**
  String get settingsSectionNotesLocation;

  /// No description provided for @settingsSectionAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsSectionAbout;

  /// No description provided for @languageTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageTitle;

  /// Option in the language picker: follow the language of the phone or PC.
  ///
  /// In en, this message translates to:
  /// **'System language'**
  String get languageSystem;

  /// Current choice shown in Settings when following the system language. {language} is the language actually in use, e.g. 'English'.
  ///
  /// In en, this message translates to:
  /// **'System language ({language})'**
  String languageSystemWithCurrent(String language);

  /// No description provided for @autosaveTitle.
  ///
  /// In en, this message translates to:
  /// **'Autosave'**
  String get autosaveTitle;

  /// No description provided for @autosaveDescription.
  ///
  /// In en, this message translates to:
  /// **'Automatically saves the note after you stop typing, when you leave it and when you close the app. The save button is always available.'**
  String get autosaveDescription;

  /// No description provided for @notesLocationWindows.
  ///
  /// In en, this message translates to:
  /// **'Each note is a .txt file inside this folder.'**
  String get notesLocationWindows;

  /// No description provided for @notesLocationAndroid.
  ///
  /// In en, this message translates to:
  /// **'Notes are stored inside the app. For now they can\'t be seen from the phone\'s file manager.'**
  String get notesLocationAndroid;

  /// No description provided for @openInExplorer.
  ///
  /// In en, this message translates to:
  /// **'Open in File Explorer'**
  String get openInExplorer;

  /// No description provided for @openFolderError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the folder: {error}'**
  String openFolderError(String error);

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String version(String version);

  /// No description provided for @versionLoading.
  ///
  /// In en, this message translates to:
  /// **'Version…'**
  String get versionLoading;

  /// No description provided for @versionUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown version'**
  String get versionUnknown;

  /// No description provided for @license.
  ///
  /// In en, this message translates to:
  /// **'License'**
  String get license;

  /// No description provided for @licenseDescription.
  ///
  /// In en, this message translates to:
  /// **'GPL-3.0: free and open-source software.'**
  String get licenseDescription;

  /// No description provided for @sourceCode.
  ///
  /// In en, this message translates to:
  /// **'Source code'**
  String get sourceCode;

  /// No description provided for @browserOpenError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the browser. The address is {url}'**
  String browserOpenError(String url);

  /// No description provided for @thirdPartyLicenses.
  ///
  /// In en, this message translates to:
  /// **'Third-party licenses'**
  String get thirdPartyLicenses;

  /// No description provided for @thirdPartyLicensesDescription.
  ///
  /// In en, this message translates to:
  /// **'Open-source packages used by the app'**
  String get thirdPartyLicensesDescription;

  /// Shown instead of the title for notes without one.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get untitled;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// No description provided for @refreshList.
  ///
  /// In en, this message translates to:
  /// **'Refresh list'**
  String get refreshList;

  /// Tooltip of the + button.
  ///
  /// In en, this message translates to:
  /// **'New note'**
  String get newNote;

  /// No description provided for @noteDeleted.
  ///
  /// In en, this message translates to:
  /// **'Note deleted'**
  String get noteDeleted;

  /// No description provided for @deleteError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete: {error}'**
  String deleteError(String error);

  /// No description provided for @notesFolderError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the notes folder:\n{path}\n\n{error}'**
  String notesFolderError(String path, String error);

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get retry;

  /// No description provided for @emptyNotes.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have any notes yet.\nTap + to create one.'**
  String get emptyNotes;

  /// Preview shown in the list for a note with a title but no text.
  ///
  /// In en, this message translates to:
  /// **'No text'**
  String get noPreview;

  /// No description provided for @deleteNoteQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete note?'**
  String get deleteNoteQuestion;

  /// No description provided for @deleteNoteWarning.
  ///
  /// In en, this message translates to:
  /// **'\"{title}\" will be deleted from the notes folder. This can\'t be undone.'**
  String deleteNoteWarning(String title);

  /// No description provided for @statusSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get statusSaving;

  /// No description provided for @statusSaveError.
  ///
  /// In en, this message translates to:
  /// **'Error saving'**
  String get statusSaveError;

  /// Editor status: a new note that is still empty.
  ///
  /// In en, this message translates to:
  /// **'New note'**
  String get statusNewNote;

  /// No description provided for @statusUnsaved.
  ///
  /// In en, this message translates to:
  /// **'Not saved'**
  String get statusUnsaved;

  /// No description provided for @statusSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get statusSaved;

  /// No description provided for @saveError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save: {error}'**
  String saveError(String error);

  /// No description provided for @emptyNoteNotSaved.
  ///
  /// In en, this message translates to:
  /// **'Write a title or some text to save the note.'**
  String get emptyNoteNotSaved;

  /// No description provided for @noteSaved.
  ///
  /// In en, this message translates to:
  /// **'Note saved'**
  String get noteSaved;

  /// No description provided for @unsavedChangesQuestion.
  ///
  /// In en, this message translates to:
  /// **'Save changes?'**
  String get unsavedChangesQuestion;

  /// No description provided for @unsavedChangesMessage.
  ///
  /// In en, this message translates to:
  /// **'This note has unsaved changes.'**
  String get unsavedChangesMessage;

  /// No description provided for @saveFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save'**
  String get saveFailedTitle;

  /// No description provided for @leaveWithoutSaving.
  ///
  /// In en, this message translates to:
  /// **'Leave without saving'**
  String get leaveWithoutSaving;

  /// No description provided for @stay.
  ///
  /// In en, this message translates to:
  /// **'Stay'**
  String get stay;

  /// No description provided for @saveTooltip.
  ///
  /// In en, this message translates to:
  /// **'Save (Ctrl+S)'**
  String get saveTooltip;

  /// No description provided for @moreOptions.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get moreOptions;

  /// No description provided for @deleteNote.
  ///
  /// In en, this message translates to:
  /// **'Delete note'**
  String get deleteNote;

  /// No description provided for @titleHint.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get titleHint;

  /// No description provided for @contentHint.
  ///
  /// In en, this message translates to:
  /// **'Write here…'**
  String get contentHint;

  /// No description provided for @errorTitleTooLong.
  ///
  /// In en, this message translates to:
  /// **'The title can\'t be longer than {max} characters.'**
  String errorTitleTooLong(int max);

  /// No description provided for @errorTitleForbiddenChars.
  ///
  /// In en, this message translates to:
  /// **'The title can\'t contain: / \\ : * ? \" < > |'**
  String get errorTitleForbiddenChars;

  /// No description provided for @errorTitleControlChars.
  ///
  /// In en, this message translates to:
  /// **'The title contains characters that aren\'t allowed.'**
  String get errorTitleControlChars;

  /// No description provided for @errorNoteNotFound.
  ///
  /// In en, this message translates to:
  /// **'The note is no longer in the folder.'**
  String get errorNoteNotFound;

  /// No description provided for @errorDuplicateName.
  ///
  /// In en, this message translates to:
  /// **'Another note already has that name.'**
  String get errorDuplicateName;

  /// Short date in the notes list for something modified yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get dateYesterday;

  /// The 12 short month names, January to December, separated by |. Used by dateDayMonth and dateDayMonthYear.
  ///
  /// In en, this message translates to:
  /// **'Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec'**
  String get dateMonthsShort;

  /// Short date in the notes list for this year, e.g. 'Oct 3'.
  ///
  /// In en, this message translates to:
  /// **'{month} {day}'**
  String dateDayMonth(String day, String month);

  /// Short date in the notes list for another year, e.g. 'Oct 3, 2025'.
  ///
  /// In en, this message translates to:
  /// **'{month} {day}, {year}'**
  String dateDayMonthYear(String day, String month, String year);

  /// Time in the notes list for something modified today. Use either the 12-hour clock (hour12 + period) or the 24-hour clock (hour24).
  ///
  /// In en, this message translates to:
  /// **'{hour12}:{minute} {period}'**
  String timeOfDay(String hour12, String hour24, String minute, String period);

  /// Morning mark for the 12-hour clock in timeOfDay (only if this language uses it).
  ///
  /// In en, this message translates to:
  /// **'AM'**
  String get timeAm;

  /// Afternoon mark for the 12-hour clock in timeOfDay (only if this language uses it).
  ///
  /// In en, this message translates to:
  /// **'PM'**
  String get timePm;

  /// No description provided for @errorCollectionNameEmpty.
  ///
  /// In en, this message translates to:
  /// **'Write a name for the collection.'**
  String get errorCollectionNameEmpty;

  /// No description provided for @errorCollectionNameTooLong.
  ///
  /// In en, this message translates to:
  /// **'The collection name can\'t be longer than {max} characters.'**
  String errorCollectionNameTooLong(int max);

  /// No description provided for @errorCollectionNameForbiddenChars.
  ///
  /// In en, this message translates to:
  /// **'The collection name can\'t contain: / \\ : * ? \" < > |'**
  String get errorCollectionNameForbiddenChars;

  /// No description provided for @errorCollectionNameReserved.
  ///
  /// In en, this message translates to:
  /// **'That name can\'t be used for a collection: it\'s reserved by the system, or it starts or ends with a period.'**
  String get errorCollectionNameReserved;

  /// No description provided for @errorCollectionExists.
  ///
  /// In en, this message translates to:
  /// **'A collection with that name already exists.'**
  String get errorCollectionExists;

  /// No description provided for @errorCollectionNotFound.
  ///
  /// In en, this message translates to:
  /// **'The collection no longer exists.'**
  String get errorCollectionNotFound;

  /// No description provided for @errorPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'The app doesn\'t have permission to change this file or folder.'**
  String get errorPermissionDenied;

  /// Chip that shows all notes, from every collection.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get collectionsAll;

  /// Chip that shows only the notes that aren't in any collection.
  ///
  /// In en, this message translates to:
  /// **'No collection'**
  String get collectionsNone;

  /// No description provided for @newCollection.
  ///
  /// In en, this message translates to:
  /// **'New collection'**
  String get newCollection;

  /// No description provided for @collectionNameHint.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get collectionNameHint;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @renameCollection.
  ///
  /// In en, this message translates to:
  /// **'Rename collection'**
  String get renameCollection;

  /// No description provided for @collectionColor.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get collectionColor;

  /// No description provided for @colorNone.
  ///
  /// In en, this message translates to:
  /// **'No color'**
  String get colorNone;

  /// No description provided for @deleteCollectionQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete the collection \"{name}\"?'**
  String deleteCollectionQuestion(String name);

  /// No description provided for @deleteEmptyCollectionMessage.
  ///
  /// In en, this message translates to:
  /// **'The collection is empty.'**
  String get deleteEmptyCollectionMessage;

  /// No description provided for @deleteCollectionWithNotes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{It has 1 note. What do you want to do with it?} other{It has {count} notes. What do you want to do with them?}}'**
  String deleteCollectionWithNotes(int count);

  /// Option when deleting a collection: keep its notes, without a collection.
  ///
  /// In en, this message translates to:
  /// **'Move to \"No collection\"'**
  String get moveNotesToNone;

  /// No description provided for @deleteNotesToo.
  ///
  /// In en, this message translates to:
  /// **'Delete the notes too'**
  String get deleteNotesToo;

  /// No description provided for @collectionDeleted.
  ///
  /// In en, this message translates to:
  /// **'Collection deleted'**
  String get collectionDeleted;

  /// Shown when the selected collection (or 'No collection') has no notes.
  ///
  /// In en, this message translates to:
  /// **'No notes here yet.\nTap + to create one.'**
  String get emptyFilter;

  /// No description provided for @moveTo.
  ///
  /// In en, this message translates to:
  /// **'Move to…'**
  String get moveTo;

  /// No description provided for @moveNoteTitle.
  ///
  /// In en, this message translates to:
  /// **'Move note to'**
  String get moveNoteTitle;

  /// No description provided for @newCollectionEllipsis.
  ///
  /// In en, this message translates to:
  /// **'New collection…'**
  String get newCollectionEllipsis;

  /// No description provided for @noteMovedTo.
  ///
  /// In en, this message translates to:
  /// **'Note moved to \"{name}\"'**
  String noteMovedTo(String name);

  /// No description provided for @noteMovedToNone.
  ///
  /// In en, this message translates to:
  /// **'Note moved to \"No collection\"'**
  String get noteMovedToNone;

  /// Tooltip of the + button while viewing a collection.
  ///
  /// In en, this message translates to:
  /// **'New note in \"{name}\"'**
  String newNoteIn(String name);

  /// No description provided for @themeTitle.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get themeTitle;

  /// Theme option: follow the light/dark setting of the phone or PC.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get themeSystem;

  /// Current choice shown in Settings when following the system. {theme} is the theme actually in use, e.g. 'Dark'.
  ///
  /// In en, this message translates to:
  /// **'System default ({theme})'**
  String themeSystemWithCurrent(String theme);

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
