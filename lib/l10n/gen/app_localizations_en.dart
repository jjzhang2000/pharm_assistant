// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Little Medicine Box';

  @override
  String get copyright => '© 2026 Little Medicine Box · All rights reserved';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'OK';

  @override
  String get delete => 'Delete';

  @override
  String get more => 'More';

  @override
  String get settings => 'Settings';

  @override
  String get newBox => 'New box';

  @override
  String get boxNameHint => 'Enter box name';

  @override
  String get renameBox => 'Rename box';

  @override
  String get newBoxNameHint => 'Enter new box name';

  @override
  String get confirmDelete => 'Confirm delete';

  @override
  String confirmDeleteBox(String name) {
    return 'Delete box \"$name\"? All medicines in it will also be deleted. This cannot be undone.';
  }

  @override
  String get dragMedicineHint => 'Drag medicine to a target box';

  @override
  String medicineCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count medicines',
      one: '1 medicine',
    );
    return '$_temp0';
  }

  @override
  String get shortagePageTitle => 'Shortage';

  @override
  String get shareShortageTooltip => 'Share shortage list';

  @override
  String get addMedicineTooltip => 'Add medicine';

  @override
  String get rename => 'Rename';

  @override
  String get saveToAlbumFailed =>
      'Failed to save to album. Please check photo permissions and try again.';

  @override
  String get savedToAlbum => 'Saved to album';

  @override
  String get savedToAlbumMessage =>
      'The shortage page screenshot has been saved to your photo album. You can share it in apps like WeChat or QQ.';

  @override
  String get gotIt => 'Got it';

  @override
  String get noShortageMedicine => 'No shortage medicines';

  @override
  String get starred => 'Starred';

  @override
  String get about => 'About';

  @override
  String get guide => 'User guide';

  @override
  String versionLabel(String version) {
    return 'Version $version';
  }

  @override
  String get versionHistory => 'Version history';

  @override
  String get theme => 'Theme';

  @override
  String get system => 'System';

  @override
  String get light => 'Light';

  @override
  String get dark => 'Dark';

  @override
  String get language => 'Language';

  @override
  String get colorTeal => 'Teal';

  @override
  String get colorBlue => 'Blue';

  @override
  String get colorGreen => 'Green';

  @override
  String get colorPurple => 'Purple';

  @override
  String get editMedicine => 'Edit medicine';

  @override
  String get addMedicine => 'Add medicine';

  @override
  String get medicineInfo => 'Medicine info';

  @override
  String get scheduleSection => 'Schedule';

  @override
  String get inventoryInfo => 'Inventory';

  @override
  String get medicineName => 'Medicine name';

  @override
  String get medicineNameRequired => 'Please enter the medicine name';

  @override
  String get dosage => 'Dose';

  @override
  String get every => 'Every';

  @override
  String get times => 'times';

  @override
  String get perDose => 'Per dose';

  @override
  String get timeLabel => 'Time';

  @override
  String get doseTime => 'Dose time';

  @override
  String get nextRound => 'Next round';

  @override
  String get currentStock => 'Current stock';

  @override
  String get quantity => 'Quantity';

  @override
  String get below => 'Below';

  @override
  String get dayReminder => 'days reminder';

  @override
  String get save => 'Save';

  @override
  String get add => 'Add';

  @override
  String get medicineNotFound => 'Medicine not found';

  @override
  String get edit => 'Edit';

  @override
  String get move => 'Move';

  @override
  String get remainingStockDays => 'Remaining / days';

  @override
  String get spec => 'Specification';

  @override
  String get dosageMethod => 'Dosage';

  @override
  String get frequency => 'Frequency';

  @override
  String frequencyValue(String value, String unit, String times) {
    return 'Every $value $unit $times times';
  }

  @override
  String get dosePerTimeLabel => 'Dose per time';

  @override
  String get nextDoseDate => 'Next dose date';

  @override
  String get notSet => 'Not set';

  @override
  String get reminderThreshold => 'Reminder threshold';

  @override
  String belowThresholdReminder(String days) {
    return 'Reminder when below $days days';
  }

  @override
  String get moveTo => 'Move to';

  @override
  String confirmDeleteMedicine(String name) {
    return 'Delete \"$name\"? This cannot be undone.';
  }

  @override
  String daysRemaining(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String get backup => 'Backup';

  @override
  String get backupBox => 'Backup box';

  @override
  String get starShortageTitle => 'Starred medicine shortage';

  @override
  String starShortageBody(String name, String days) {
    return '$name is running low, about $days days left. Please replenish.';
  }

  @override
  String get starAlertChannelName => 'Starred medicine alerts';

  @override
  String get starAlertChannelDesc => 'Starred medicine shortage alerts';

  @override
  String starShortageUpcoming(String name) {
    return '$name is about to fall below its threshold. Please replenish.';
  }

  @override
  String get medicineRunningOut => 'Medicine running low';

  @override
  String medicineInsufficient(String name) {
    return '$name is running out of stock. Please replenish.';
  }

  @override
  String get medicineAlertChannelName => 'Medicine alerts';

  @override
  String get medicineAlertChannelDesc => 'Medicine stock shortage alerts';

  @override
  String medicineExpectedOut(String name) {
    return '$name is expected to run out today. Please replenish.';
  }

  @override
  String get unitTablet => 'tablet';

  @override
  String get unitPill => 'pill';

  @override
  String get unitCapsule => 'capsule';

  @override
  String get unitPacket => 'packet';

  @override
  String get unitBottle => 'bottle';

  @override
  String get unitVial => 'vial';

  @override
  String get unitDrop => 'drop';

  @override
  String get unitDay => 'day';

  @override
  String get unitWeek => 'week';

  @override
  String get unitMonth => 'month';
}
