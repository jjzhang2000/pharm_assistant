# Agents 协作指南

本文档定义了 AI 代理在「药品助手」项目中的协作规则与工作流程。

## 项目概览

- **项目名称**：药品助手（Medicine Assistant）
- **技术栈**：Flutter + Provider + JSON 文件存储
- **目标平台**：Android / iOS
- **代码仓库**：`d:/Projects/pharm_assistant`

## 代理角色

| 代理 | 职责 |
|------|------|
| 架构师（Architect） | 需求分析、技术方案设计、数据模型设计 |
| 开发者（Developer） | 代码实现、Bug 修复、功能开发 |
| 审查者（Reviewer） | 代码审查、质量把控、最佳实践检查 |
| 测试者（Tester） | 测试用例编写、功能验证、回归测试 |

## 协作流程

### 1. 需求阶段

- 用户提出需求后，由架构师分析需求，产出计划文档
- 计划文档存放于 `.trae/documents/` 目录
- 关键决策记录在 `project_memory.md` 中

### 2. 开发阶段

- 开发者按照计划文档逐步实现
- 遵循项目既定的代码规范（见下方「编码规范」）
- 每次修改后确保 `flutter analyze` 无错误

### 3. 审查阶段

- 审查者检查代码质量和安全性
- 关注点：状态管理规范、数据持久化正确性、通知逻辑健壮性

### 4. 测试阶段

- 测试者编写单元测试（`test/` 目录）
- 验证要点：CRUD 操作、剩余天数计算、库存预警逻辑

## 编码规范

### 状态管理

- 使用 `provider` + `ChangeNotifier`
- `StorageService` 作为全局单例，通过 `ChangeNotifierProvider.value` 注入
- 数据变更后必须调用 `notifyListeners()`

### 数据存储

- 所有药品数据存储在 `medicines.json` 中
- ID 使用 `DateTime.now().millisecondsSinceEpoch.toString()` 生成
- 避免引入数据库依赖（sqflite 等）

### 命名规范

- 文件名：snake_case（如 `home_screen.dart`）
- 类名：PascalCase（如 `MedicineCard`）
- 变量/方法：camelCase（如 `remainingDays`）
- 常量：lowerCamelCase 或 SCREAMING_SNAKE_CASE

### 文件组织

- `models/` — 数据模型
- `services/` — 业务逻辑服务
- `screens/` — 页面
- `widgets/` — 可复用组件

## 关键约束

1. 应用名称为「药品助手」，定位为日常药品管理
2. 数据存储仅使用 JSON 文件，不使用数据库
3. Android 构建配置：compileSdk=35, ndkVersion=28.2.13676358, coreLibraryDesugaring
4. Gradle 8.7, AGP 8.6.0, Kotlin 2.1.0

## 通知机制

- 应用启动时初始化 `NotificationService`
- 首页加载后检查所有药品，库存不足时触发通知
- 通知初始化失败不应阻塞应用启动（已通过 timeout 容错）

## 常用命令

```bash
# 依赖安装
flutter pub get

# 代码分析
flutter analyze

# 运行测试
flutter test

# 构建 APK
flutter build apk --release

# 清理构建
flutter clean
```