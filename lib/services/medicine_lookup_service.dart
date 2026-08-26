import 'dart:convert';

import 'package:http/http.dart' as http;

/// 药品联网查询结果（从说明书解析出的规范信息）
class DrugLookupResult {
  final String name;
  final double? dosageStrength;
  final String? dosageStrengthUnit;
  final String? form;
  final int? periodValue;
  final String? periodUnit;
  final int? timesPerPeriod;
  final double? dosagePerTime;

  const DrugLookupResult({
    required this.name,
    this.dosageStrength,
    this.dosageStrengthUnit,
    this.form,
    this.periodValue,
    this.periodUnit,
    this.timesPerPeriod,
    this.dosagePerTime,
  });
}

/// 商品条码查询结果（含名称及从规格解析出的剂量/剂型）
class BarcodeInfo {
  final String name;
  final double? dosageStrength;
  final String? dosageStrengthUnit;
  final String? form;
  const BarcodeInfo({
    required this.name,
    this.dosageStrength,
    this.dosageStrengthUnit,
    this.form,
  });
}

/// 通过天行数据「药品说明书」接口查询药品规范信息并解析关键字段。
///
/// 数据源：https://www.tianapi.com/apiview/134
class MedicineLookupService {
  /// 天行数据 API Key。请到 https://www.tianapi.com/ 注册并申请「药品说明书」接口后填入。
  static const String apiKey = '5fe2d02121e46cb025755d7948cf1234';

  static const String _endpoint = 'https://apis.tianapi.com/yaopin/index';

  Future<DrugLookupResult> lookup(String keyword) async {
    final word = keyword.trim();
    if (word.isEmpty) throw Exception('请输入药品名称');
    if (apiKey.isEmpty || apiKey == 'YOUR_API_KEY') {
      throw Exception('请先在 medicine_lookup_service.dart 中配置天行数据 API Key');
    }

    // 依次尝试：原始名称 → 去空白 → 去括号（商品名），命中即用
    final candidates = <String>{
      word,
      word.replaceAll(RegExp(r'\s+'), ''),
      word.replaceAll(RegExp(r'[（(][^）)]*[）)]'), '').replaceAll(RegExp(r'\s+'), ''),
    };
    var title = '';
    var content = '';
    for (final c in candidates) {
      if (c.isEmpty) continue;
      final (t, ct) = await _query(c);
      if (t.isNotEmpty) {
        title = t;
        content = ct;
        break;
      }
    }
    if (title.isEmpty) throw Exception('未查询到该药品');
    return _buildResult(title, content);
  }

  /// 查询一次说明书接口；code 250（数据为空）返回空字符串，便于上层重试
  Future<(String, String)> _query(String word) async {
    final uri = Uri.parse(_endpoint).replace(queryParameters: {
      'key': apiKey,
      'word': word,
      'num': '1',
    });
    final resp = await http.get(uri).timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) {
      throw Exception('请求失败（HTTP ${resp.statusCode}）');
    }

