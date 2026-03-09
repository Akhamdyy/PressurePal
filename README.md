# 🩺 PressurePal (v3.3.1)

![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)
![Supabase](https://img.shields.io/badge/Supabase-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)
![Gemini](https://img.shields.io/badge/Google%20Gemini-8E75B2?style=for-the-badge&logo=google%20gemini&logoColor=white)
![Android](https://img.shields.io/badge/Android-3DDC84?style=for-the-badge&logo=android&logoColor=white)

**PressurePal** is a smart, zero-friction blood pressure tracking application designed specifically for seniors and hypertensive patients. It removes the barrier of typing by allowing users to log their vitals using their camera or their voice (with full Arabic support). 

It acts as a companion, offering AI-driven health insights, and acts as a guardian, automatically alerting family members during medical emergencies.

## ✨ Key Features

### 🎙️ Zero-Friction Logging
* **Voice Commander:** Speak your readings in natural language (e.g., "130 over 80 and pulse 70"). Fully optimized for **Egyptian Arabic** with extended patience timeouts.
* **Camera OCR:** Point your phone at your physical Blood Pressure monitor. Google ML Kit extracts the Systolic, Diastolic, and Pulse automatically.
* **Manual Entry:** Simple, large-number keypad entry for traditional logging.

### 🤖 AI Doctor (Powered by Gemini)
* A built-in AI health assistant powered by Google's **Gemini Flash**.
* **Context-Aware:** The AI securely reads the user's recent BP history before answering, providing personalized lifestyle and dietary advice.

### 🛡️ Guardian Mode (Emergency Alerts)
* A life-saving safety net. If a user logs a critical reading (e.g., Sys >= 180 or Dia >= 110), the app automatically sends a **Silent Background SMS** to a designated emergency contact (son, daughter, or doctor) with the exact vitals.

### 📊 Analytics & Doctor Exports
* **Interactive Charts:** Visualize trends over 7 days, 30 days, or all time.
* **Advanced Stats:** Deep dive into Pulse Pressure and categorization (Normal, Elevated, Hypertension Stages).
* **Export Anywhere:** Generate professional **PDFs**, **CSV (Excel)** files for doctors, or quick text summaries for WhatsApp.

### 🔐 Security & Cloud
* **Cloud Sync:** Data is securely backed up in real-time using **Supabase**.
* **Biometric Lock:** Secure medical data behind native Fingerprint or FaceID authentication.

### 🌍 Localization & Accessibility
* Full support for **English** and **Arabic**.
* Configurable daily local notifications (Morning, Afternoon, Evening) to remind users to measure their vitals and take medication.

---

## 🛠️ Tech Stack

* **Framework:** Flutter (Dart)
* **Backend as a Service:** Supabase (PostgreSQL, Auth)
* **Artificial Intelligence:** `google_generative_ai` (Gemini Flash)
* **Machine Learning (Vision):** `google_mlkit_text_recognition`
* **Speech to Text:** `speech_to_text`
* **Background SMS:** `telephony`
* **Security:** `local_auth`, `flutter_secure_storage`
* **Local Notifications:** `flutter_local_notifications`

---

## 🚀 Getting Started

### Prerequisites
1. Flutter SDK (v3.10+)
2. A [Supabase](https://supabase.com/) Project
3. A [Google AI Studio](https://aistudio.google.com/) API Key

### Installation

1. **Clone the repository**
   ```bash
   git clone [https://github.com/yourusername/pressurepal.git](https://github.com/yourusername/pressurepal.git)
   cd pressurepal
Install Dependencies

Bash
flutter pub get
Environment Variables
Create a .env file in the root directory and add your keys:

Code snippet
SUPABASE_URL=[https://your-project-id.supabase.co](https://your-project-id.supabase.co)
SUPABASE_ANON_KEY=your-anon-key
GEMINI_API_KEY=your-gemini-api-key
Run the App

Bash
flutter run
(Note: Voice, Camera OCR, and Telephony require a physical Android device to test properly).

🛣️ Future Roadmap (Phase 9+)
The Digital Pharmacist: Advanced medication inventory tracking and refill alarms.

Smartwatch Integration: Passive logging via Google Health Connect.

Bluetooth Bridge: Direct BLE integration with Omron/Beurer monitors.

Developed with ❤️ by Ali Khaled for his father.


***

### 🌟 Next Steps
You can run `git init`, `git add .`, `git commit -m "v3.3.1: AI, OCR, Voice, and Guardian Mode"`, and push this up to GitHub! Let me know when you are ready to tackle Phase 9!
