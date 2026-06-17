# BNMIT Companion App

BNMIT Companion is a Flutter-based mobile application designed to provide a seamless and modern interface for BNMIT students to access their Contineo portal data — all scraped securely on-device, no backend server required.

---

## 🆕 What's New in v2.0

### ✅ Exam History — Complete Rewrite
- **Semester selector dropdown** — choose any semester from a clean dropdown
- **Subject-wise results** displayed natively as Flutter cards — no PDF download, no file I/O
- Shows **GPA**, **Grade**, **Credits Registered**, **Credits Earned** per subject
- **SGPA & CGPA** displayed on the semester summary card
- **Overall CGPA pill** at the top showing cumulative GPA + credits earned/remaining
- **Pass/Fail badge** per subject (derived from credits earned vs registered)
- Lateral entry students automatically get semesters labelled from **Sem 3**
- Data is parsed directly from the portal result page — **instant display** after first load (no secondary network calls)

### ✅ Marks Screen — Rework
- Reworked internal assessment (CIE) marks view
- Added a dedicated `MarksScreen` with provider-driven data

### ✅ Dashboard Screen
- New `DashboardScreen` as the home tab showing an at-a-glance summary of attendance, marks, and results

### ✅ Shell / Navigation
- Bottom navigation shell (`ShellScreen`) with proper route management via `go_router`
- Screens: Dashboard · Attendance · Marks · Exam History · Settings

### ✅ Authentication Improvements
- Enhanced HTTP session handling with 15s timeouts and retry logic
- Improved redirect detection and cookie management

### ✅ App Constants
- Centralised URL and API params in `AppConstants` for easier future maintenance

---

## 📱 Features (v2.0)

- 🔐 **Secure Login** — Contineo portal credentials, session stored locally
- 📊 **Attendance** — Live attendance percentage with subject-wise breakdown and shortage warnings
- 📝 **CIE Marks** — Internal assessment marks per subject
- 🎓 **Exam History** — Semester-wise grade cards (SGPA, CGPA, subject GPAs and grades)
- 🏠 **Dashboard** — Overview of all academic data at a glance
- ⚙️ **Settings** — Theme toggle (light/dark), account info

---

## 🛠️ How It Works

The app acts as a companion client to the Contineo web portal. Instead of relying on a dedicated backend API (which doesn't exist), it uses **web scraping** techniques securely executed on the device:

1. **Authentication** — Logs into the Contineo portal using your credentials and retrieves a session cookie.
2. **Data Extraction** — Fetches the relevant HTML pages (Attendance, CIE Marks, Exam History) using the authenticated session.
3. **Parsing** — The HTML is parsed locally on your device to extract structured data.
4. **Presentation** — Extracted data is displayed in a clean, native mobile UI.

All credentials and data are handled securely on your device and are **not sent to any third-party servers**.

---

## 📥 Download App

You can find the compiled Android APK file here:  
[**Download BNMIT Companion APK**](./bnmit_companion/build/app/outputs/flutter-apk/app-release.apk)

*(For GitHub users: check the Releases section for pre-built APKs.)*

---

## 📋 Changelog

| Version | Description |
|---------|-------------|
| **v2.0** | Exam History rewrite (grade cards, no PDF), Dashboard, Marks screen, Shell nav, Auth improvements |
| **v1.0** | Initial release — Login, Attendance, CIE Marks, basic Exam History (PDF download) |