    final data = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    final code = data['code'];
    if (code == 250) return ('', '');
    if (code != 200) {
      throw Exception(_describeError(code, data['msg']));
    }
    return _extractResult(data['result']);
  }

  /// 通过商品条码查询药品名称及规格（天行数据「商品条码查询」接口）。
  /// 仅支持商品条码（如 EAN-13），药品追溯码查不到。
  /// 数据源：https://www.tianapi.com/apiview/138
  Future<BarcodeInfo?> lookupByBarcode(String barcode) async {
    final code = barcode.trim();
    if (code.isEmpty) return null;
    if (apiKey.isEmpty || apiKey == 'YOUR_API_KEY') {
      throw Exception('请先在 medicine_lookup_service.dart 中配置天行数据 API Key');
    }

    final uri = Uri.parse('https://apis.tianapi.com/barcode/index')
        .replace(queryParameters: {'key': apiKey, 'barcode': code});
    final resp = await http.get(uri).timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) {
      throw Exception('请求失败（HTTP ${resp.statusCode}）');
    }

    final data = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    final c = data['code'];
    if (c != 200) {
      throw Exception(_describeError(c, data['msg']));
    }

    final result = data['result'];
    if (result is Map) {
      final name = result['name']?.toString().trim();
      if (name == null || name.isEmpty) return null;
      final spec = result['spec']?.toString().trim() ?? '';
      final (strength, unit, form) = _parseBarcodeSpec(spec);
      return BarcodeInfo(
        name: name,
        dosageStrength: strength,
        dosageStrengthUnit: unit,
        form: form,
      );
    }
    return null;
  }

  /// 从商品条码的「规格」字段解析剂量/剂型，如「25mg*100片」「0.1g×30片」
  (double?, String?, String?) _parseBarcodeSpec(String spec) {
    if (spec.isEmpty) return (null, null, null);
    final m = RegExp(r'(\d+(?:\.\d+)?)\s*(mg|μg|mcg|ug|g|克|毫升|ml)')
        .firstMatch(spec);
    if (m == null) return (null, null, null);
    final value = double.tryParse(m.group(1)!);
    var unit = m.group(2)!;
    if (unit == 'μg' || unit == 'ug') unit = 'mcg';
    if (unit == '克') unit = 'g';
    if (unit == '毫升') unit = 'ml';
    String? form;
    if (spec.contains('胶囊')) {
      form = '胶囊';
    } else if (spec.contains('片')) {
      form = '片';
    } else if (spec.contains('粒') || spec.contains('丸')) {
      form = '粒';
    } else if (spec.contains('支')) {
      form = '支';
    } else if (spec.contains('滴')) {
      form = '滴';
    } else if (spec.contains('袋') || spec.contains('包')) {
      form = '包';
    } else if (spec.contains('瓶')) {
      form = '瓶';
    }
    return (value, unit, form);
  }

  (String, String) _extractResult(dynamic result) {
    String title = '';
    String content = '';
    if (result is Map) {
      final map = Map<String, dynamic>.from(result);
      if (map.containsKey('title') || map.containsKey('content')) {
        title = map['title']?.toString() ?? '';
        content = map['content']?.toString() ?? '';
      } else {
        final list = map['list'] ?? map['newslist'] ?? map['data'];
        if (list is List && list.isNotEmpty && list.first is Map) {
          final first = Map<String, dynamic>.from(list.first);
          title = first['title']?.toString() ?? '';
          content = first['content']?.toString() ?? '';
        }
      }
    } else if (result is List && result.isNotEmpty && result.first is Map) {
      final first = Map<String, dynamic>.from(result.first);
      title = first['title']?.toString() ?? '';
      content = first['content']?.toString() ?? '';
    }
    return (title, content);
  }

  DrugLookupResult _buildResult(String title, String content) {
    final cleaned = _cleanContent(content);
    final name = _standardName(title, cleaned);
    final form = _inferForm(name, cleaned);
    final (strength, unit) = _parseSpec(cleaned);
    final usage = _extractUsage(cleaned);
    final (periodUnit, periodValue, times) = _parsePeriod(usage);
    final (perTime, perTimeForm) =
        _parsePerTime(usage, form, strength, unit);
    return DrugLookupResult(
      name: name,
      dosageStrength: strength,
      dosageStrengthUnit: unit,
      form: perTimeForm ?? form,
      periodValue: periodValue,
      periodUnit: periodUnit,
      timesPerPeriod: times,
      dosagePerTime: perTime,
    );
  }

  /// 清洗说明书文本：去掉 HTML 标签、制表符等，便于正则解析
  String _cleanContent(String content) {
    return content
        .replaceAll(RegExp(r'<br\s*/?>'), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('\t', ' ')
        .replaceAll('&nbsp;', ' ');
  }

  /// 提取【用法用量】段落（兼容天行数据的「用量用法」写法）
  String _extractUsage(String content) {
    final a = _extractSection(content, '用法用量');
    if (a.isNotEmpty) return a;
    return _extractSection(content, '用量用法');
  }

  /// 提取【标题】…到下一个【 之间的段落
  String _extractSection(String content, String title) {
    final start = content.indexOf('【$title】');
    if (start < 0) return '';
    final end = content.indexOf('【', start + title.length + 2);
    return content.substring(start, end < 0 ? content.length : end);
  }

  /// 规范名称：优先取说明书「通用名称」，否则用接口标题并去掉括号商品名
  String _standardName(String title, String content) {
    final m = RegExp(r'通用名称[:：]?\s*([^\s；;。，,]+)').firstMatch(content);
    if (m != null && m.group(1)!.trim().isNotEmpty) {
      return m.group(1)!.trim();
    }
    final t = title.replaceAll(RegExp(r'[（(][^）)]*[）)]'), '').trim();
    return t.isEmpty ? title.trim() : t;
  }

  /// 剂型（每剂单位）：从名称/说明书推断，映射到表单的片/粒/胶囊/包/瓶/支/滴
  String? _inferForm(String name, String content) {
    final text = '$name $content';
    if (text.contains('胶囊')) return '胶囊';
    if (text.contains('颗粒') ||
        text.contains('冲剂') ||
        text.contains('散剂') ||
        text.contains('散')) {
      return '包';
    }
    if (text.contains('口服液') ||
        text.contains('糖浆') ||
        text.contains('合剂') ||
        text.contains('口服溶液') ||
        text.contains('混悬液')) {
      return '瓶';
    }
    if (text.contains('注射液') ||
        text.contains('注射剂') ||
        text.contains('冻干')) {
      return '支';
    }
    if (text.contains('滴眼') ||
        text.contains('滴耳') ||
        text.contains('滴鼻') ||
        text.contains('滴剂')) {
      return '滴';
    }
    if (text.contains('丸')) return '粒';
    if (text.contains('片')) return '片';
    return null;
  }

  /// 规格剂量：从【规格】取第一个「数字+单位」，如 0.1g / 5mg / 10ml
  (double?, String?) _parseSpec(String content) {
    final specBlock = _extractSection(content, '规格');
    final text = specBlock.isNotEmpty ? specBlock : content;
    final m = RegExp(r'(\d+(?:\.\d+)?)\s*(mg|μg|mcg|ug|g|ml|IU|单位|万单位)')
        .firstMatch(text);
    if (m == null) return (null, null);
    final value = double.tryParse(m.group(1)!);
    var unit = m.group(2)!;
    if (unit == 'μg' || unit == 'ug') unit = 'mcg';
    if (unit == '单位' || unit == '万单位') unit = 'IU';
    return (value, unit);
  }

  /// 服用周期：qd/bid/tid/qid / 每周 N 次 / 每 X 天 N 次 / 一日 N 次
  (String?, int?, int?) _parsePeriod(String usage) {
    if (usage.isEmpty) return (null, null, null);
    // 医学缩写：qd=每日1次，bid=每日2次，tid=每日3次，qid=每日4次
    if (RegExp(r'\bqid\b', caseSensitive: false).hasMatch(usage)) {
      return ('天', 1, 4);
    }
    if (RegExp(r'\btid\b', caseSensitive: false).hasMatch(usage)) {
      return ('天', 1, 3);
    }
    if (RegExp(r'\bbid\b', caseSensitive: false).hasMatch(usage)) {
      return ('天', 1, 2);
    }
    if (RegExp(r'\bqd\b', caseSensitive: false).hasMatch(usage)) {
      return ('天', 1, 1);
    }
    final weekly = RegExp(r'每周\s*(\d+)\s*次').firstMatch(usage);
    if (weekly != null) return ('周', 1, int.tryParse(weekly.group(1)!));
    final everyXD = RegExp(r'每\s*(\d+)\s*天\s*(\d+)\s*次').firstMatch(usage);
    if (everyXD != null) {
      return ('天', int.tryParse(everyXD.group(1)!),
          int.tryParse(everyXD.group(2)!));
    }
    final daily =
        RegExp(r'(?:一日|每日|每天|1天|一天)\s*(\d+)\s*次').firstMatch(usage);
    if (daily != null) return ('天', 1, int.tryParse(daily.group(1)!));
    return (null, null, null);
  }

  /// 每次剂量：优先「一次 X 片/粒/…」；否则「一次 X mg/g/…」或「X－Y mg」范围按规格换算成片数
  (double?, String?) _parsePerTime(
      String usage, String? form, double? strength, String? unit) {
    if (usage.isEmpty) return (null, null);
    final m = RegExp(r'一次\s*(\d+(?:\.\d+)?)\s*(片|粒|胶囊|包|袋|支|滴|瓶)')
        .firstMatch(usage);
    if (m != null) {
      final v = double.tryParse(m.group(1)!);
      var u = m.group(2)!;
      if (u == '袋') u = '包';
      return (v, u);
    }
    // 质量/体积剂量：优先「一次 X mg」；否则「X－Y mg」范围取最小值
    final patterns = <RegExp>[
      RegExp(r'一次\s*(\d+(?:\.\d+)?)\s*(mg|g|ml|μg|mcg|ug)'),
      RegExp(r'(\d+(?:\.\d+)?)\s*(?:－|-|~|～)\s*\d+(?:\.\d+)?\s*(mg|g|ml|μg|mcg|ug)'),
    ];
    for (final re in patterns) {
      final mm = re.firstMatch(usage);
      if (mm == null || strength == null || strength <= 0 || unit == null) {
        continue;
      }
      final v = double.tryParse(mm.group(1)!);
      var u = mm.group(2)!;
      if (u == 'μg' || u == 'ug') u = 'mcg';
      final doseMg = _toMg(v, u);
      final specMg = _toMg(strength, unit);
      if (doseMg != null && specMg != null && specMg > 0) {
        return (doseMg / specMg, form);
      }
    }
    return (null, null);
  }

  double? _toMg(double? v, String unit) {
    if (v == null) return null;
    switch (unit) {
      case 'mg':
        return v;
      case 'g':
        return v * 1000;
      case 'mcg':
        return v / 1000;
      default:
        return null; // ml 等体积单位不参与换算
    }
  }

  String _describeError(dynamic code, dynamic msg) {
    if (code == 250) return '未查询到该药品的说明书';
    final m = msg?.toString();
    if (m != null && m.isNotEmpty && m != 'success') return m;
    return '查询失败（code=$code）';
  }
}
