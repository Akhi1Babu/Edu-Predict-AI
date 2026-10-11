# 🎓 EduPredict AI

> **Bridging Machine Learning Predictive Analytics with Real-Time RAG Curriculum Interventions for Higher Education.**

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.100+-009688?logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com)
[![Scikit-Learn](https://img.shields.io/badge/scikit--learn-1.2+-F7931E?logo=scikit-learn&logoColor=white)](https://scikit-learn.org)
[![Firebase](https://img.shields.io/badge/Firebase-Firestore%20%26%20Auth-FFCA28?logo=firebase&logoColor=black)](https://firebase.google.com)
[![Render](https://img.shields.io/badge/Deployment-Render-46E3B7?logo=render&logoColor=white)](https://render.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

---

## 📌 Executive Summary

Traditional Learning Management Systems (LMS) diagnose student failure **post-mortem**—after midterms or final exams have concluded and backlogs have accumulated. Generic advice like *"study harder"* fails because it is neither timely nor actionable.

**EduPredict AI** closes this gap with an end-to-end academic intelligence platform:
1. **Predictive AI Core**: Uses a **Gradient Boosting Regressor** trained on 6,600+ multi-dimensional student profiles to forecast subject-wise exam scores (0–100%) weeks before finals.
2. **Pedagogical RAG Engine**: A **Retrieval-Augmented Generation** engine indexes course syllabi and teacher guidelines (PDF/text) to generate targeted, subject-specific remedial roadmaps instead of generic advice.
3. **Role-Segregated Ecosystem**:
   - **Student Portal**: Input study habits, view multi-subject score forecasts, track risk status, and access RAG study interventions.
   - **Teacher Portal**: Securely manage academic records (attendance, previous semester scores) and upload dynamic curriculum documents into the live RAG vector store.

---

## 🚀 Key Features

- **Multi-Subject Performance Forecasting**: Predicts exam outcomes across core subjects (e.g., Data Structures & Algorithms, Artificial Intelligence, Cloud Computing).
- **RAG-Powered Remedial Guidelines**: Dynamically matches weak performance areas against institutional course materials using TF-IDF semantic vector similarity.
- **Dynamic Curriculum Ingestion**: Teachers can upload syllabi or remedial guidelines as PDFs or raw text, instantly updating the RAG knowledge corpus in real-time.
- **Academic Governance**: Role-based access ensures only verified faculty can update official previous semester marks and attendance metrics.
- **Cross-Platform Mobile App**: Modern Flutter mobile experience with glassmorphism design, real-time Firestore sync, and rich analytics visualizations.
- **Production-Ready REST API**: High-performance FastAPI backend with automatic OpenAPI documentation and CORS support for web and mobile clients.

---

## 🏗️ Architecture & System Design

```
+-----------------------------------------------------------------------------------+
|                              FLUTTER MOBILE CLIENT                                |
|  - Role Authentication (Firebase Auth)                                            |
|  - Student Dashboard (Score Predictions, Lifestyle Sliders, RAG Roadmaps)         |
|  - Teacher Portal (Student Records, Previous Marks, Syllabus & PDF Uploads)       |
+----------------------------------------+------------------------------------------+
                                         | HTTPS / REST
                                         v
+-----------------------------------------------------------------------------------+
|                               FASTAPI BACKEND                                     |
|  - `/predict`: Multi-Subject Gradient Boosting ML Inference                       |
|  - `/upload_guidelines`: Dynamic Document Parser (PDF / Text Ingestion)           |
|  - `/recommendations`: Semantic Retrieval over Vectorized Knowledge Base         |
+--------------------+-------------------------------------+------------------------+
                     |                                     |
                     v                                     v
+------------------------------------+   +------------------------------------------+
|       MACHINE LEARNING CORE        |   |           RETRIEVAL RAG ENGINE           |
| - Gradient Boosting Regressor      |   | - Scikit-learn TF-IDF Vectorizer         |
| - 6,600+ Student Record Dataset    |   | - Cosine Similarity Semantic Ranking     |
| - R² ~0.76 | MAE ~1.46             |   | - Curated Subject Chunks + Live Additions|
+------------------------------------+   +------------------------------------------+
                     |                                     |
                     +-------------------+-----------------+
                                         |
                                         v
+-----------------------------------------------------------------------------------+
|                        FIREBASE FIRESTORE CLOUD DATABASE                          |
| - `users`: Role Profiles (Student / Teacher)                                      |
| - `student_records`: Multi-Subject Predictions, Official Marks & Habits           |
| - `curriculum_guidelines`: Live Indexed Subject Chunks & Teacher Uploads          |
+-----------------------------------------------------------------------------------+
```

---

## 📊 Dataset & Machine Learning

The ML model is trained on [`dataset/StudentPerformanceFactors.csv`](dataset/StudentPerformanceFactors.csv) containing **6,600+ student profiles** across 20 distinct academic and lifestyle variables:

| Feature Category | Inputs Tracked |
| :--- | :--- |
| **Academic** | Previous Semester Scores, Attendance %, Tutoring Sessions |
| **Study Habits** | Weekly Study Hours, Access to Resources, Teacher Quality |
| **Lifestyle & Well-being** | Sleep Hours, Physical Activity, Extracurricular Involvement |
| **Environmental** | Peer Influence, Family Income, Internet Access, Motivation Level |

### Model Benchmark & Evaluation

Multiple regression architectures were trained and benchmarked:

| Model | MAE | MSE | R² Score | Status |
| :--- | :--- | :--- | :--- | :--- |
| **Gradient Boosting Regressor** | **1.46** | **3.64** | **0.762** | **Production Selected** |
| Random Forest Regressor | 1.62 | 4.31 | 0.718 | Candidate |
| Linear Regression | 1.89 | 5.82 | 0.619 | Baseline |

> Model weights and scaler artifacts are saved at [`backend/student_prediction_model.pkl`](backend/student_prediction_model.pkl) and [`ml/student_prediction_model.pkl`](ml/student_prediction_model.pkl).

---

## 📂 Project Structure

```
edupredict-AI/
├── HACKATHON_PRESENTATION.md          # Complete hackathon pitch playbook & slide deck
├── README.md                          # Project documentation
├── requirements.txt                   # Root dependency manifest
│
├── dataset/
│   └── StudentPerformanceFactors.csv  # 6,600+ row clean student performance dataset
│
├── ml/
│   ├── 05_create_xy.py                # Feature extraction & matrix prep
│   ├── 05_train_test_split.py         # Stratified train/test splitting
│   ├── 06_linear_regression.py        # Baseline Linear Regression model
│   ├── 07_random_forest.py            # Random Forest benchmark
│   ├── 08_gradient_boosting.py        # Production Gradient Boosting training
│   ├── 09_test_saved_model.py         # Inference testing suite
│   ├── 10_visualize_model_metrics.py  # Model evaluation visualization generator
│   ├── encodedata.py                  # Categorical one-hot & label encoding
│   ├── model_evaluation_metrics.png   # Performance benchmark chart
│   └── student_prediction_model.pkl   # Serialized production model
│
├── backend/
│   ├── main.py                        # FastAPI application & route controllers
│   ├── rag_engine.py                  # TF-IDF RAG retrieval & PDF ingestion
│   ├── recommendation_engine.py       # Recommendation dispatcher
│   ├── student_prediction_model.pkl   # Model binary for deployment
│   ├── requirements.txt               # Backend dependencies
│   ├── Procfile                       # Production web process definition
│   └── render.yaml                    # Render Cloud deployment blueprint
│
└── flutter/
    └── edupredict_app/                # Cross-platform Flutter client
        ├── pubspec.yaml               # Flutter package configuration
        └── lib/
            ├── main.dart              # App entrypoint & theme definitions
            ├── screens/
            │   ├── auth_screen.dart                   # Role-based login & signup
            │   ├── student_home_screen.dart           # Student dashboard & habit inputs
            │   ├── teacher_home_screen.dart           # Teacher gradebook & syllabus upload
            │   └── prediction_dashboard_screen.dart   # Deep analytics & RAG roadmaps
            └── services/
                └── backend_service.dart               # HTTP client for FastAPI endpoints
```

---

## 🛠️ Quick Start & Local Setup

### 1. Prerequisites
- Python 3.10 or higher
- Flutter SDK 3.x+
- Git

### 2. Backend Setup
```bash
# Clone the repository
git clone https://github.com/Akhi1Babu/Edu-Predict-AI.git
cd Edu-Predict-AI

# Create and activate a virtual environment
python -m venv venv
# Windows:
.\venv\Scripts\activate
# macOS/Linux:
source venv/bin/activate

# Install backend dependencies
pip install -r backend/requirements.txt

# Start the FastAPI development server
uvicorn backend.main:app --host 0.0.0.0 --port 8000 --reload
```
API Documentation will be live at `http://localhost:8000/docs`.

### 3. Flutter App Setup
```bash
cd flutter/edupredict_app

# Fetch dependencies
flutter pub get

# Run on connected device or emulator
flutter run
```

---

## 📑 Presentation & Pitch Deck

For judges and stakeholders, see [`HACKATHON_PRESENTATION.md`](HACKATHON_PRESENTATION.md) for:
- 12-slide comprehensive presentation script
- System live demo walkthrough
- Competitive differentiator matrix
- Scalability & business model roadmap

---

## 👥 Contributors

- **Akhil Babu** ([@Akhi1Babu](https://github.com/Akhi1Babu))

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).
