# BNMIT Companion App v1.0

BNMIT Companion is a Flutter-based mobile application designed to provide a seamless and modern interface for BNMIT students to access their Contineo portal data.

## 📱 App Details

- **Framework:** Flutter (Dart)
- **Features:**
  - Secure Login with Contineo Portal credentials
  - View real-time Attendance status
  - Access Internal Assessment (CIE) Marks
  - View Class Timetable
  - Modern, responsive, and student-friendly user interface

## 🛠️ How It Works

The app acts as a companion client to the Contineo web portal. Instead of relying on a dedicated backend API (which doesn't exist), it uses **web scraping** techniques securely executed on the device:
1. **Authentication:** The app logs into the Contineo portal using your credentials and retrieves a session cookie.
2. **Data Extraction:** It fetches the relevant HTML pages (e.g., Attendance, CIE Marks, Timetable) using the authenticated session.
3. **Parsing:** The HTML is parsed locally on your device to extract structured data.
4. **Presentation:** The extracted data is displayed in a clean, native mobile UI.

All credentials and data are handled securely on your device and are not sent to any third-party servers.


## 📥 Download App

You can find the compiled Android APK file here:
[**Download BNMIT Companion APK**](./bnmit_companion/build/app/outputs/flutter-apk/app-release.apk)

*(Note: For GitHub users, ensure you navigate to the local build directory or check the Releases section if available.)*
