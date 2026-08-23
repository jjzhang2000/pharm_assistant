# 小药箱

一款帮助普通用户管理日常药品库存的 Flutter 移动应用。基于用药计划自动预测药品耗尽时间，库存不足时通过 App 内提示和推送通知提醒及时补充。

## 功能特性

- **药品管理**：手动录入药品信息（名称、剂量、频次、库存等）
- **服用时间安排**：支持每天固定时段、每周/每月服用计划，按具体时刻自动扣减
- **智能预测**：按用药计划精确扣减库存，并计算剩余天数（长周期按离散剂量、短周期锚定到下次服药时间）
- **库存预警**：库存不足时卡片高亮 + 推送通知提醒
- **快速调整**：在卡片上直接 +/- 调整库存数量
- **纯本地存储**：数据保存在 JSON 文件中，无需网络，无需数据库

## 技术栈

| 技术 | 说明 |
|------|------|
| Flutter | 跨平台移动开发框架 |
| Provider | 状态管理 |
| path_provider | 获取应用文档目录 |
| flutter_local_notifications | 本地推送通知 |
| intl | 日期格式化 |
| JSON 文件 | 数据持久化（`medicines.json`） |

## 项目结构

```
lib/
├── main.dart                          # 应用入口
├── app.dart                           # MaterialApp 配置
├── models/
│   └── medicine.dart                  # 药品数据模型
├── services/
│   ├── storage_service.dart           # JSON 文件读写服务
│   └── notification_service.dart      # 推送通知服务
├── screens/
│   ├── home_screen.dart               # 首页（药品列表）
│   ├── add_edit_medicine_screen.dart   # 添加/编辑药品
│   └── medicine_detail_screen.dart    # 药品详情
└── widgets/
    ├── medicine_card.dart             # 药品卡片组件
    └── empty_state.dart               # 空状态组件
```

## 快速开始

### 环境要求

- Flutter SDK >= 3.0.0
- Android Studio / Xcode
- Android SDK（compileSdk 35）

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

## 数据存储

药品数据存储在应用文档目录下的 `medicines.json` 文件中，格式为 JSON 数组。个人用药数量通常较少（< 10 种），全量读写性能完全足够，无需数据库。

## 许可证

个人项目，仅供学习使用。