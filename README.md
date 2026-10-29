# 小药箱

一款帮助普通用户管理日常药品库存的 Flutter 移动应用。基于用药计划自动预测药品耗尽时间，库存不足时通过 App 内提示和推送通知提醒及时补充。

## 功能特性

- **多药箱管理**：支持创建、重命名、删除多个药箱，每个药箱独立存放药品并自动分配柔和的水粉/水彩底色，AppBar 左右滑动切换
- **备用药箱**：在所有药箱最末（最右屏）固定一个「备用药箱」，其中的药品只记录存量、不自动扣减、不显示剩余天数、不参与短缺统计，适合存放暂时不服用的药品
- **药品管理**：手动录入药品信息（名称、剂量、频次、库存等）
- **服用时间安排**：支持每天固定时段、每周/每月服用计划，按具体时刻自动扣减
- **智能预测**：按用药计划精确扣减库存，并计算剩余天数（长周期按离散剂量、短周期锚定到下次服药时间）
- **库存预警**：库存不足的药品高亮，列表按星标优先、各自按剩余天数递增排序 + 推送通知提醒
- **短缺药品负一页**：App 启动默认显示短缺药品页（负一页），星标药品聚合在顶部，其余按药箱分组显示，条目显示「剩余存量 / 剩余天数」
- **短缺页分享**：负一页 AppBar 右侧「分享」按钮一键生成整页长截图并保存到系统相册，随后提示可在微信、QQ 等应用中分享给好友
- **设置页**：负一页 AppBar 右侧「设置」按钮进入设置页，仅保留主题（明暗模式 + 四色配色）与语言设置
- **信息页**：负一页 AppBar 右侧「信息」按钮进入信息页，展示版本说明与版权声明，并分栏滚动展示使用指南（中英文）与版本更新记录
- **主题切换**：支持亮色/暗色主题（跟随系统 / 亮色 / 暗色），并提供青、蓝、绿、紫四种配色，在「设置」页内即可切换、即时生效并持久保存
- **多语言支持**：界面文案统一管理，支持简体中文与英文切换；「设置」页「语言」选项即时切换并持久保存，使用指南亦随语言切换
- **快速调整**：在卡片上直接 +/- 调整库存数量
- **药品移动**：详情页「更多」菜单可把药品移动到其他药箱；长按卡片进入全屏概览，拖动到目标药箱或「新药箱」完成移动
- **星标药品**：卡片名称下方用星标图标一键标记，星标药品在药箱页与负一页顶部优先展示
- **星标短缺后台通知**：星标药品跌破警戒线时即使 App 未运行也会推送提醒；补充后重新预排期，不重复发送
- **纯本地存储**：数据保存在 JSON 文件中，无需网络，无需数据库

## 技术栈

| 技术 | 说明 |
|------|------|
| Flutter | 跨平台移动开发框架 |
| Provider | 状态管理 |
| path_provider | 获取应用文档目录 |
| flutter_local_notifications | 本地推送通知 |
| gal | 保存图片到系统相册（负一页分享长截图） |
| package_info_plus | 运行时读取应用版本号 |
| flutter_markdown | 渲染信息页使用指南（Markdown） |
| intl / flutter_localizations | 国际化（gen-l10n，ARB 资源文件） |
| JSON 文件 | 数据持久化（`medicines.json`） |

## 项目结构

```
lib/
├── main.dart                          # 应用入口
├── app.dart                           # MaterialApp 配置
├── theme/
│   └── app_colors.dart                # 主题色板与语义色（明暗自适应）
├── l10n/
│   ├── app_en.arb                      # 英文字符串资源
│   ├── app_zh.arb                      # 中文字符串资源
│   ├── unit_labels.dart                # 剂型/周期单位 → 本地化标签
│   └── gen/                            # gen-l10n 生成的本地化代码
├── models/
│   ├── medicine.dart                  # 药品数据模型
│   └── medicine_box.dart              # 药箱数据模型
├── services/
│   ├── storage_service.dart           # JSON 文件读写服务
│   ├── notification_service.dart      # 推送通知服务
│   ├── theme_service.dart             # 主题（明暗/配色）状态管理与持久化
│   └── locale_service.dart            # 语言偏好状态管理与持久化
├── screens/
│   ├── home_screen.dart               # 首页（多药箱切换 + 短缺药品负一页）
│   ├── add_edit_medicine_screen.dart   # 添加/编辑药品
│   ├── medicine_detail_screen.dart    # 药品详情
│   ├── settings_screen.dart           # 设置页（主题 + 语言）
│   └── info_screen.dart               # 信息页（版本信息、使用指南、更新记录）
└── widgets/
    ├── medicine_card.dart             # 药品卡片组件
    └── empty_state.dart               # 空状态组件
```

## 快速开始

### 环境要求

- Flutter SDK >= 3.0.0
- Android Studio / Xcode
- Android SDK（compileSdk 36）

### 运行

```bash
# 安装依赖
flutter pub get

# 在模拟器或真机上运行
flutter run
```

### 构建 APK

```bash
flutter build apk --release
```

APK 输出路径：`build/app/outputs/flutter-apk/app-release.apk`

### 构建 App Bundle（上架 Google Play）

```bash
flutter build appbundle --release
```

AAB 输出路径：`build/app/outputs/bundle/release/app-release.aab`

应用包名（applicationId / namespace）为 `com.artozi.pharm_assistant`。Release 构建使用正式签名：密钥库 `android/app/upload-keystore.jks`（别名 `upload`）+ 配置 `android/key.properties`，两者均已加入 `.gitignore`，不会提交到仓库。

## 数据存储

药箱与药品数据存储在应用文档目录下的 `medicines.json` 文件中，格式为 `{ "boxes": [...], "medicines": [...] }`。个人用药数量通常较少（< 10 种），全量读写性能完全足够，无需数据库。库存数值统一舍入到 2 位小数存储，避免浮点误差。

## 版本更新记录

版本更新记录以 [assets/changelog.json](assets/changelog.json) 为唯一来源，应用内「信息」页直接读取该文件展示。

## 许可证

本项目基于 [MIT 许可证](https://opensource.org/licenses/MIT) 开源，版权所有 © 2026 Eddie J. Zhang。