import pandas as pd
import numpy as np
import xgboost as xgb
from sklearn.metrics import precision_score, recall_score, f1_score
import json
import os

# 1. Data Preparation & Identity Proxy
print("Loading dataset...")
df = pd.read_csv('/workspaces/sentinel-v1/sentinel_root/upi_transactions_2024.csv')

df['timestamp'] = pd.to_datetime(df['timestamp'])
df.sort_values('timestamp', inplace=True)

# Create high-fidelity proxy_account_id
df['proxy_account_id'] = (df['sender_state'].astype(str) + '_' + 
                          df['sender_bank'].astype(str) + '_' + 
                          df['sender_age_group'].astype(str) + '_' + 
                          df['device_type'].astype(str))

print("Feature Engineering...")
df['amount'] = df['amount (INR)']

# 2. Feature Engineering (120s Rolling Sieve)

# Backup original chronological order
df['original_order'] = np.arange(len(df))

# Sort by account and then time to make groups contiguous
df.sort_values(['proxy_account_id', 'timestamp'], inplace=True)

# Calculate inter-arrival time per proxy account using simple diff
df['time_delta_sec'] = df.groupby('proxy_account_id')['timestamp'].diff().dt.total_seconds()

# Set index to timestamp for rolling window
df.set_index('timestamp', inplace=True)

# Group with sort=False means it respects the order we just set
grouped = df.groupby('proxy_account_id', sort=False)

# txn_count_120s
df['txn_count_120s'] = grouped['amount'].rolling('120s').count().values

# ptr_ratio: rolling sum / 100000.0, capped at 1.0
rolling_sum = grouped['amount'].rolling('120s').sum().values
df['ptr_ratio'] = np.clip(rolling_sum / 100000.0, a_min=None, a_max=1.0)

# jitter_sigma: standard deviation of time delta in 120s window. Fill NaN with 0.0
df['jitter_sigma'] = grouped['time_delta_sec'].rolling('120s').std().values
df['jitter_sigma'] = df['jitter_sigma'].fillna(0.0)

df.reset_index(inplace=True)

# Important: restore strict chronological order
df.sort_values('original_order', inplace=True)
df.drop(columns=['original_order'], inplace=True)

# 3. Temporal Split (No Data Leakage)
print("Performing Temporal Split...")
n = len(df)
train_end = int(0.7 * n)
val_end = int(0.85 * n)

train = df.iloc[:train_end]
val = df.iloc[train_end:val_end]
test = df.iloc[val_end:]

features = ['amount', 'txn_count_120s', 'ptr_ratio', 'jitter_sigma']
target = 'fraud_flag'

X_train, y_train = train[features], train[target]
X_val, y_val = val[features], val[target]
X_test, y_test = test[features], test[target]

print(f"Train size: {len(X_train)}, Val size: {len(X_val)}, Test size: {len(X_test)}")

# 4. XGBoost Training (Imbalance Handled)
print("Training XGBoost Model...")
neg = (y_train == 0).sum()
pos = (y_train == 1).sum()
scale_pos_weight = neg / pos if pos > 0 else 1.0
print(f"Class imbalance (Neg/Pos): {scale_pos_weight:.2f}")

model = xgb.XGBClassifier(
    objective='binary:logistic',
    scale_pos_weight=scale_pos_weight,
    early_stopping_rounds=10,
    eval_metric='logloss',
    n_estimators=100
)

model.fit(
    X_train, y_train,
    eval_set=[(X_val, y_val)],
    verbose=True
)

# 5. Export & Verification
print("Exporting Verification...")
y_pred = model.predict(X_test)
precision = precision_score(y_test, y_pred)
recall = recall_score(y_test, y_pred)
f1 = f1_score(y_test, y_pred)

importances = model.get_booster().get_score(importance_type='weight')

report = f"""--- Test Set Metrics ---
Precision: {precision:.4f}
Recall: {recall:.4f}
F1-Score: {f1:.4f}

--- XGBoost Feature Importances (Weight) ---
"""
for feat, imp in importances.items():
    report += f"{feat}: {imp}\n"

with open('/workspaces/sentinel-v1/sentinel_root/ml_pipeline/test_report.txt', 'w') as f:
    f.write(report)

print("Saving model exported mapping to JSON...")
model_path = '/workspaces/sentinel-v1/sentinel_root/core_engine/xgboost_model.json'
model.save_model(model_path)
print(f"Model saved to {model_path}.")
print(f"F1-Score: {f1:.4f}")
