import 'package:flutter/material.dart';

/// 浅色水粉底上的深色前景，保证在所有 boxPalette / 语义浅色下的对比度
const Color _onSoftLight = Color(0xFF2B2F33);

/// 短缺页 AppBar 底色（浅粉）
const Color shortageSoft = Color(0xFFE8B4B4);

/// 星标聚合卡标题底色（浅粉）
const Color starSoft = Color(0xFFF2C9C9);

/// 星标强调色（红），浅/暗色下均可作为图标强调色
const Color starRed = Color(0xFFE53935);

/// 将浅色「软底」颜色适配当前明暗模式：
/// 亮色下原样返回；暗色下压暗明度、降饱和，避免大面积浅色块刺眼。
Color softSurface(Color base, Brightness brightness) {
  if (brightness == Brightness.light) return base;
  final hsl = HSLColor.fromColor(base);
  return hsl
      .withLightness((hsl.lightness * 0.2).clamp(0.06, 0.30).toDouble())
      .withSaturation((hsl.saturation * 0.45).clamp(0.0, 0.55).toDouble())
      .toColor();
}

/// 软底色块上的前景（文字/图标）颜色
Color onSoftSurface(Brightness brightness) =>
    brightness == Brightness.light ? _onSoftLight : Colors.white;