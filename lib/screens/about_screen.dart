import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../services/theme_service.dart';

/// 关于页：展示应用信息与版本更新记录，并提供主题（明暗模式 + 配色）设置入口
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
    final themeService = context.watch<ThemeService>();

    return Scaffold(
      appBar: AppBar(title: const Text('关于')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 应用信息
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.medical_services_outlined,
                    size: 40,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  AboutScreen.appName,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  '版本 ${_version.isEmpty ? '--' : _version}',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                Text(
                  AboutScreen.copyright,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),

          // 主题设置
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildThemeSection(theme, themeService),
          ),

          const SizedBox(height: 8),
          const Divider(height: 1),

          // 版本更新记录（占据剩余空间，可滚动）
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
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
                    itemBuilder: (context, index) =>
                        _buildVersionEntry(theme, _changelog[index]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 主题设置卡片：明暗模式 + 配色选择
  Widget _buildThemeSection(ThemeData theme, ThemeService ts) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.palette_outlined,
                    size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Text(
                  '主题',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 明暗模式
            SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                    value: ThemeMode.system, label: Text('跟随系统')),
                ButtonSegment(value: ThemeMode.light, label: Text('亮色')),
                ButtonSegment(value: ThemeMode.dark, label: Text('暗色')),
              ],
              selected: {ts.mode},
              onSelectionChanged: (s) => ts.setMode(s.first),
              showSelectedIcon: false,
            ),
            const SizedBox(height: 16),
            // 配色主题
            Wrap(
              spacing: 20,
              runSpacing: 12,
              children: [
                for (var i = 0; i < ThemeService.seedOptions.length; i++)
                  _buildColorSwatch(theme, ts, i),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 单个配色圆形色块，选中时加粗边框并显示勾选
  Widget _buildColorSwatch(ThemeData theme, ThemeService ts, int index) {
    final option = ThemeService.seedOptions[index];
    final selected = ts.seedIndex == index;
    return GestureDetector(
      onTap: () => ts.setSeed(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: option.seed,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.outlineVariant,
                width: selected ? 3 : 1,
              ),
            ),
            child: selected
                ? const Icon(Icons.check, size: 22, color: Colors.white)
                : null,
          ),
          const SizedBox(height: 6),
          Text(option.label, style: theme.textTheme.bodySmall),
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