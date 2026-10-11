import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// 关于页：展示应用名称、版本号、版权声明；页面下半部滚动展示版本更新记录
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  /// 应用名称
  static const String appName = '小药箱';

  /// 版权声明
  static const String copyright = '© 2026 小药箱 · 保留所有权利';

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  /// 运行时从 pubspec.yaml（经 package_info_plus）读取的版本号
  String _version = '';

  /// 从 assets/changelog.json 读取的版本更新记录（按版本从新到旧）
  List<_VersionEntry> _changelog = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final raw = await rootBundle.loadString('assets/changelog.json');
      final entries = (jsonDecode(raw) as List)
          .map((e) => _VersionEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      if (!mounted) return;
      setState(() {
        _version = info.version;
        _changelog = entries;
      });
    } catch (_) {
      // 读取失败时版本号显示占位符，更新记录保持为空
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('关于')),
      body: Column(
        children: [
          // 上半部：应用信息
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      Icons.medical_services_outlined,
                      size: 48,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    AboutScreen.appName,
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '版本 ${_version.isEmpty ? '--' : _version}',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    AboutScreen.copyright,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
          // 下半部：版本更新记录（约占一半高度，可滚动）
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLowest,
                border: Border(
                  top: BorderSide(
                    color: theme.dividerColor.withValues(alpha: 0.4),
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Text(
                      '版本更新记录',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      itemCount: _changelog.length,
                      itemBuilder: (context, index) {
                        final entry = _changelog[index];
                        return _buildVersionEntry(theme, entry);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVersionEntry(ThemeData theme, _VersionEntry entry) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'v${entry.version}',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          for (final change in entry.changes)
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: SizedBox(
                      width: 4,
                      height: 4,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      change,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _VersionEntry {
  const _VersionEntry(this.version, this.changes);

  factory _VersionEntry.fromJson(Map<String, dynamic> json) => _VersionEntry(
        json['version'] as String,
        (json['changes'] as List).cast<String>(),
      );

  final String version;
  final List<String> changes;
}