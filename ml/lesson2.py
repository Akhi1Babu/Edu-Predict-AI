import pandas as pd

# Load dataset
df = pd.read_csv("../dataset/StudentPerformanceFactors.csv")

print("Original Shape:", df.shape)

# Remove unnecessary columns
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

print("New Shape:", df.shape)

print("\nRemaining Columns:\n")
print(df.columns)
print(df.isnull().sum())
# Fill missing categorical values using Mode

df["Teacher_Quality"] = df["Teacher_Quality"].fillna(
    df["Teacher_Quality"].mode()[0]
)

df["Parental_Education_Level"] = df["Parental_Education_Level"].fillna(
    df["Parental_Education_Level"].mode()[0]
)

df["Distance_from_Home"] = df["Distance_from_Home"].fillna(
    df["Distance_from_Home"].mode()[0]
)
print("\nMissing values AFTER filling:\n")
print(df.isnull().sum())