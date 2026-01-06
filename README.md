# ChiffonTranslator

ChiffonTranslator 是一款专为 macOS 设计的实时翻译工具。它能够捕获特定应用程序的音频输出，利用macOS内置的ASR模型进行语音转文字，并利用大语言模型 (LLM) 进行高质量的实时翻译，最终将翻译结果以悬浮字幕的形式展示在屏幕上。


## ✨ 主要功能

*   **🎯 应用级音频捕获**: 可以选择任意正在运行的应用程序（如 Safari, Chrome, QuickTime 等）作为音频源，而不干扰系统其他声音。
*   **🎙️ 实时语音识别**: 快速准确地将捕获的音频转换为文本。
*   **🧠 LLM 智能翻译**: 集成大语言模型（兼容 OpenAI API 格式），提供比传统机器翻译更自然、更准确的翻译结果。
*   **💬 悬浮字幕窗口**:
    *   **始终置顶**: 翻译结果显示在悬浮窗口中，不会被其他应用遮挡。
    *   **极简设计**: 界面简洁，专注于内容展示。
    *   **透明度调节**: 支持调整窗口透明度，避免遮挡背景内容。
*   **⚙️ 高度可定制**:
    *   支持自定义源语言和目标语言。
    *   支持配置任意兼容 OpenAI 接口的 LLM 服务（如 OpenAI, Azure OpenAI, 本地 LLM 等）。
    *   自定义 API Key、Base URL 和模型名称。

## 🛠️ 系统要求

*   macOS 14.0 或更高版本
*   Xcode 15.0+ (用于构建)

## 🚀 快速开始

### 安装与运行

1.  **克隆项目**
    ```bash
    git clone https://github.com/yourusername/ChiffonTranslator.git
    cd ChiffonTranslator
    ```

2.  **打开项目**
    使用 Xcode 打开项目文件夹。

3.  **构建与运行**
    在 Xcode 中点击 "Run" (或按 `Cmd + R`) 启动应用。

### 权限说明

为了正常工作，ChiffonTranslator 需要以下权限：
*   **屏幕录制 (Screen Recording)**: 用于捕获其他应用程序的音频（macOS 限制，捕获应用音频属于屏幕录制权限范畴）。
*   **麦克风 (Microphone)**: 用于语音识别输入（视具体实现而定）。

首次运行时，系统会弹出权限请求，请务必允许，否则无法捕获音频。

## 📖 使用指南

1.  **启动应用**: 打开 ChiffonTranslator，你会看到主控制中心。
2.  **选择目标应用**: 点击 "Select Application" 下拉菜单，选择你想要翻译的应用程序。如果列表未更新，点击右侧的刷新按钮。
3.  **配置语言**:
    *   **Source**: 视频或音频的原始语言。
    *   **Target**: 你希望看到的翻译语言。
4.  **模型设置 (Model Settings)**:
    *   输入你的 LLM API Key。
    *   设置 Base URL (例如 `https://api.openai.com/v1` 或其他中转地址)。
    *   输入模型名称 (例如 `gpt-3.5-turbo`, `gpt-4o`)。
    *   点击 "Save" 保存配置。
5.  **调整外观**: 拖动 "Window Opacity" 滑块调整悬浮窗的透明度。
6.  **开始翻译**: 点击 "Start Translation" (或类似按钮)，悬浮条将出现并开始显示翻译内容。

## 🏗️ 项目结构

*   `ChiffonTranslatorApp.swift`: 应用入口。
*   `Services/`: 核心服务层。
    *   `AudioCaptureService.swift`: 处理音频捕获。
    *   `SpeechRecognizerService.swift`: 处理语音转文字。
    *   `LLMService.swift`: 处理与 LLM 的通信。
    *   `TranslationManager.swift`: 协调音频、识别和翻译流程。
*   `Views/`: SwiftUI 视图文件。
    *   `ControlCenterView.swift`: 主设置界面。
    *   `FloatingBarView.swift`: 悬浮字幕条。

## 📄 许可证

[MIT License](LICENSE)
