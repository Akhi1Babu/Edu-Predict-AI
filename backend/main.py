# pyrefly: ignore [missing-import]
import os
import joblib
import numpy as np
# pyrefly: ignore [missing-import]
from fastapi import FastAPI, HTTPException
# pyrefly: ignore [missing-import]
from fastapi.middleware.cors import CORSMiddleware
# pyrefly: ignore [missing-import]
from pydantic import BaseModel, Field
from recommendation_engine import generate_recommendations

# Firebase Admin Imports
try:
    import firebase_admin
    from firebase_admin import credentials, firestore
    FIREBASE_AVAILABLE = True
except ImportError:
    FIREBASE_AVAILABLE = False

app = FastAPI(
    title="EduPredict AI - Student Performance Backend API",
    description="Machine Learning API for predicting student exam scores and offering recommendations.",
    version="1.0.0"
)

# Enable CORS for Flutter & Web Frontends
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Load Trained Model
MODEL_PATH = os.path.join(os.path.dirname(__file__), "student_prediction_model.pkl")

try:
    model = joblib.load(MODEL_PATH)
    print("Model loaded successfully in FastAPI Backend.")
except Exception as e:
    model = None
    print(f"Error loading model from {MODEL_PATH}: {e}")

# Initialize Firebase Admin SDK
db = None
SERVICE_KEY_PATH = os.path.join(os.path.dirname(__file__), "serviceAccountKey.json")
FIREBASE_ENV_JSON = os.getenv("FIREBASE_SERVICE_ACCOUNT_JSON")

if FIREBASE_AVAILABLE:
    try:
        if FIREBASE_ENV_JSON:
            import json
            cred_dict = json.loads(FIREBASE_ENV_JSON)
            cred = credentials.Certificate(cred_dict)
            firebase_admin.initialize_app(cred)
            db = firestore.client()
            print("Firebase Admin initialized from ENV JSON successfully.")
        elif os.path.exists(SERVICE_KEY_PATH):
            cred = credentials.Certificate(SERVICE_KEY_PATH)
            firebase_admin.initialize_app(cred)
            db = firestore.client()
            print("Firebase Admin initialized from local file successfully.")
    except Exception as e:
        print(f"Error initializing Firebase Admin: {e}")

# Define Pydantic Schema for Direct Prediction API
class StudentInput(BaseModel):
    Subject: str = Field("Data Structures & Algorithms", description="Subject name (DSA, AI, Cloud)")
    Grade_Level: int = Field(3, ge=1, le=12, description="Student grade level (1-12)")
    Current_Semester: int = Field(6, ge=1, le=8, description="Current semester (1-8)")
    Age: int = Field(20, ge=10, le=40, description="Age of student")
    Previous_Scores_Semester_Wise: float = Field(75.0, ge=0.0, le=100.0, description="Average score in previous semester")
    Class_Participation_Score: float = Field(8.0, ge=0.0, le=10.0, description="Class participation score (0-10)")
    Hours_Studied: float = Field(15.0, ge=0.0, le=100.0, description="Hours studied per week")
    Attendance: float = Field(85.0, ge=0.0, le=100.0, description="Attendance percentage (0-100%)")
    Parental_Involvement: int = Field(2, ge=0, le=3, description="Parental involvement level (0=Low, 1=Med, 2=High)")
    Access_to_Resources: int = Field(2, ge=0, le=3, description="Resource access level (0=Low, 1=Med, 2=High)")
    Extracurricular_Activities: int = Field(1, ge=0, le=1, description="Extracurricular participation (0=No, 1=Yes)")
    Sleep_Hours: float = Field(7.0, ge=0.0, le=24.0, description="Average sleep hours per night")
    Previous_Scores: float = Field(75.0, ge=0.0, le=100.0, description="Overall previous score")
    Motivation_Level: int = Field(2, ge=0, le=3, description="Motivation level (0=Low, 1=Med, 2=High)")
    Internet_Access: int = Field(1, ge=0, le=1, description="Internet access (0=No, 1=Yes)")
    Tutoring_Sessions: int = Field(1, ge=0, le=10, description="Tutoring sessions per month")
    Family_Income: int = Field(1, ge=0, le=3, description="Family income category")
    Teacher_Quality: int = Field(2, ge=0, le=3, description="Teacher quality index")
    School_Type: int = Field(0, ge=0, le=1, description="School type (0=Public, 1=Private)")
    Peer_Influence: int = Field(1, ge=0, le=2, description="Peer influence score")
    Physical_Activity: float = Field(3.0, ge=0.0, le=20.0, description="Physical activity hours per week")
    Learning_Disabilities: int = Field(0, ge=0, le=1, description="Learning disability status (0=No, 1=Yes)")
    Parental_Education_Level: int = Field(2, ge=0, le=4, description="Parental education level index")
    Distance_from_Home: int = Field(1, ge=0, le=3, description="Distance from home category")
    Gender: int = Field(1, ge=0, le=1, description="Gender (0=Female, 1=Male)")


