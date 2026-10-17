import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../l10n/gen/app_localizations.dart';
import '../services/locale_service.dart';

/// 信息页：版本说明与版权声明、使用指南、版本更新记录
class InfoScreen extends StatefulWidget {
  const InfoScreen({super.key});

  @override
  State<InfoScreen> createState() => _InfoScreenState();
}

class _InfoScreenState extends State<InfoScreen> {
  String _version = '';
  String _manual = '';
  List<_VersionEntry> _changelog = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final manualAsset = LocaleService.current.languageCode == 'en'
          ? 'Manual_en.md'
          : 'Manual.md';
      final info = await PackageInfo.fromPlatform();
      final manual = await rootBundle.loadString(manualAsset);
      final raw = await rootBundle.loadString('assets/changelog.json');
      final entries = (jsonDecode(raw) as List)
          .map((e) => _VersionEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      if (!mounted) return;
      setState(() {
        _version = info.version;
        _manual = manual;
        _changelog = entries;
      });
    } catch (_) {
      // 读取失败时保留占位内容，避免页面空白
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.about)),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. 版本说明和版权声明
            _buildAppInfo(theme, l10n),
            const SizedBox(height: 16),

            // 2. 使用指南（独立滚动）
            _sectionHeader(theme, l10n.guide),
            const SizedBox(height: 8),
            Expanded(
              flex: 2,
              child: _scrollBox(
                theme,
                MarkdownBody(
                  data: _manual.isEmpty ? l10n.guide : _manual,
                  styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                    blockquoteDecoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      border: Border(
                        left: BorderSide(
                            color: theme.colorScheme.primary, width: 3),
                      ),
                      borderRadius: const BorderRadius.horizontal(
                          right: Radius.circular(8)),
                    ),
                    blockquote: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 3. 版本更新记录（独立滚动）
            _sectionHeader(theme, l10n.versionHistory),
            const SizedBox(height: 8),
            Expanded(
              flex: 1,
              child: _scrollBox(
                theme,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final entry in _changelog)
                      _buildVersionEntry(theme, entry),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppInfo(ThemeData theme, AppLocalizations l10n) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            Icons.medical_services_outlined,
            size: 36,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.appName,
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                l10n.versionLabel(_version.isEmpty ? '--' : _version),
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 2),
              Text(
                l10n.copyright,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader(ThemeData theme, String title) {
    return Text(
      title,
      style: theme.textTheme.titleMedium
          ?.copyWith(fontWeight: FontWeight.bold),
    );
  }

  Widget _scrollBox(ThemeData theme, Widget child) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Scrollbar(
        thumbVisibility: true,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: child,
        ),
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