# SSEMarket-X

使用 **Flutter** 构建的多端应用，目标平台包含：

- **Android**（Phone / Pad）
- **iOS**（iPhone / iPad）
- **HarmonyOS**（Mobile / Tablet）
- **Desktop**（Windows / macOS / Linux）

---

## 环境要求

- Flutter SDK（推荐使用 `stable` 渠道）
- Dart SDK（随 Flutter 附带）
- 对应平台的构建工具：
  - Android：Android Studio / Android SDK、配置好 ANDROID_HOME
  - iOS：Xcode（仅限 macOS）
  - Web：任意现代浏览器（Chrome / Edge / Safari 等）
  - Desktop：
    - Windows：Visual Studio（含 C++ 桌面开发组件）
    - macOS：Xcode
    - Linux：常见构建工具（cmake、gcc 等）

检查 Flutter 环境：

```bash
flutter doctor
```

---

## 依赖安装

在项目根目录执行：

```bash
flutter pub get
```

如使用了本地配置文件（如 `assets`、环境变量等），请根据实际情况在 `pubspec.yaml` 中确认资源已正确声明。

---

## 运行与构建 - Android

### Debug 运行

连接真机或启动 Android 模拟器后，在项目根目录执行：

```bash
flutter run -d android
```

或者直接：

```bash
flutter run
```

### Release 构建 APK

构建 Release APK（分 ABI，体积更小）：

```bash
flutter build apk --release --split-per-abi --no-tree-shake-icons
```

构建完成后，APK 位于：

- `build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk`
- `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`
- `build/app/outputs/flutter-apk/app-x86_64-release.apk`

如需构建「通用 APK」（单个大包），可以执行：

```bash
flutter build apk --release --no-tree-shake-icons
```

---

## 运行与构建 - iOS

> 仅在 **macOS** 上支持 iOS 构建。

### Debug 运行

连接 iPhone 或启动 iOS 模拟器后：

```bash
flutter run -d ios
```

或者直接在 Xcode 中打开 `ios/Runner.xcworkspace`，选择设备后点击 Run。

### Release 构建（归档 IPA）

1. 生成 iOS Release 构建配置：

   ```bash
   flutter build ios --release
   ```

2. 打开 Xcode：
   - 打开 `ios/Runner.xcworkspace`
   - 选择 `Generic iOS Device` 或真实设备
   - 使用 `Product -> Archive` 进行归档
   - 在 Organizer 中导出 IPA 或上传到 App Store Connect

---

## 运行与构建 - Web

### Debug 运行（开发模式）

在本地启动 Web 开发服务器：

```bash
flutter run -d chrome
```

或指定其他浏览器设备 ID：

```bash
flutter devices   # 查看可用设备
flutter run -d <device_id>
```

### Release 构建（静态资源）

构建 Web 静态文件：

```bash
flutter build web --release
```

构建产物位于：

- `build/web/`

可部署到任意静态站点服务（如 Nginx、GitHub Pages、OSS/对象存储 等）。

---

## 运行与构建 - Desktop（Windows / macOS / Linux）

确保已启用对应桌面平台支持（仅需执行一次）：

```bash
flutter config --enable-windows-desktop
flutter config --enable-macos-desktop
flutter config --enable-linux-desktop
```

### Debug 运行

根据当前系统选择对应平台运行，例如：

```bash
flutter run -d windows   # 在 Windows 上
flutter run -d macos     # 在 macOS 上
flutter run -d linux     # 在 Linux 上
```

### Release 构建

```bash
flutter build windows --release
flutter build macos --release
flutter build linux --release
```

各平台的可执行文件/安装包输出在对应的 `build/` 目录下，例如：

- Windows：`build/windows/`
- macOS：`build/macos/`
- Linux：`build/linux/`

---

## 运行与构建 - OpenHarmony / HarmonyOS (OHOS)

> OHOS 平台需要使用 OpenHarmony TPC 维护的 Flutter SDK 分支。

### 环境准备

1. 克隆 OpenHarmony TPC 的 Flutter SDK：

   ```bash
   git clone -b br_3.22.0-ohos-1.0.4 https://gitcode.com/openharmony-tpc/flutter_flutter.git ~/flutter-ohos
   export PATH="$HOME/flutter-ohos/bin:$PATH"
   ```

2. 安装 HarmonyOS SDK 和命令行工具（hvigor、ohpm 等）

3. 验证环境：

   ```bash
   flutter doctor
   ```

### 依赖说明

本项目使用 `pubspec_overrides.yaml` 管理 OHOS 平台的特殊依赖。该文件会自动覆盖 `pubspec.yaml` 中的部分依赖，从 OpenHarmony TPC 的 git 仓库拉取适配版本。

- **构建 OHOS 平台**：保留 `pubspec_overrides.yaml` 文件
- **构建其他平台**：删除或重命名 `pubspec_overrides.yaml` 文件

### Debug 运行

连接 HarmonyOS 设备或启动模拟器后：

```bash
flutter pub get
flutter run -d ohos
```

### Release 构建 HAP

```bash
flutter pub get
flutter flutter build hap --release --no-codesign
```

构建产物位于：

- `build/ohos/hap/entry-default-unsigned.hap`（未签名）

如需签名，请配置签名证书后执行：

```bash
flutter build hap --release
```

---

## 常用开发命令

- 热重载开发：

  ```bash
  flutter run
  ```

- 格式化代码：

  ```bash
  flutter format lib
  ```

- 运行测试：

  ```bash
  flutter test
  ```
