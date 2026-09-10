# Import Libraries
import pandas as pd
from sklearn.preprocessing import LabelEncoder
from sklearn.model_selection import train_test_split

# ==========================================
# Step 1 : Load Dataset
# ==========================================

df = pd.read_csv("../dataset/StudentPerformanceFactors.csv")

print("Original Dataset Shape:", df.shape)

# ==========================================
# Step 2 : Remove Unnecessary Columns
# ==========================================

columns_to_drop = [
    "Student_ID",
    "Student_Name",
    "Enrollment_Number",
    "Admission_Date",
    "Data_Entry_Date",
    "Academic_Year",
    "Section",
    "Enrollment_Status"
]

df = df.drop(columns=columns_to_drop)

print("Dataset Shape After Removing Columns:", df.shape)

# ==========================================
# Step 3 : Handle Missing Values
# ==========================================

df["Teacher_Quality"] = df["Teacher_Quality"].fillna(
    df["Teacher_Quality"].mode()[0]
)

df["Parental_Education_Level"] = df["Parental_Education_Level"].fillna(
    df["Parental_Education_Level"].mode()[0]
)

df["Distance_from_Home"] = df["Distance_from_Home"].fillna(
    df["Distance_from_Home"].mode()[0]
)

print("\nMissing Values After Filling:")
print(df.isnull().sum())

# ==========================================
# Step 4 : Convert Previous Semester Scores
# ==========================================

def calculate_average(score_string):
    scores = list(map(int, score_string.split("|")))
    return sum(scores) / len(scores)

df["Previous_Scores_Semester_Wise"] = (
    df["Previous_Scores_Semester_Wise"]
    .apply(calculate_average)
)

# ==========================================
# Step 5 : Encode Categorical Columns
# ==========================================

label_encoder = LabelEncoder()

categorical_columns = df.select_dtypes(
    include=["object", "string"]
).columns

print("\nCategorical Columns:")
print(categorical_columns)

for column in categorical_columns:
    df[column] = label_encoder.fit_transform(df[column])

print("\nDataset Information After Encoding")
print(df.info())

# ==========================================
# Step 6 : Create Features (X) and Target (y)
# ==========================================

X = df.drop("Exam_Score", axis=1)
y = df["Exam_Score"]

print("\nFeatures Shape :", X.shape)
print("Target Shape   :", y.shape)

print("\nFirst 5 Rows of Features")
print(X.head())

print("\nFirst 5 Target Values")
print(y.head())