FEATURE_ORDER = [
    "Grade_Level", "Current_Semester", "Age", "Previous_Scores_Semester_Wise",
    "Class_Participation_Score", "Hours_Studied", "Attendance", "Parental_Involvement",
    "Access_to_Resources", "Extracurricular_Activities", "Sleep_Hours", "Previous_Scores",
    "Motivation_Level", "Internet_Access", "Tutoring_Sessions", "Family_Income",
    "Teacher_Quality", "School_Type", "Peer_Influence", "Physical_Activity",
    "Learning_Disabilities", "Parental_Education_Level", "Distance_from_Home", "Gender"
]

DEFAULT_FEATURE_VALUES = {
    "Grade_Level": 3, "Current_Semester": 6, "Age": 20, "Previous_Scores_Semester_Wise": 75.0,
    "Class_Participation_Score": 8.0, "Hours_Studied": 15.0, "Attendance": 85.0, "Parental_Involvement": 2,
    "Access_to_Resources": 2, "Extracurricular_Activities": 1, "Sleep_Hours": 7.0, "Previous_Scores": 75.0,
    "Motivation_Level": 2, "Internet_Access": 1, "Tutoring_Sessions": 1, "Family_Income": 1,
    "Teacher_Quality": 2, "School_Type": 0, "Peer_Influence": 1, "Physical_Activity": 3.0,
    "Learning_Disabilities": 0, "Parental_Education_Level": 2, "Distance_from_Home": 1, "Gender": 1
}

SUBJECT_LIST = ["Data Structures & Algorithms", "Artificial Intelligence", "Cloud Computing"]


@app.get("/")
def root():
    return {
        "status": "online",
        "message": "EduPredict AI Backend API Running Successfully",
        "model_loaded": model is not None,
        "firebase_connected": db is not None,
        "supported_subjects": SUBJECT_LIST
    }


@app.post("/predict")
def predict_exam_score(student: StudentInput):
    if model is None:
        raise HTTPException(status_code=500, detail="ML Model is not loaded on server.")
    
    student_dict = student.model_dump()
    subject = student_dict.get("Subject", "Data Structures & Algorithms")
    feature_vector = np.array([[student_dict[feature] for feature in FEATURE_ORDER]])
    
    predicted_score = float(model.predict(feature_vector)[0])
    predicted_score = round(max(0.0, min(100.0, predicted_score)), 2)
    
    recommendations = generate_recommendations(student_dict, predicted_score, subject=subject)
    
    return {
        "subject": subject,
        "predicted_exam_score": predicted_score,
        "recommendations": recommendations,
        "student_summary": {
            "attendance": student_dict["Attendance"],
            "hours_studied": student_dict["Hours_Studied"],
            "previous_semester_score": student_dict["Previous_Scores_Semester_Wise"]
        }
    }


@app.post("/sync-prediction/{student_id}")
def sync_student_prediction(student_id: str):
    if model is None:
        raise HTTPException(status_code=500, detail="ML Model is not loaded.")
    if db is None:
        raise HTTPException(status_code=500, detail="Firebase Admin is not connected.")
        
    doc_ref = db.collection("student_records").document(student_id)
    doc = doc_ref.get()
    
    if not doc.exists:
        raise HTTPException(status_code=404, detail=f"Student record '{student_id}' not found in Firestore.")
        
    data = doc.to_dict()
    student_inputs = data.get("studentInputs", {})
    teacher_inputs = data.get("teacherInputs", {})
    subject_records = data.get("subjectRecords", {})

    predictions = {}

    for subj in SUBJECT_LIST:
        subj_data = subject_records.get(subj, {})
        subj_student_inputs = subj_data.get("studentInputs", student_inputs)
        subj_teacher_inputs = subj_data.get("teacherInputs", teacher_inputs)

        full_data = {**DEFAULT_FEATURE_VALUES, **subj_student_inputs, **subj_teacher_inputs}
        
        feature_vector = np.array([[full_data[feature] for feature in FEATURE_ORDER]])
        score = round(max(0.0, min(100.0, float(model.predict(feature_vector)[0]))), 2)
        recs = generate_recommendations(full_data, score, subject=subj)

        predictions[subj] = {
            "predictedExamScore": score,
            "recommendations": recs,
            "attendance": full_data.get("Attendance", 85.0),
            "hoursStudied": full_data.get("Hours_Studied", 15.0),
            "previousScore": full_data.get("Previous_Scores_Semester_Wise", 75.0)
        }
    
    # Backwards compatibility primary prediction (using DSA)
    primary_pred = predictions.get("Data Structures & Algorithms", list(predictions.values())[0])

    prediction_payload = {
        "predictedExamScore": primary_pred["predictedExamScore"],
        "recommendations": primary_pred["recommendations"],
        "subjectPredictions": predictions,
        "lastUpdated": firestore.SERVER_TIMESTAMP
    }
    
    doc_ref.update({"prediction": prediction_payload})
    
    return {
        "status": "success",
        "student_id": student_id,
        "prediction": prediction_payload
    }