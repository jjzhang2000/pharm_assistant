# Agents 工作准则

## 与用户协作

- **不要质疑用户的操作方式，也不要怀疑用户提出的问题。** 用户报告的问题一律视为真实存在，直接排查技术根因。
- 用户已确认的操作（如重新构建、卸载重装）不要再重复确认。

## 项目约定

- 应用名称：小药箱（Android `android:label` / iOS `CFBundleDisplayName`）
- 版本号以 `pubspec.yaml` 的 `version` 字段为唯一来源
- 库存扣减以当天午夜为界计算
- 低频药品（频次低于每天 1 次）使用「下次服用日期」驱动扣减

## 构建

- Windows 环境构建偶发 Gradle 守护进程污染导致的 ACCESS_VIOLATION（exit code 268435466），运行 `build_apk_release.bat`（含三级自动重试）解决
- 构建前需设置 JAVA_HOME 指向 Android Studio 自带 JBR
