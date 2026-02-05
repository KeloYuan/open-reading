import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
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

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
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
    Locale('zh')
  ];

  /// The title of the application
  ///
  /// In en, this message translates to:
  /// **'XiaoYuan Reader'**
  String get appTitle;

  /// Home tab label
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// Library tab label
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get library;

  /// Settings tab label
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// Statistics tab label
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get statistics;

  /// Reading page title
  ///
  /// In en, this message translates to:
  /// **'Reading'**
  String get reading;

  /// Import books button label
  ///
  /// In en, this message translates to:
  /// **'Import Books'**
  String get importBooks;

  /// Dark mode setting label
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkMode;

  /// Light mode setting label
  ///
  /// In en, this message translates to:
  /// **'Light Mode'**
  String get lightMode;

  /// System theme mode setting label
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get systemMode;

  /// Theme setting section
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// Accent color setting label
  ///
  /// In en, this message translates to:
  /// **'Accent Color'**
  String get accent;

  /// Bookmarks feature label
  ///
  /// In en, this message translates to:
  /// **'Bookmarks'**
  String get bookmarks;

  /// Notes feature label
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// Highlights feature label
  ///
  /// In en, this message translates to:
  /// **'Highlights'**
  String get highlights;

  /// TTS reading feature label
  ///
  /// In en, this message translates to:
  /// **'Text-to-Speech'**
  String get ttsReading;

  /// Share button label
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// Share content dialog title
  ///
  /// In en, this message translates to:
  /// **'Share Content'**
  String get shareContent;

  /// Share current page option
  ///
  /// In en, this message translates to:
  /// **'Share Current Page'**
  String get shareCurrentPage;

  /// Share selected text option
  ///
  /// In en, this message translates to:
  /// **'Share Selected Text'**
  String get shareSelectedText;

  /// Share reading progress option
  ///
  /// In en, this message translates to:
  /// **'Share Reading Progress'**
  String get shareProgress;

  /// Play TTS button
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get play;

  /// Pause TTS button
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// Stop TTS button
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop;

  /// TTS speed setting
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get speed;

  /// TTS pitch setting
  ///
  /// In en, this message translates to:
  /// **'Pitch'**
  String get pitch;

  /// Language setting
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// Font size setting
  ///
  /// In en, this message translates to:
  /// **'Font Size'**
  String get fontSize;

  /// Reading progress indicator
  ///
  /// In en, this message translates to:
  /// **'Reading Progress'**
  String get readingProgress;

  /// Total pages label
  ///
  /// In en, this message translates to:
  /// **'Total Pages'**
  String get totalPages;

  /// Current page label
  ///
  /// In en, this message translates to:
  /// **'Current Page'**
  String get currentPage;

  /// Reading time statistics
  ///
  /// In en, this message translates to:
  /// **'Reading Time'**
  String get readingTime;

  /// Books read statistics
  ///
  /// In en, this message translates to:
  /// **'Books Read'**
  String get booksRead;

  /// Today's reading time
  ///
  /// In en, this message translates to:
  /// **'Today\'s Reading'**
  String get todayReading;

  /// Cancel button
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Confirm button
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// Delete button
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// Edit button
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// Save button
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Back button
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// Next button
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// Previous button
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get previous;

  /// Search function
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No search results message
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get noResults;

  /// Loading indicator text
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// Error message
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @initializationFailed.
  ///
  /// In en, this message translates to:
  /// **'Initialization failed'**
  String get initializationFailed;

  /// No description provided for @unknownError.
  ///
  /// In en, this message translates to:
  /// **'Unknown error'**
  String get unknownError;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @appearanceSettings.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearanceSettings;

  /// No description provided for @readingTips.
  ///
  /// In en, this message translates to:
  /// **'Reading Tips'**
  String get readingTips;

  /// No description provided for @readingFontSettingsMoved.
  ///
  /// In en, this message translates to:
  /// **'Reading font settings moved'**
  String get readingFontSettingsMoved;

  /// No description provided for @readingFontSettingsHint.
  ///
  /// In en, this message translates to:
  /// **'Open any book, tap the center of the screen, then use the bottom toolbar to adjust font size, line spacing, letter spacing, margins, and reading font.'**
  String get readingFontSettingsHint;

  /// No description provided for @readingSettings.
  ///
  /// In en, this message translates to:
  /// **'Reading Settings'**
  String get readingSettings;

  /// No description provided for @bookSource.
  ///
  /// In en, this message translates to:
  /// **'Sources'**
  String get bookSource;

  /// No description provided for @bookSourceFeatures.
  ///
  /// In en, this message translates to:
  /// **'Book Sources'**
  String get bookSourceFeatures;

  /// No description provided for @enableBookSource.
  ///
  /// In en, this message translates to:
  /// **'Enable book sources'**
  String get enableBookSource;

  /// No description provided for @enableBookSourceHint.
  ///
  /// In en, this message translates to:
  /// **'Enable online book search and reading'**
  String get enableBookSourceHint;

  /// No description provided for @bookSourceEnabledHint.
  ///
  /// In en, this message translates to:
  /// **'When enabled, you will see the \"Sources\" tab for online search and reading.'**
  String get bookSourceEnabledHint;

  /// No description provided for @enableTts.
  ///
  /// In en, this message translates to:
  /// **'Enable TTS'**
  String get enableTts;

  /// No description provided for @enableTtsHint.
  ///
  /// In en, this message translates to:
  /// **'Enable text-to-speech reading'**
  String get enableTtsHint;

  /// No description provided for @ttsSpeedLabel.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get ttsSpeedLabel;

  /// No description provided for @ttsSpeedHint.
  ///
  /// In en, this message translates to:
  /// **'Adjust reading speed'**
  String get ttsSpeedHint;

  /// No description provided for @ttsVolumeLabel.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get ttsVolumeLabel;

  /// No description provided for @ttsVolumeHint.
  ///
  /// In en, this message translates to:
  /// **'Adjust reading volume'**
  String get ttsVolumeHint;

  /// No description provided for @ttsPitchLabel.
  ///
  /// In en, this message translates to:
  /// **'Pitch'**
  String get ttsPitchLabel;

  /// No description provided for @ttsPitchHint.
  ///
  /// In en, this message translates to:
  /// **'Adjust reading pitch'**
  String get ttsPitchHint;

  /// No description provided for @cloudSync.
  ///
  /// In en, this message translates to:
  /// **'Cloud Sync'**
  String get cloudSync;

  /// No description provided for @webdavConfig.
  ///
  /// In en, this message translates to:
  /// **'WebDAV'**
  String get webdavConfig;

  /// No description provided for @webdavConfigured.
  ///
  /// In en, this message translates to:
  /// **'Configured - {serverUrl}'**
  String webdavConfigured(Object serverUrl);

  /// No description provided for @webdavConfigHint.
  ///
  /// In en, this message translates to:
  /// **'Tap to configure WebDAV server'**
  String get webdavConfigHint;

  /// No description provided for @appSettings.
  ///
  /// In en, this message translates to:
  /// **'App Settings'**
  String get appSettings;

  /// No description provided for @appFont.
  ///
  /// In en, this message translates to:
  /// **'App Font'**
  String get appFont;

  /// No description provided for @fontSystem.
  ///
  /// In en, this message translates to:
  /// **'System Default'**
  String get fontSystem;

  /// No description provided for @fontSourceHanSans.
  ///
  /// In en, this message translates to:
  /// **'Source Han Sans'**
  String get fontSourceHanSans;

  /// No description provided for @fontJetBrainsMono.
  ///
  /// In en, this message translates to:
  /// **'JetBrains Mono'**
  String get fontJetBrainsMono;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get languageSystem;

  /// No description provided for @languageChinese.
  ///
  /// In en, this message translates to:
  /// **'Chinese'**
  String get languageChinese;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @typographySettings.
  ///
  /// In en, this message translates to:
  /// **'Typography'**
  String get typographySettings;

  /// No description provided for @fontFamilyLabel.
  ///
  /// In en, this message translates to:
  /// **'Font'**
  String get fontFamilyLabel;

  /// No description provided for @fontSizeLabel.
  ///
  /// In en, this message translates to:
  /// **'Font Size'**
  String get fontSizeLabel;

  /// No description provided for @lineSpacingLabel.
  ///
  /// In en, this message translates to:
  /// **'Line Spacing'**
  String get lineSpacingLabel;

  /// No description provided for @letterSpacingLabel.
  ///
  /// In en, this message translates to:
  /// **'Letter Spacing'**
  String get letterSpacingLabel;

  /// No description provided for @firstLineIndentLabel.
  ///
  /// In en, this message translates to:
  /// **'First-line Indent'**
  String get firstLineIndentLabel;

  /// No description provided for @pageMarginLabel.
  ///
  /// In en, this message translates to:
  /// **'Page Margin'**
  String get pageMarginLabel;

  /// No description provided for @resetDefault.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get resetDefault;
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
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
