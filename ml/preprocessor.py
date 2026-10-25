"""
EduPredict AI - Canonical Preprocessing Pipeline
Provides consistent preprocessing across Training, Inference API, and Evaluation.
"""

import os
import joblib
import pandas as pd
import numpy as np

# Canonical feature list (24 features, Cumulative_GPA strictly excluded)
FEATURE_ORDER = [
    "Grade_Level",
    "Current_Semester",
    "Age",
    "Previous_Scores_Semester_Wise",
    "Class_Participation_Score",
    "Hours_Studied",
    "Attendance",
    "Parental_Involvement",
    "Access_to_Resources",
    "Extracurricular_Activities",
    "Sleep_Hours",
    "Previous_Scores",
    "Motivation_Level",
    "Internet_Access",
    "Tutoring_Sessions",
    "Family_Income",
    "Teacher_Quality",
    "School_Type",
    "Peer_Influence",
    "Physical_Activity",
    "Learning_Disabilities",
    "Parental_Education_Level",
    "Distance_from_Home",
    "Gender",
]

# Exact categorical mappings fitted during model training (alphabetical LabelEncoder order)
# Also supports integer codes and maps both string and integer inputs into canonical training codes.
CATEGORICAL_MAPPINGS = {
    "Parental_Involvement": {
        # Raw strings
        "High": 0, "Low": 1, "Medium": 2,
        # API schema integer codes (0=Low, 1=Med, 2=High) mapped to training codes:
        # If passed as training codes: 0, 1, 2
    },
    "Access_to_Resources": {
        "High": 0, "Low": 1, "Medium": 2,
    },
    "Extracurricular_Activities": {
        "No": 0, "Yes": 1,
        0: 0, 1: 1
    },
    "Motivation_Level": {
        "High": 0, "Low": 1, "Medium": 2,
    },
    "Internet_Access": {
        "No": 0, "Yes": 1,
        0: 0, 1: 1
    },
    "Family_Income": {
        "High": 0, "Low": 1, "Medium": 2,
    },
    "Teacher_Quality": {
        "High": 0, "Low": 1, "Medium": 2,
    },
    "School_Type": {
        "Private": 0, "Public": 1,
    },
    "Peer_Influence": {
        "Negative": 0, "Neutral": 1, "Positive": 2,
    },
    "Learning_Disabilities": {
        "No": 0, "Yes": 1,
        0: 0, 1: 1
    },
    "Parental_Education_Level": {
        "College": 0, "High School": 1, "Postgraduate": 2,
    },
    "Distance_from_Home": {
        "Far": 0, "Moderate": 1, "Near": 2,
    },
    "Gender": {
        "Female": 0, "Male": 1,
        0: 0, 1: 1
    },
}

# Mapping between API ordinal schema conventions (e.g. 0=Low, 1=Med, 2=High) and Model Training codes (0=High, 1=Low, 2=Med)
API_ORDINAL_TO_TRAINING_CODE = {
    "Parental_Involvement": {0: 1, 1: 2, 2: 0},     # Low -> 1, Med -> 2, High -> 0
    "Access_to_Resources":  {0: 1, 1: 2, 2: 0},
    "Motivation_Level":     {0: 1, 1: 2, 2: 0},
    "Family_Income":        {0: 1, 1: 2, 2: 0},
    "Teacher_Quality":      {0: 1, 1: 2, 2: 0},
    "School_Type":          {0: 1, 1: 0},            # API doc: 0=Public, 1=Private -> Model: Public=1, Private=0
    "Parental_Education_Level": {0: 1, 1: 0, 2: 2}, # High School -> 1, College -> 0, Postgrad -> 2
    "Distance_from_Home":   {0: 2, 1: 1, 2: 0},     # Near -> 2, Moderate -> 1, Far -> 0
    "Peer_Influence":       {0: 0, 1: 1, 2: 2},     # Neg=0, Neutral=1, Pos=2
}

