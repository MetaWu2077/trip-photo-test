# 旅途相册 (Trip Photo)

一款基于 Flutter 3+ 构建的旅行相册 App，帮助你记录和分享旅途中的精彩瞬间。

---

## 功能说明

- **首页**：以网格形式展示旅行相册列表，每张卡片显示封面图、目的地、照片数量和时间。
- **相册详情页**：进入相册后以九宫格形式浏览所有照片。
- **照片预览页**：全屏查看大图，支持左右滑动切换、双指缩放，点击屏幕可切换信息浮层的显示/隐藏。

> 当前版本使用本地 Mock 数据 + 网络占位图（[picsum.photos](https://picsum.photos)），无需任何账号或密钥配置即可直接运行。

---

## 项目结构

```
trip-photo-test/
├── lib/
│   ├── main.dart                  # 应用入口
│   ├── models/
│   │   ├── photo.dart             # Photo 数据模型
│   │   ├── album.dart             # Album 数据模型
│   │   └── mock_data.dart         # 本地 Mock 数据
│   ├── screens/
│   │   ├── home_screen.dart       # 首页（相册列表）
│   │   ├── album_detail_screen.dart  # 相册详情页（照片网格）
│   │   └── photo_preview_screen.dart # 照片预览页（全屏大图）
│   └── widgets/
│       ├── album_card.dart        # 相册卡片组件
│       └── photo_grid_item.dart   # 照片网格项组件
├── android/                       # Android 项目配置
├── ios/                           # iOS 项目配置
├── test/
│   └── widget_test.dart           # 基础 Widget 测试
└── pubspec.yaml
```

---

## 如何安装依赖与运行

### 前置条件

- [Flutter SDK](https://flutter.dev/docs/get-started/install) **3.19+**（推荐使用 stable channel）
- Android Studio / VS Code（含 Flutter 插件）
- Android 模拟器或真机（Android 5.0+）

### 步骤

```bash
# 1. 克隆仓库
git clone https://github.com/MetaWu2077/trip-photo-test.git
cd trip-photo-test

# 2. 安装依赖
flutter pub get

# 3. 代码静态分析
flutter analyze

# 4. 运行（确保有连接的设备或启动模拟器）
flutter run

# 5. 运行测试
flutter test
```

### 编译 Release APK

```bash
flutter build apk --release
# APK 产物路径：build/app/outputs/flutter-apk/app-release.apk
```

---

## 技术栈

| 技术 | 说明 |
|------|------|
| Flutter 3+ | 跨平台 UI 框架 |
| Navigator 1.0 | 页面路由导航 |
| StatelessWidget / StatefulWidget | 状态管理 |
| Image.network | 网络图片加载（含加载动画与错误处理）|
| InteractiveViewer | 照片缩放 |
| SliverAppBar | 相册详情页可折叠头部 |
