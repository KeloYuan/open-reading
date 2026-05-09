<p align="center">
  <img src="https://capsule-render.vercel.app/api?type=waving&color=0:0d1117,50:1a1b26,100:0d1117&height=200&section=header&text=Open%20Reading&fontSize=50&fontColor=f7768e&fontAlignY=40&desc=%E5%B0%8F%E5%85%83%E9%98%85%E8%AF%BB%E5%99%A8%20%E2%80%94%20An%20Elegant%20Cross-Platform%20Ebook%20Reader&descSize=16&descAlignY=60&descAlign=50&animation=fadeIn" width="100%" />
</p>

<p align="center">
  <a href="https://github.com/KeloYuan/open-reading/releases"><img src="https://img.shields.io/github/v/release/KeloYuan/open-reading?style=for-the-badge&color=f7768e" /></a>
  <a href="https://github.com/KeloYuan/open-reading/stargazers"><img src="https://img.shields.io/github/stars/KeloYuan/open-reading?style=for-the-badge&color=e0af68" /></a>
  <img src="https://img.shields.io/badge/Flutter-3.35-blue?style=for-the-badge&logo=flutter&logoColor=white" />
  <img src="https://img.shields.io/badge/Dart-3.9-0175C2?style=for-the-badge&logo=dart&logoColor=white" />
  <img src="https://img.shields.io/badge/Rust-Powered-da4326?style=for-the-badge&logo=rust&logoColor=white" />
  <img src="https://img.shields.io/badge/License-MIT-green?style=for-the-badge" />
</p>

<p align="center">
  <b>专注阅读本身的电子书阅读器</b><br/>
  <sub>不社交 · 不弹窗 · 不开屏广告 · 只安静地读书</sub>
</p>

<p align="center">
  <b>English</b> · <a href="#-关于小元阅读器">中文</a>
</p>

<br/>

> **Open Reading** is the open-source edition of [Origo Reader (小元读书)](https://github.com/KeloYuan/Origo-Reader).  
> Built with Flutter + Rust, one codebase covers Android, iOS, macOS, Windows, and Linux.  
> No social features. No ads. No distractions. Just books.

<br/>

---

<br/>

## ✨ Why Open Reading

<table>
  <tr>
    <td width="50%" valign="top">

#### 📖 读得舒服
- 📄 EPUB · PDF · TXT · ZIP 全格式
- 📐 二分搜索精准分页，不跳不闪
- 🔄 翻页 / 滑动 / 滚动 / 3D 仿真
- 🎨 多种阅读主题 + 自定义背景色
- 🔤 字号 · 行距 · 字距 · 缩进全可调
- 🌙 护眼暗色模式

</td>
    <td width="50%" valign="top">

#### 🛠️ 用得省心
- 🔖 书签 · 一键快速跳转
- ✏️ 高亮标注 + 笔记，深度阅读
- 🔊 TTS 朗读 + 逐句高亮
- 📊 阅读统计可视化（日/周/月）
- ☁️ WebDAV 全量云端同步
- 🦀 Rust 核心引擎，极致性能

</td>
  </tr>
</table>

<br/>

---

<br/>

## 📱 Supported Platforms

<table>
  <tr>
    <td align="center"><img src="https://img.shields.io/badge/Android-3DDC84?style=for-the-badge&logo=android&logoColor=white" /><br/><sub>API 21+</sub></td>
    <td align="center"><img src="https://img.shields.io/badge/iOS-007AFF?style=for-the-badge&logo=apple&logoColor=white" /><br/><sub>iOS 11+</sub></td>
    <td align="center"><img src="https://img.shields.io/badge/macOS-000000?style=for-the-badge&logo=apple&logoColor=white" /><br/><sub>Apple Silicon</sub></td>
    <td align="center"><img src="https://img.shields.io/badge/Windows-0078D6?style=for-the-badge&logo=windows&logoColor=white" /><br/><sub>Win 10+</sub></td>
    <td align="center"><img src="https://img.shields.io/badge/Linux-FCC624?style=for-the-badge&logo=linux&logoColor=black" /><br/><sub>x64</sub></td>
  </tr>
</table>

<br/>

---

<br/>

## 🚀 Getting Started

```bash
git clone https://github.com/KeloYuan/open-reading.git
cd open-reading
flutter pub get
flutter run
```

### Build

```bash
flutter build apk        # Android
flutter build ios        # iOS
flutter build macos      # macOS
flutter build windows    # Windows
flutter build linux      # Linux
```

<br/>

---

<br/>

## 📦 Tech Stack

```
Frontend    → Flutter 3.35 + Dart 3.9 + Material 3
State       → Riverpod 2.6
Database    → SQLite (sqflite)
Reader      → WebView (Foliate) + Rust Core Engine
Sync        → WebDAV
```

<br/>

---

<br/>

## 📁 Project Structure

```
lib/
├── main.dart              # Entry point
├── models/                # Data models (books, chapters, bookmarks)
├── pages/                 # UI pages & home components
├── reader_core/           # Reader engine core (parser, document model)
├── services/              # Business services (import, DAO, sync, reading, TTS)
├── utils/                 # Themes, layout, encoding utilities
├── widgets/               # Reusable UI components
└── l10n/                  # Internationalization
```

<br/>

---

<br/>

## 🗺️ Roadmap

- [x] EPUB / PDF / TXT / ZIP 格式支持
- [x] 智能分页引擎（二分搜索）
- [x] 多种翻页模式（含 3D 仿真）
- [x] 多种阅读主题 + 自定义主题
- [x] 书签 · 高亮 · 笔记
- [x] TTS 文本朗读
- [x] 阅读统计图表
- [x] WebDAV 全量同步
- [ ] 🔥 书源搜索 & 在线阅读
- [ ] URL 导入书籍
- [ ] iCloud 同步
- [ ] 全局暗色模式
- [ ] 自定义字体导入

<br/>

---

<br/>

## 🤝 Contributing

欢迎贡献！无论是修 bug、加功能还是改进文档。

1. Fork 本仓库
2. 创建分支 (`git checkout -b feature/amazing-feature`)
3. 提交 (`git commit -m 'feat: add amazing feature'`)
4. 推送 (`git push origin feature/amazing-feature`)
5. 开 Pull Request

<br/>

---

<br/>

## ⭐ Star History

<p align="center">
  <a href="https://star-history.com/#KeloYuan/open-reading&Date">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/svg?repos=KeloYuan/open-reading&type=Date&theme=dark" />
      <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/svg?repos=KeloYuan/open-reading&type=Date" />
      <img alt="Star History Chart" src="https://api.star-history.com/svg?repos=KeloYuan/open-reading&type=Date" width="600" />
    </picture>
  </a>
</p>

<br/>

---

<br/>

## 🌍 关于小元阅读器

<p align="center">
  <b>让阅读回归阅读本身。</b>
</p>

<p align="center">
  排版好不好看 · 翻页顺不顺手 · 笔记好不好找<br/>
  <sub>—— 这些才是阅读器该关心的事。</sub>
</p>

<br/>

## 📄 License

[MIT](LICENSE) © [KeloYuan](https://github.com/KeloYuan)

<br/>

<p align="center">
  Part of <a href="https://github.com/KeloYuan/Origo-Reader"><b>Origo Reader (小元读书)</b></a> — Reading, refined.<br/><br/>
  <a href="https://github.com/KeloYuan/open-reading/stargazers">
    <img src="https://img.shields.io/badge/⭐_Star_支持-FFD600?style=for-the-badge&logo=github&logoColor=black" />
  </a>
</p>
