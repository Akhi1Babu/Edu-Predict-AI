import joblib

# Load the saved model
model = joblib.load("student_prediction_model.pkl")

print("Model Loaded Successfully")
student = [[
    3,      # Grade_Level
    6,      # Current_Semester
    21,     # Age
    65,     # Previous_Scores_Semester_Wise
    8,      # Class_Participation_Score
    15,     # Hours_Studied
    80,     # Attendance
    2,      # Parental_Involvement
    2,      # Access_to_Resources
    1,      # Extracurricular_Activities
    7,      # Sleep_Hours
    72,     # Previous_Scores
    2,      # Motivation_Level
    0,      # Internet_Access
    2,      # Tutoring_Sessions
    1,      # Family_Income
    2,      # Teacher_Quality
    0,      # School_Type
    1,      # Peer_Influence
    3,      # Physical_Activity
    0,      # Learning_Disabilities
    2,      # Parental_Education_Level
    1,      # Distance_from_Home
    1       # Gender
]]

prediction = model.predict(student)

print("Predicted Exam Score:", prediction[0])