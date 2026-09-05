# Expense Logger 🪵

A clean, fast, and professional Flutter application designed for logging daily recurring expenses with a single tap. 

No clunky inputs, no hassle inserting dates and timestamps manually—just open, tap, and done.

![App Icon](web/icons/Icon-192.png)

## 🌟 Key Features

- **⚡ Instant 1-Tap Logging**: Pre-configured quick buttons for daily routine expenses (Metro, Bus, Auto, etc.) with pre-set amounts and custom export descriptions.
- **📱 Responsive Button Scaling**: Cards automatically adjust their height and aspect ratio so all your quick buttons fit cleanly on the screen without excessive vertical scrolling.
- **🪵 App Icon**: Custom **🪵** (log) icon representing instant expense logging.
- **🛡️ Safe Unlogging & Deletion**:
  - **Front Page Safety**: Delete buttons and swipe gestures are disabled on the main tab to prevent accidental deletions.
  - **Confirmation Dialog**: Deleting logs in the **History** tab requires explicit modal confirmation.
  - **Instant Undo**: Confirmation SnackBar allows instant "Undo" right after logging or unlogging.
- **🎨 Icon Appearance Toggle**:
  - **Theme Green Default**: Signature green (`#176b5b`) Material Icons for a sleek, uniform look.
  - **Full-Color Emojis**: Toggle switch in the quick button editor lets you use vibrant unicode emojis.
- **📊 Reports & Formal Exporting**:
  - **PDF Export**: Generate formal, formatted expense reports ready for employer reimbursement or accounting.
  - **Text Copy**: Copy structured plain-text reports to clipboard in one tap.
  - **Weekly, Monthly, Yearly Totals**: Live calculation of total expenditure.
- **💾 Local Persistent Storage**: Saved automatically to local device storage via `shared_preferences`.

---

## 🛠️ Tech Stack

- **Framework**: Flutter (Dart)
- **State & Storage**: Flutter Material 3, `shared_preferences`
- **PDF & Printing**: `pdf`, `printing`
- **Formatting**: `intl`

---

## 🚀 Building & Running

### Run Locally (Web / Desktop / Device)
```bash
flutter run
```

### Build Web App
```bash
flutter build web
```

### Build Android Release APK
```bash
flutter build apk --release
```
The output APK file will be located at:
`build/app/outputs/flutter-apk/app-release.apk`

---

## 📄 License
This project is open source and available for public use.
