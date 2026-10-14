// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appName => '小药箱';

  @override
  String get copyright => '© 2026 小药箱 · 保留所有权利';

  @override
  String get cancel => '取消';

  @override
  String get confirm => '确定';

  @override
  String get delete => '删除';

  @override
  String get more => '更多';

  @override
  String get settings => '设置';

  @override
  String get newBox => '新药箱';

  @override
  String get boxNameHint => '请输入药箱名';

  @override
  String get renameBox => '重命名药箱';

  @override
  String get newBoxNameHint => '请输入新的药箱名';

  @override
  String get confirmDelete => '确认删除';

  @override
  String confirmDeleteBox(String name) {
    return '确定要删除药箱「$name」吗？其中的药品将一并删除，此操作不可撤销。';
  }

  @override
  String get dragMedicineHint => '拖动药品到目标药箱';

  @override
  String medicineCount(int count) {
    return '$count 种药品';
  }

  @override
  String get shortagePageTitle => '短缺药品';

  @override
  String get shareShortageTooltip => '分享短缺药品';

  @override
  String get addMedicineTooltip => '添加药品';

  @override
  String get rename => '重命名';

  @override
  String get saveToAlbumFailed => '保存到相册失败，请检查相册权限后重试';

  @override
  String get savedToAlbum => '已保存到相册';

  @override
  String get savedToAlbumMessage => '短缺药品页面长截图已保存到手机相册，可在微信、QQ 等应用中分享给好友。';

  @override
  String get gotIt => '知道了';

  @override
  String get noShortageMedicine => '暂无短缺药品';

  @override
  String get starred => '星标';

  @override
  String get about => '关于';

  @override
  String versionLabel(String version) {
    return '版本 $version';
  }

  @override
  String get versionHistory => '版本更新记录';

  @override
  String get theme => '主题';

  @override
  String get system => '跟随系统';

  @override
  String get light => '亮色';

  @override
  String get dark => '暗色';

  @override
  String get language => '语言';

  @override
  String get colorTeal => '青';

  @override
  String get colorBlue => '蓝';

  @override
  String get colorGreen => '绿';

  @override
  String get colorPurple => '紫';

  @override
  String get editMedicine => '编辑药品';

  @override
  String get addMedicine => '添加药品';

  @override
  String get medicineInfo => '药品信息';

  @override
  String get scheduleSection => '服用安排';

  @override
  String get inventoryInfo => '库存信息';

  @override
  String get medicineName => '药品名称';

  @override
  String get medicineNameRequired => '请输入药品名称';

  @override
  String get lookupTooltip => '联网查询药品信息';

  @override
  String get scanTooltip => '扫描药盒条码/二维码';

  @override
  String get dosage => '剂量';

  @override
  String get every => '每';

  @override
  String get times => '次';

  @override
  String get perDose => '每次';

  @override
  String get timeLabel => '时间';

  @override
  String get doseTime => '服用时间';

  @override
  String get nextRound => '下轮';

  @override
  String get currentStock => '当前存量';

  @override
  String get quantity => '数量';

  @override
  String get below => '低于';

  @override
  String get dayReminder => '天提醒';

  @override
  String get save => '保存';

  @override
  String get add => '添加';

  @override
  String get traceCodeUnsupported => '这是药品追溯码，暂无法查询，请手动输入药品名称';

  @override
  String get barcodeApiNotApplied => '请先在天行数据控制台申请「商品条码查询」接口';

  @override
  String barcodeLookupFailed(String msg) {
    return '条码查询失败：$msg';
  }

  @override
  String barcodeNotFound(String code) {
    return '未查到该条码「$code」对应的药品，请手动输入名称';
  }

  @override
  String get enterMedicineNameFirst => '请先输入药品名称';

  @override
  String lookupApplied(String name) {
    return '已填入「$name」的信息，请核对服用剂量与周期';
  }

  @override
  String get lookupNameOnly => '已填入名称，但未查到该药品的说明书，剂量/周期请手动填写';

  @override
  String lookupFailed(String msg) {
    return '查询失败：$msg';
  }

  @override
  String get scanTitle => '扫描药品条码/二维码';

  @override
  String get scanHint => '对准药盒上的条码或二维码';

  @override
  String get medicineNotFound => '药品不存在';

  @override
  String get edit => '编辑';

  @override
  String get move => '移动';

  @override
  String get remainingStockDays => '剩余存量 / 天数';

  @override
  String get spec => '规格';

  @override
  String get dosageMethod => '服用方式';

  @override
  String get frequency => '频次';

  @override
  String frequencyValue(String value, String unit, String times) {
    return '每 $value $unit $times 次';
  }

  @override
  String get dosePerTimeLabel => '每次剂量';

  @override
  String get nextDoseDate => '下次服用日期';

  @override
  String get notSet => '未设置';

  @override
  String get reminderThreshold => '提醒阈值';

  @override
  String belowThresholdReminder(String days) {
    return '低于 $days 天提醒';
  }

  @override
  String get moveTo => '移动到';

  @override
  String confirmDeleteMedicine(String name) {
    return '确定要删除「$name」吗？此操作不可撤销。';
  }

  @override
  String daysRemaining(int days) {
    return '$days 天';
  }

  @override
  String get backup => '备用';

  @override
  String get backupBox => '备用药箱';

  @override
  String get starShortageTitle => '星标药品短缺';

  @override
  String starShortageBody(String name, String days) {
    return '$name 库存不足，剩余约 $days 天用量，请及时补充';
  }

  @override
  String get starAlertChannelName => '星标药品提醒';

  @override
  String get starAlertChannelDesc => '星标药品短缺提醒';

  @override
  String starShortageUpcoming(String name) {
    return '$name 库存即将低于警戒线，请及时补充';
  }

  @override
  String get medicineRunningOut => '药品即将用完';

  @override
  String medicineInsufficient(String name) {
    return '$name 库存已不足，请及时补充';
  }

  @override
  String get medicineAlertChannelName => '药品提醒';

  @override
  String get medicineAlertChannelDesc => '药品库存不足提醒';

  @override
  String medicineExpectedOut(String name) {
    return '$name 预计当天用完，请及时补充';
  }

  @override
  String get unitTablet => '片';

  @override
  String get unitPill => '粒';

  @override
  String get unitCapsule => '胶囊';

  @override
  String get unitPacket => '包';

  @override
  String get unitBottle => '瓶';

  @override
  String get unitVial => '支';

  @override
  String get unitDrop => '滴';

  @override
  String get unitDay => '天';

  @override
  String get unitWeek => '周';

  @override
  String get unitMonth => '月';
}
