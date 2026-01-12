# ParkingGatePro – iOS App

ParkingGatePro 是一套以 iOS 為平台的停車場管理 App，  
提供停車場人員以「掃描」或「手動輸入」方式，快速完成車輛入場 / 出場作業。

本專案為前後端分離架構：
- 前端：iOS App（SwiftUI + OCR）
- 後端：Spring Boot API（另見 ParkingGatePro-Backend）

---

## 功能簡介
- 📷 車牌 OCR 掃描（相機即時辨識）
- ⌨️ 手動輸入車牌
- 🚗 入場 / 出場流程（Check-In / Check-Out）
- 💳 月租車自動辨識（免費）
- 🧾 顯示停車結果（Session / Event / Fee）
- 🛠 後台管理介面
  - 車輛管理（新增 / 編輯 / 刪除）
  - 月租管理
  - 最近活動紀錄
- ⚙️ Server 設定（Base URL / Gate 設定）

---

## 技術架構
- SwiftUI
- AVFoundation（Camera / OCR）
- MVVM 架構
- RESTful API
- 非同步處理（async / await）

---

## 專案結構





ParkingGatePro/
├─ App/
├─ Core/
├─ Networking/
├─ OCR/
├─ ViewModels/
└─ Views/



---

## 執行方式
1. 使用 Xcode 開啟 `ParkingGatePro.xcodeproj`
2. 設定後端 API Base URL（App 內 Settings）
3. 連接實體 iPhone（建議）或模擬器
4. Run 專案

---

本專案為課堂期末實作，重點在於：
- AI 協作開發流程
- UML 設計
- 前後端整合實務
