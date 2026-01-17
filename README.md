# AutoScroll Pro 🚀

[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Android](https://img.shields.io/badge/Android-3DDC84?style=for-the-badge&logo=android&logoColor=white)](https://developer.android.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)

**AutoScroll Pro** is the ultimate hands-free utility for modern short-form video consumption. Whether you're multitasking, eating, or just relaxing, AutoScroll Pro takes control of your feed, automatically scrolling to the next video so you don't have to lift a finger.

Designed for **Instagram Reels**, **TikTok**, **YouTube Shorts**, and more.

---

## ✨ Features

- **📱 Smart Overlay Control**: A sleek, unobtrusive floating widget gives you Play/Pause and Next controls from anywhere.
- **⏱️ Adjustable Scroll Timer**: Set your preferred viewing time per video—from quick skips to deep dives.
- **🎲 Humanized Scrolling**: Adds random variance to the scroll timer to mimic human behavior (e.g., 10s +/- 2s).
- **💤 Sleep Timer**: Automatically stop scrolling after a set duration (e.g., 30 mins) so you can fall asleep watching.
- **🧠 Intelligent App Detection**: The overlay automatically appears when you open a compatible app and vanishes when you leave or minimize it to save battery.
- **⚡ Background Efficiency**: Optimized to run smoothly in the background without draining your resources.
- **👆 System-Level Gestures**: Uses advanced Android Accessibility integration for natural, human-like swipe interactions.
- **🎨 Modern Glassmorphism UI**: A beautiful, premium dark-mode interface with smooth gradients and animations.

---

## 📸 Screenshots

<p align="center">
  <img src="docs/autoscroll-screen.jpg" width="30%" alt="Main Screen" style="border-radius: 10px; margin: 10px;" />
  <img src="docs/with-overlay.jpg" width="30%" alt="Overlay Controls" style="border-radius: 10px; margin: 10px;" />
</p>

---

## 🚀 Getting Started

### Prerequisites

- **Android Device** (Android 7.0 / API 24 or higher)
- **Flutter SDK** (Latest Stable)
- IDE (VS Code or Android Studio)

### Installation

1. **Clone the repository**:
   ```bash
   git clone https://github.com/dipak-github/autoscroll_app.git
   cd autoscroll_app
   ```

2. **Install dependencies**:
   ```bash
   flutter pub get
   ```

3. **Run the app**:
   ```bash
   flutter run
   ```

---

## 📖 How to Use

1. **Grant Permissions**: Upon first launch, the app will guide you to enable:
   - **Display over other apps**: Required to show the floating controller.
   - **Accessibility Service**: Required to perform the actual scrolling action.
   - **Notification**: Required to keep the service running in the background (Android 13+).

2. **Configure**: Set your desired **Scroll Duration** (e.g., 15 seconds) in the app.

3. **Activate**: Toggle the service **ON**.

4. **Enjoy**: Open Instagram, TikTok, or YouTube Shorts. The overlay will appear automatically. Tap **Play** to start auto-scrolling!

---

## 🛠️ Tech Stack & Architecture

Built with a focus on performance, stability, and clean code principles.

- **Framework**: [Flutter](https://flutter.dev) (Dart)
- **State Management**: [Riverpod](https://riverpod.dev) (Clean Architecture)
- **Core Services**:
  - `flutter_overlay_window`: For the floating UI.
  - `flutter_background_service`: For persistent background execution.
  - **Native Android (Kotlin)**: Custom Accessibility Service implementation for precise gesture dispatching.
- **Communication**: Bidirectional `MethodChannel` usage for syncing state between the Main UI, Background Service, and Overlay.

---

## ⚠️ Important Notes

- **Privacy**: This app uses Accessibility Services **strictly** for performing swipe gestures. It **does not** read your screen content, log your keystrokes, or access personal data.
- **Battery Optimization**: If the app stops working in the background, ensure you have disabled "Battery Optimization" for AutoScroll Pro in your device settings.

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

<p align="center">
  Made with ❤️ by Dipak
</p>