class EduPredictPreprocessor:
    """
    Robust preprocessor handling both DataFrame training sets and single API dictionary payloads.
    Normalizes categorical encoding and Class_Participation_Score scales.
    """
    def __init__(self):
        self.feature_order = FEATURE_ORDER
        self.categorical_mappings = CATEGORICAL_MAPPINGS
        self.ordinal_mapping = API_ORDINAL_TO_TRAINING_CODE

    def _normalize_participation(self, val):
        """Converts participation score from 0-10 scale to 0-100 scale if needed."""
        try:
            v = float(val)
            # If provided on a 0-10 scale (common in UI forms), scale to 0-100
            if v <= 10.0 and v > 0:
                return v * 10.0
            return v
        except (ValueError, TypeError):
            return 75.0

    def _parse_semester_scores(self, val):
        """Calculates average if pipe-delimited string is passed (e.g., '87|98|98|94')."""
        if isinstance(val, str) and "|" in val:
            scores = list(map(int, val.split("|")))
            return sum(scores) / len(scores)
        try:
            return float(val)
        except (ValueError, TypeError):
            return 75.0

    def transform_single(self, input_dict: dict, from_api_codes: bool = True) -> np.ndarray:
        """
        Transforms a single input dictionary into a 2D numpy array [1, 24] with strict ordering.
        If from_api_codes is True, maps integer schema codes (0=Low, 1=Med, 2=High) to model training codes.
        """
        row = []
        for feat in self.feature_order:
            val = input_dict.get(feat)
            
            # Feature-specific adjustments
            if feat == "Previous_Scores_Semester_Wise":
                val = self._parse_semester_scores(val)
            elif feat == "Class_Participation_Score":
                val = self._normalize_participation(val)
            elif feat in self.categorical_mappings:
                mapping = self.categorical_mappings[feat]
                if isinstance(val, str):
                    val = mapping.get(val, 1) # default to middle/mode
                elif from_api_codes and feat in self.ordinal_mapping:
                    val = self.ordinal_mapping[feat].get(val, val)
            
            row.append(float(val) if val is not None else 0.0)
            
        return np.array([row], dtype=np.float32)

    def transform_dataframe(self, df: pd.DataFrame) -> pd.DataFrame:
        """Transforms a DataFrame containing raw strings/pipe-delimited values into X matrix."""
        df_clean = df.copy()
        
        # Drop identifiers and GPA if present
        cols_to_drop = [
            "Student_ID", "Student_Name", "Enrollment_Number",
            "Admission_Date", "Data_Entry_Date", "Academic_Year",
            "Section", "Enrollment_Status", "Cumulative_GPA", "Exam_Score"
        ]
        existing_drop = [c for c in cols_to_drop if c in df_clean.columns]
        df_clean = df_clean.drop(columns=existing_drop)
        
        # Impute missing values
        for col, default_val in [("Teacher_Quality", "Medium"), ("Parental_Education_Level", "High School"), ("Distance_from_Home", "Near")]:
            if col in df_clean.columns:
                df_clean[col] = df_clean[col].fillna(default_val)
                
        # Parse semester scores
        if "Previous_Scores_Semester_Wise" in df_clean.columns:
            df_clean["Previous_Scores_Semester_Wise"] = df_clean["Previous_Scores_Semester_Wise"].apply(self._parse_semester_scores)
            
        # Map categorical columns
        for col, mapping in self.categorical_mappings.items():
            if col in df_clean.columns:
                df_clean[col] = df_clean[col].map(mapping).fillna(1).astype(int)
                
        return df_clean[self.feature_order]

# Persist utility
def save_preprocessor(filepath: str = "ml/preprocessor.pkl"):
    preprocessor = EduPredictPreprocessor()
    joblib.dump(preprocessor, filepath)
    print(f"Preprocessor saved to {filepath}")
    return preprocessor

if __name__ == "__main__":
    prep = save_preprocessor("ml/preprocessor.pkl")
    save_preprocessor("backend/preprocessor.pkl")
