import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/gen/app_localizations.dart';
import '../services/locale_service.dart';
import '../services/quick_add_service.dart';
import '../services/theme_service.dart';

/// 设置页：仅提供主题（配色）与语言设置
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final themeService = context.watch<ThemeService>();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildThemeSection(context, theme, themeService),
          const SizedBox(height: 12),
          _buildQuickAddSection(context, theme),
          const SizedBox(height: 12),
          _buildLanguageSection(context, theme),
        ],
      ),
    );
  }

  /// 主题设置卡片：明暗模式 + 配色选择
  Widget _buildThemeSection(BuildContext context, ThemeData theme, ThemeService ts) {
    final l10n = AppLocalizations.of(context);
    final colorLabels = [
      l10n.colorTeal,
      l10n.colorBlue,
      l10n.colorGreen,
      l10n.colorPurple,
    ];
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
                  l10n.theme,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SegmentedButton<ThemeMode>(
              segments: [
                ButtonSegment(value: ThemeMode.system, label: Text(l10n.system)),
                ButtonSegment(value: ThemeMode.light, label: Text(l10n.light)),
                ButtonSegment(value: ThemeMode.dark, label: Text(l10n.dark)),
              ],
              selected: {ts.mode},
              onSelectionChanged: (s) => ts.setMode(s.first),
              showSelectedIcon: false,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 20,
              runSpacing: 12,
              children: [
                for (var i = 0; i < ThemeService.seedOptions.length; i++)
                  _buildColorSwatch(theme, ts, i, colorLabels[i]),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 快速增加库存设置卡片：+10/50 或 +28/100
  Widget _buildQuickAddSection(BuildContext context, ThemeData theme) {
    final l10n = AppLocalizations.of(context);
    final quickAdd = context.watch<QuickAddService>();
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
                Icon(Icons.add_box_outlined,
                    size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Text(
                  l10n.quickAddStock,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('+10/50')),
                ButtonSegment(value: 1, label: Text('+28/100')),
              ],
              selected: {quickAdd.index},
              onSelectionChanged: (s) => quickAdd.setPreset(s.first),
              showSelectedIcon: false,
            ),
          ],
        ),
      ),
    );
  }

  /// 语言设置卡片：中文 / English
  Widget _buildLanguageSection(BuildContext context, ThemeData theme) {
    final l10n = AppLocalizations.of(context);
    final localeService = context.read<LocaleService>();
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
                Icon(Icons.language,
                    size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Text(
                  l10n.language,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'zh', label: Text('中文')),
                ButtonSegment(value: 'en', label: Text('English')),
              ],
              selected: {localeService.locale.languageCode},
              onSelectionChanged: (s) =>
                  localeService.setLocale(Locale(s.first)),
              showSelectedIcon: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorSwatch(
      ThemeData theme, ThemeService ts, int index, String label) {
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
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}