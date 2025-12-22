# GyaanSetu 📚

**Offline-First Learning Platform for Students & Teachers**

GyaanSetu is a comprehensive Flutter-based educational app designed to work seamlessly both online and offline. It empowers teachers to share study materials and enables students to learn anytime, anywhere - even without internet connectivity.

---

## ✨ Features

### 👨‍🏫 For Teachers
- **Create & Manage Classes** - Generate unique class codes for students to join
- **Upload Study Materials** - Share PDFs, documents, and presentations
- **Student Progress Analytics** - Track quiz performance with detailed charts and statistics
- **Real-time Dashboard** - Monitor student engagement and activity

### 👨‍🎓 For Students
- **Join Classes** - Enter class code to access materials instantly
- **Offline Access** - Download materials and study without internet
- **AI-Powered Features**:
  - 📝 **Auto-generate Summaries** from PDFs
  - ❓ **AI Quiz Generation** with multiple-choice questions
  - 🧠 **Interactive Mind Maps** for visual learning
  - 💬 **AI Chatbot** to ask questions about your documents
  - 🎤 **Voice Features** - Text-to-Speech and Speech-to-Text for quizzes
  - 🌐 **Multilingual Support** - Content in English, Hindi, and Marathi
- **Personal PDF Library** - Upload your own PDFs (max 10MB)
- **Learning Streaks** - Track daily study habits with gamification
- **Smart Compression** - Saves device storage with file compression

---

## 🚀 Tech Stack

**Frontend:**
- Flutter 3.x with Dart
- Material Design 3 UI
- Provider for state management

**Backend & Services:**
- Firebase (Authentication, Firestore, Storage)
- Custom Python FastAPI server for AI models
- Google ML Kit (Translation, TTS, STT)

**AI/ML:**
- Llama 3.1 models (8B/70B) via server API
- Mixtral 8x7B for premium quality
- Offline RAG (Retrieval-Augmented Generation)
- BM25 search algorithm
- Optional local LLM support (Qwen 2.5)

**Key Packages:**
```yaml
- firebase_core & firebase_auth
- cloud_firestore
- provider
- syncfusion_flutter_pdf
- dio (networking)
- shared_preferences
- file_picker
- open_file
- archive (compression)
- fl_chart (analytics)
- flutter_tts & speech_to_text
- google_mlkit_translation
- connectivity_plus
```

---

## 📋 Prerequisites

- Flutter SDK (3.0 or higher)
- Dart SDK (3.0 or higher)
- Android Studio / VS Code with Flutter extensions
- Firebase account (for backend services)
- Android device/emulator or iOS device/simulator

---

## 🛠️ Installation & Setup

### 1️⃣ Clone the Repository
```bash
git clone https://github.com/yourusername/gyaansetu.git
cd gyaansetu
```

### 2️⃣ Install Dependencies
```bash
flutter pub get
```

### 3️⃣ Firebase Configuration
The app is pre-configured with Firebase credentials in `lib/config/firebase_config.dart`. 

**For production use, replace with your own Firebase project:**
1. Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
2. Enable Authentication (Email/Password)
3. Create a Firestore database
4. Update `lib/config/firebase_config.dart` with your credentials

### 4️⃣ Run the App
```bash
flutter run
```

That's it! The app will launch on your connected device/emulator.

---

## 🎯 Usage Guide

### Getting Started

**For Teachers:**
1. Register with email & password
2. Select "Teacher" role
3. Create a new class (auto-generates 6-digit code)
4. Share the class code with students
5. Upload study materials (PDFs, docs)
6. Monitor student progress in analytics dashboard

**For Students:**
1. Register with email & password
2. Select "Student" role
3. Join class using teacher's code
4. Download materials for offline access
5. Generate AI summaries & quizzes
6. Chat with AI about your documents
7. Build learning streaks!

---

## 🌟 Key Highlights

### Offline-First Architecture
- ✅ Works completely offline after initial setup
- ✅ Smart file compression (saves 30-50% storage)
- ✅ Local database with SharedPreferences
- ✅ Automatic sync when online

### AI Features (Online/Offline Hybrid)
- **Online Mode**: Uses powerful cloud AI models via API
  - Fast (2-3s): Llama 3.1 8B
  - Balanced (4-6s): Llama 3.1 70B  
  - Best (7-10s): Mixtral 8x7B
- **Offline Mode**: 
  - Rule-based summary generation
  - BM25 RAG for document Q&A
  - Optional 678MB local LLM download

### Gamification
- 🔥 Daily learning streaks
- 🏆 Milestone celebrations (3, 7, 14, 30, 100 days)
- 📊 Progress tracking
- ⭐ Quiz performance analytics

---

## 📱 Screenshots

*(App is fully functional - screenshots can be added from actual device)*

---

## 🏗️ Project Structure

```
lib/
├── config/
│   └── firebase_config.dart          # Firebase setup
├── models/
│   └── models.dart                    # Data models
├── providers/
│   └── auth_provider.dart             # Authentication state
├── screens/
│   ├── home_screen.dart
│   ├── login_screen.dart
│   ├── student/                       # Student-specific screens
│   │   ├── student_dashboard.dart
│   │   ├── summary_quiz_screen.dart
│   │   ├── chatbot_screen.dart
│   │   └── ...
│   └── teacher/                       # Teacher-specific screens
│       ├── teacher_dashboard.dart
│       └── ...
├── services/
│   ├── offline_db.dart                # Local storage
│   ├── summary_generator.dart         # PDF processing
│   ├── server_api_service.dart        # AI API calls
│   ├── offline_rag_service.dart       # Offline Q&A
│   ├── tts_service.dart               # Text-to-Speech
│   ├── stt_service.dart               # Speech-to-Text
│   ├── translation_service.dart       # Multilingual
│   └── ...
└── widgets/
    ├── streak_widget.dart             # Learning streaks
    └── student_progress_widget.dart   # Analytics charts
```

---

## 🔐 Security Note

**Important:** The Firebase API keys in this repository are for demo purposes only. For production deployment:
1. Create your own Firebase project
2. Enable appropriate security rules
3. Use environment variables for sensitive data
4. Implement proper authentication flows

---

## 🤝 Contributing

Contributions are welcome! This is an educational project built for a hackathon.

**To contribute:**
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

---

## 📄 License

This project is open source and available under the MIT License.

---

## 👨‍💻 Developer

Built with ❤️ for educational purposes

**Contact:** [Your Email/GitHub Profile]

---

## 🙏 Acknowledgments

- Firebase for backend infrastructure
- Anthropic Claude for AI capabilities
- Groq for fast LLM inference
- Google ML Kit for on-device ML features
- Flutter community for amazing packages

---

## 📝 Notes

- First-time setup requires internet for Firebase authentication
- AI features work best with internet, but basic functionality remains offline
- File size limit: 10MB per PDF for optimal processing
- Recommended: Download AI model (678MB) for enhanced offline features

---

**Happy Learning! 🎓📚**
