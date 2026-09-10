import pandas as pd

# Load the dataset
df = pd.read_csv("../dataset/StudentPerformanceFactors.csv")

# First 5 rows
print("========== FIRST 5 ROWS ==========")
print(df.head())

# Dataset information
print("\n========== DATASET INFO ==========")
print(df.info())

# Number of rows and columns
print("\n========== SHAPE ==========")
print(df.shape)

# Column names
print("\n========== COLUMN NAMES ==========")
print(df.columns)

# Missing values
print("\n========== MISSING VALUES ==========")
print(df.isnull().sum())

# Basic statistics
print("\n========== STATISTICS ==========")
print(df.describe())