# Roadmap 🗺️

> [!NOTE]
> This document outlines the development status and future plans for **LiquidMonitor**.
> Priorities may change based on technical challenges and user feedback.

## 🟢 Implemented Features (Ready)

### Core Monitoring

- [x] **App Infrastructure**: SwiftUI + AppKit Hybrid Lifecycle `AppDelegate`.
- [x] **Theme Support**: Basic System/Dark/Light mode toggling (via `AppTheme`).
- [x] **Process Monitoring**: Real-time process listing (`ProcessProvider`).
- [x] **Hardware Monitoring Integration**: Basic scaffolding for `HardwareMonitor`.
- [x] **Battery Monitoring Integration**: Basic scaffolding for `BatteryMonitor`.

### UI/UX

- [x] **Dashboard Layout**: Basic window configuration (Sidebar + Content).
- [x] **Window Management**: Resizable, closable, miniaturizable Pro window.

---

## 🟡 In Progress (Alpha)

### Advanced Hardware Metrics (Apple Silicon M3)

- [ ] **CPU Real-time Usage**: Precise per-core usage visualization.
- [ ] **GPU Usage**: Metal-based GPU load monitoring.
- [ ] **Thermal Pressure**: Apple Silicon sensor access for temperature/throttling.
- [ ] **Memory Pressure**: RAM usage breakdown (App, Wired, Compressed).

### Dashboard Widgets

- [ ] **CPU History Chart**: Historical graph of CPU load.
- [ ] **Network Activity**: Up/Down speed indicators.

---

## 🔴 Todo (Backlog)

### Features

- [ ] **Menu Bar Extension**: A lightweight status bar item for quick stats.
- [ ] **Custom Alerts**: Notifications for high CPU/Memory usage.
- [ ] **Process Killer**: Ability to terminate processes directly from the list.
- [ ] **Fan Control**: (Experimental) Read/Write fan speeds if accessible.
- [ ] **Battery Health**: Cycle count and maximum capacity reading.

### Optimization & Tech Debt

- [ ] **Performance**: Optimize monitoring loops to reduce app's own CPU impact.
- [ ] **Persistence**: Save user window size and specific view settings.
- [ ] **Localization**: English (Default) + French support.

---

## 🧪 Known Issues

* **M3 Specificity**: Crashes or shows 0 values on non-Apple Silicon devices.
- **Permissions**: May require full disk access for some process details.
