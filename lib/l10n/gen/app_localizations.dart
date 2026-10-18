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
/// import 'gen/app_localizations.dart';
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
    Locale('zh')
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Little Medicine Box'**
  String get appName;

  /// No description provided for @copyright.
  ///
  /// In en, this message translates to:
  /// **'© 2026 Little Medicine Box · All rights reserved'**
  String get copyright;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get confirm;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @newBox.
  ///
  /// In en, this message translates to:
  /// **'New box'**
  String get newBox;

  /// No description provided for @boxNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter box name'**
  String get boxNameHint;

  /// No description provided for @renameBox.
  ///
  /// In en, this message translates to:
  /// **'Rename box'**
  String get renameBox;

  /// No description provided for @newBoxNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter new box name'**
  String get newBoxNameHint;

  /// No description provided for @confirmDelete.
  ///
  /// In en, this message translates to:
  /// **'Confirm delete'**
  String get confirmDelete;

  /// No description provided for @confirmDeleteBox.
  ///
  /// In en, this message translates to:
  /// **'Delete box \"{name}\"? All medicines in it will also be deleted. This cannot be undone.'**
  String confirmDeleteBox(String name);

  /// No description provided for @dragMedicineHint.
  ///
  /// In en, this message translates to:
  /// **'Drag medicine to a target box'**
  String get dragMedicineHint;

  /// No description provided for @medicineCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 medicine} other{{count} medicines}}'**
  String medicineCount(int count);

  /// No description provided for @shortagePageTitle.
  ///
  /// In en, this message translates to:
  /// **'Shortage'**
  String get shortagePageTitle;

  /// No description provided for @shareShortageTooltip.
  ///
  /// In en, this message translates to:
  /// **'Share shortage list'**
  String get shareShortageTooltip;

  /// No description provided for @addMedicineTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add medicine'**
  String get addMedicineTooltip;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @saveToAlbumFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save to album. Please check photo permissions and try again.'**
  String get saveToAlbumFailed;

  /// No description provided for @savedToAlbum.
  ///
  /// In en, this message translates to:
  /// **'Saved to album'**
  String get savedToAlbum;

  /// No description provided for @savedToAlbumMessage.
  ///
  /// In en, this message translates to:
  /// **'The shortage page screenshot has been saved to your photo album. You can share it in apps like WeChat or QQ.'**
  String get savedToAlbumMessage;

  /// No description provided for @gotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get gotIt;

  /// No description provided for @noShortageMedicine.
  ///
  /// In en, this message translates to:
  /// **'No shortage medicines'**
  String get noShortageMedicine;

  /// No description provided for @starred.
  ///
  /// In en, this message translates to:
  /// **'Starred'**
  String get starred;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @guide.
  ///
  /// In en, this message translates to:
  /// **'User guide'**
  String get guide;

  /// No description provided for @versionLabel.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String versionLabel(String version);

  /// No description provided for @versionHistory.
  ///
  /// In en, this message translates to:
  /// **'Version history'**
  String get versionHistory;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @system.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get system;

  /// No description provided for @light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// No description provided for @dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get dark;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @quickAddStock.
  ///
  /// In en, this message translates to:
  /// **'Quick add stock'**
  String get quickAddStock;

  /// No description provided for @colorTeal.
  ///
  /// In en, this message translates to:
  /// **'Teal'**
  String get colorTeal;

  /// No description provided for @colorBlue.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get colorBlue;

  /// No description provided for @colorGreen.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get colorGreen;

  /// No description provided for @colorPurple.
  ///
  /// In en, this message translates to:
  /// **'Purple'**
  String get colorPurple;

  /// No description provided for @editMedicine.
  ///
  /// In en, this message translates to:
  /// **'Edit medicine'**
  String get editMedicine;

  /// No description provided for @addMedicine.
  ///
  /// In en, this message translates to:
  /// **'Add medicine'**
  String get addMedicine;

  /// No description provided for @medicineInfo.
  ///
  /// In en, this message translates to:
  /// **'Medicine info'**
  String get medicineInfo;

  /// No description provided for @scheduleSection.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get scheduleSection;

  /// No description provided for @inventoryInfo.
  ///
  /// In en, this message translates to:
  /// **'Inventory'**
  String get inventoryInfo;

  /// No description provided for @medicineName.
  ///
  /// In en, this message translates to:
  /// **'Medicine name'**
  String get medicineName;

  /// No description provided for @medicineNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter the medicine name'**
  String get medicineNameRequired;

  /// No description provided for @dosage.
  ///
  /// In en, this message translates to:
  /// **'Dose'**
  String get dosage;

  /// No description provided for @every.
  ///
  /// In en, this message translates to:
  /// **'Every'**
  String get every;

  /// No description provided for @times.
  ///
  /// In en, this message translates to:
  /// **'times'**
  String get times;

  /// No description provided for @perDose.
  ///
  /// In en, this message translates to:
  /// **'Per dose'**
  String get perDose;

  /// No description provided for @timeLabel.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get timeLabel;

  /// No description provided for @doseTime.
  ///
  /// In en, this message translates to:
  /// **'Dose time'**
  String get doseTime;

  /// No description provided for @nextRound.
  ///
  /// In en, this message translates to:
  /// **'Next round'**
  String get nextRound;

  /// No description provided for @currentStock.
  ///
  /// In en, this message translates to:
  /// **'Current stock'**
  String get currentStock;

  /// No description provided for @quantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get quantity;

  /// No description provided for @below.
  ///
  /// In en, this message translates to:
  /// **'Below'**
  String get below;

  /// No description provided for @dayReminder.
  ///
  /// In en, this message translates to:
  /// **'days reminder'**
  String get dayReminder;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @medicineNotFound.
  ///
  /// In en, this message translates to:
  /// **'Medicine not found'**
  String get medicineNotFound;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @move.
  ///
  /// In en, this message translates to:
  /// **'Move'**
  String get move;

  /// No description provided for @remainingStockDays.
  ///
  /// In en, this message translates to:
  /// **'Remaining / days'**
  String get remainingStockDays;

  /// No description provided for @spec.
  ///
  /// In en, this message translates to:
  /// **'Specification'**
  String get spec;

  /// No description provided for @dosageMethod.
  ///
  /// In en, this message translates to:
  /// **'Dosage'**
  String get dosageMethod;

  /// No description provided for @frequency.
  ///
  /// In en, this message translates to:
  /// **'Frequency'**
  String get frequency;

  /// No description provided for @frequencyValue.
  ///
  /// In en, this message translates to:
  /// **'Every {value} {unit} {times} times'**
  String frequencyValue(String value, String unit, String times);

  /// No description provided for @dosePerTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Dose per time'**
  String get dosePerTimeLabel;

  /// No description provided for @nextDoseDate.
  ///
  /// In en, this message translates to:
  /// **'Next dose date'**
  String get nextDoseDate;

  /// No description provided for @notSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get notSet;

  /// No description provided for @reminderThreshold.
  ///
  /// In en, this message translates to:
  /// **'Reminder threshold'**
  String get reminderThreshold;

  /// No description provided for @belowThresholdReminder.
  ///
  /// In en, this message translates to:
  /// **'Reminder when below {days} days'**
  String belowThresholdReminder(String days);

  /// No description provided for @moveTo.
  ///
  /// In en, this message translates to:
  /// **'Move to'**
  String get moveTo;

  /// No description provided for @confirmDeleteMedicine.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"? This cannot be undone.'**
  String confirmDeleteMedicine(String name);

  /// No description provided for @daysRemaining.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{1 day} other{{days} days}}'**
  String daysRemaining(int days);

  /// No description provided for @backup.
  ///
  /// In en, this message translates to:
  /// **'Backup'**
  String get backup;

  /// No description provided for @backupBox.
  ///
  /// In en, this message translates to:
  /// **'Backup box'**
  String get backupBox;

  /// No description provided for @starShortageTitle.
  ///
  /// In en, this message translates to:
  /// **'Starred medicine shortage'**
  String get starShortageTitle;

  /// No description provided for @starShortageBody.
  ///
  /// In en, this message translates to:
  /// **'{name} is running low, about {days} days left. Please replenish.'**
  String starShortageBody(String name, String days);

  /// No description provided for @starAlertChannelName.
  ///
  /// In en, this message translates to:
  /// **'Starred medicine alerts'**
  String get starAlertChannelName;

  /// No description provided for @starAlertChannelDesc.
  ///
  /// In en, this message translates to:
  /// **'Starred medicine shortage alerts'**
  String get starAlertChannelDesc;

  /// No description provided for @starShortageUpcoming.
  ///
  /// In en, this message translates to:
  /// **'{name} is about to fall below its threshold. Please replenish.'**
  String starShortageUpcoming(String name);

  /// No description provided for @medicineRunningOut.
  ///
  /// In en, this message translates to:
  /// **'Medicine running low'**
  String get medicineRunningOut;

  /// No description provided for @medicineInsufficient.
  ///
  /// In en, this message translates to:
  /// **'{name} is running out of stock. Please replenish.'**
  String medicineInsufficient(String name);

  /// No description provided for @medicineAlertChannelName.
  ///
  /// In en, this message translates to:
  /// **'Medicine alerts'**
  String get medicineAlertChannelName;

  /// No description provided for @medicineAlertChannelDesc.
  ///
  /// In en, this message translates to:
  /// **'Medicine stock shortage alerts'**
  String get medicineAlertChannelDesc;

  /// No description provided for @medicineExpectedOut.
  ///
  /// In en, this message translates to:
  /// **'{name} is expected to run out today. Please replenish.'**
  String medicineExpectedOut(String name);

  /// No description provided for @unitTablet.
  ///
  /// In en, this message translates to:
  /// **'tablet'**
  String get unitTablet;

  /// No description provided for @unitPill.
  ///
  /// In en, this message translates to:
  /// **'pill'**
  String get unitPill;

  /// No description provided for @unitCapsule.
  ///
  /// In en, this message translates to:
  /// **'capsule'**
  String get unitCapsule;

  /// No description provided for @unitPacket.
  ///
  /// In en, this message translates to:
  /// **'packet'**
  String get unitPacket;

  /// No description provided for @unitBottle.
  ///
  /// In en, this message translates to:
  /// **'bottle'**
  String get unitBottle;

  /// No description provided for @unitVial.
  ///
  /// In en, this message translates to:
  /// **'vial'**
  String get unitVial;

  /// No description provided for @unitDrop.
  ///
  /// In en, this message translates to:
  /// **'drop'**
  String get unitDrop;

  /// No description provided for @unitDay.
  ///
  /// In en, this message translates to:
  /// **'day'**
  String get unitDay;

  /// No description provided for @unitWeek.
  ///
  /// In en, this message translates to:
  /// **'week'**
  String get unitWeek;

  /// No description provided for @unitMonth.
  ///
  /// In en, this message translates to:
  /// **'month'**
  String get unitMonth;
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
