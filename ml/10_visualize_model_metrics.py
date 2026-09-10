import pandas as pd
import numpy as np
# pyrefly: ignore [missing-import]
import matplotlib.pyplot as plt
import seaborn as sns
from sklearn.preprocessing import LabelEncoder
from sklearn.model_selection import train_test_split
from sklearn.ensemble import GradientBoostingRegressor
from sklearn.metrics import mean_absolute_error, mean_squared_error, r2_score

# Set overall plot aesthetics
sns.set_theme(style="whitegrid")
plt.rcParams["font.sans-serif"] = "DejaVu Sans"

# ==========================================
# Step 1 : Load & Preprocess Data
# ==========================================
df = pd.read_csv("../dataset/StudentPerformanceFactors.csv")

# Drop unnecessary columns
columns_to_drop = [
    "Student_ID", "Student_Name", "Enrollment_Number",
    "Admission_Date", "Data_Entry_Date", "Academic_Year",
    "Section", "Enrollment_Status"
]
df = df.drop(columns=columns_to_drop)

# Handle missing values
df["Teacher_Quality"] = df["Teacher_Quality"].fillna(df["Teacher_Quality"].mode()[0])
df["Parental_Education_Level"] = df["Parental_Education_Level"].fillna(df["Parental_Education_Level"].mode()[0])
df["Distance_from_Home"] = df["Distance_from_Home"].fillna(df["Distance_from_Home"].mode()[0])

# Average previous semester scores
def calculate_average(score_string):
    scores = list(map(int, score_string.split("|")))
    return sum(scores) / len(scores)

df["Previous_Scores_Semester_Wise"] = df["Previous_Scores_Semester_Wise"].apply(calculate_average)

# Encode categorical variables
label_encoder = LabelEncoder()
categorical_columns = df.select_dtypes(include=["object", "string"]).columns
for column in categorical_columns:
    df[column] = label_encoder.fit_transform(df[column])

# Features & Target
X = df.drop(["Exam_Score", "Cumulative_GPA"], axis=1)
y = df["Exam_Score"]

# Train/Test Split
X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.20, random_state=42
)

# ==========================================
# Step 2 : Train Model & Evaluate
# ==========================================
model = GradientBoostingRegressor(
    n_estimators=100,
    learning_rate=0.1,
    max_depth=3,
    random_state=42
)
model.fit(X_train, y_train)
y_pred = model.predict(X_test)

# Calculate metrics
mae = mean_absolute_error(y_test, y_pred)
mse = mean_squared_error(y_test, y_pred)
rmse = float(np.sqrt(mse))
r2 = r2_score(y_test, y_pred)

residuals = y_test - y_pred

# ==========================================
# Step 3 : Generate 4-Panel Visualization
# ==========================================
fig, axes = plt.subplots(2, 2, figsize=(14, 10))
fig.suptitle("EduPredict AI - Model Evaluation & Performance Metrics", fontsize=16, fontweight="bold")

# --- Graph 1: Actual vs Predicted ---
ax1 = axes[0, 0]
ax1.scatter(y_test, y_pred, alpha=0.4, color="#2b5c8f", edgecolor="none")
min_val = min(y_test.min(), y_pred.min())
max_val = max(y_test.max(), y_pred.max())
ax1.plot([min_val, max_val], [min_val, max_val], color="#e74c3c", linestyle="--", linewidth=2, label="Ideal Prediction (y = x)")
ax1.set_title(f"Actual vs. Predicted Scores (R² = {r2:.3f})", fontsize=12, fontweight="bold")
ax1.set_xlabel("Actual Exam Score")
ax1.set_ylabel("Predicted Exam Score")
ax1.legend()

# --- Graph 2: Residuals (Error Distribution) ---
ax2 = axes[0, 1]
sns.histplot(residuals, kde=True, ax=ax2, color="#27ae60", bins=30)
ax2.axvline(0, color="#e74c3c", linestyle="--", linewidth=2)
ax2.set_title(f"Residuals / Error Distribution (MAE = {mae:.2f})", fontsize=12, fontweight="bold")
ax2.set_xlabel("Error (Actual - Predicted)")
ax2.set_ylabel("Frequency")

# --- Graph 3: Top 10 Feature Importance ---
ax3 = axes[1, 0]
feat_df = pd.DataFrame({
    "Feature": X.columns,
    "Importance": model.feature_importances_
}).sort_values(by="Importance", ascending=False).head(10)

sns.barplot(data=feat_df, x="Importance", y="Feature", hue="Feature", legend=False, ax=ax3, palette="Blues_r")
ax3.set_title("Top 10 Feature Importances", fontsize=12, fontweight="bold")
ax3.set_xlabel("Importance Score")
ax3.set_ylabel("Feature")

# --- Graph 4: Metrics Summary Bar Chart ---
ax4 = axes[1, 1]
metrics_names = ["R² Score (%)", "MAE (Points)", "RMSE (Points)"]
metrics_values = [r2 * 100, mae, rmse]
colors = ["#3498db", "#f39c12", "#e74c3c"]

bars = ax4.bar(metrics_names, metrics_values, color=colors, width=0.5)
ax4.set_title("Key Performance Metrics", fontsize=12, fontweight="bold")
ax4.set_ylabel("Value")

# Add text labels on top of bars
for bar in bars:
    height = bar.get_height()
    ax4.annotate(f"{height:.2f}",
                 xy=(bar.get_x() + bar.get_width() / 2, height),
                 xytext=(0, 4),
                 textcoords="offset points",
                 ha="center", va="bottom", fontweight="bold")

plt.tight_layout(rect=[0, 0.03, 1, 0.95])

# Save graph image
output_file = "model_evaluation_metrics.png"
plt.savefig(output_file, dpi=300)
print(f"Graph successfully saved as '{output_file}'!")

# Show plot window (if running in desktop/GUI environment)
plt.show()
