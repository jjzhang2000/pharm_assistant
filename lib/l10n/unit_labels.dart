import 'gen/app_localizations.dart';

/// 剂型（片/粒/胶囊…）原始存储值 → 本地化展示标签。
/// 存储值保持中文短码（参与业务逻辑），仅在显示时翻译。
String formLabel(AppLocalizations l10n, String form) {
  switch (form) {
    case '片':
      return l10n.unitTablet;
    case '粒':
      return l10n.unitPill;
    case '胶囊':
      return l10n.unitCapsule;
    case '包':
      return l10n.unitPacket;
    case '瓶':
      return l10n.unitBottle;
    case '支':
      return l10n.unitVial;
    case '滴':
      return l10n.unitDrop;
    default:
      return form;
  }
}

/// 周期单位（天/周/月）原始存储值 → 本地化展示标签。
/// 存储值保持中文短码（periodToDays 等逻辑依赖其字面值），仅显示时翻译。
String periodUnitLabel(AppLocalizations l10n, String unit) {
  switch (unit) {
    case '天':
      return l10n.unitDay;
    case '周':
      return l10n.unitWeek;
    case '月':
      return l10n.unitMonth;
    default:
      return unit;
  }
}

/// 星期（DateTime.weekday：1=周一…7=周日）→ 本地化短标签。
/// 用于服用安排展示，如「每2周六 08:00」中的「六」。
String weekdayLabel(AppLocalizations l10n, int weekday) {
  switch (weekday) {
    case 1:
      return l10n.weekdayMon;
    case 2:
      return l10n.weekdayTue;
    case 3:
      return l10n.weekdayWed;
    case 4:
      return l10n.weekdayThu;
    case 5:
      return l10n.weekdayFri;
    case 6:
      return l10n.weekdaySat;
    case 7:
      return l10n.weekdaySun;
    default:
      return '';
  }
}

/// 采购单位（盒/瓶）原始存储值 → 本地化展示标签。
String packageUnitLabel(AppLocalizations l10n, String unit) {
  switch (unit) {
    case '盒':
      return l10n.unitBox;
    case '瓶':
      return l10n.unitBottle;
    default:
      return unit;
  }
}