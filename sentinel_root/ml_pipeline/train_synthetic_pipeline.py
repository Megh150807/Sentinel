import pandas as pd
import numpy as np
import xgboost as xgb
from sklearn.metrics import classification_report, f1_score
import json
import warnings
warnings.filterwarnings('ignore')

print("1. Data Ingestion & Proxy IDs")
df = pd.read_csv('/workspaces/sentinel-v1/sentinel_root/upi_transactions_2024.csv')

df['timestamp'] = pd.to_datetime(df['timestamp'])
df.sort_values('timestamp', inplace=True)

df['proxy_account_id'] = (df['sender_state'].astype(str) + '_' + 
                          df['sender_bank'].astype(str) + '_' + 
                          df['sender_age_group'].astype(str) + '_' + 
                          df['device_type'].astype(str))

print("2. The Infection Phase (Data Poisoning)")
np.random.seed(42)
unique_proxies = df['proxy_account_id'].dropna().unique()
num_mule_proxies = max(1, int(0.05 * len(unique_proxies)))
mule_proxies = np.random.choice(unique_proxies, size=num_mule_proxies, replace=False)

df['fraud_flag'] = 0
mule_mask = df['proxy_account_id'].isin(mule_proxies)

pristine_df = df[~mule_mask].copy()
infected_base_df = df[mule_mask].copy()

# Inject High Volume: duplicate rows 20 times for each proxy to ensure 20 transactions
infected_expanded = infected_base_df.loc[infected_base_df.index.repeat(20)].copy()

# Inject Bot Jitter: space out timestamps by exactly 5ms
cumulative_ms = infected_expanded.groupby(infected_expanded.index).cumcount() * 5
infected_expanded['timestamp'] = infected_expanded['timestamp'] + pd.to_timedelta(cumulative_ms, unit='ms')

# Inject PTR: Adjust amount so 20 transactions * 4900 = 98000, achieving PTR ~0.98.
infected_expanded['amount (INR)'] = 4900.0

# Ensure fraud_flag is set to 1 for our synthetically infected dataset
infected_expanded['fraud_flag'] = 1

# Re-combine and re-sort chronologically
full_df = pd.concat([pristine_df, infected_expanded], ignore_index=True)
full_df.sort_values('timestamp', inplace=True)
full_df.reset_index(drop=True, inplace=True)

print("3. Feature Engineering (The 120s Sieve)")
full_df['amount'] = full_df['amount (INR)']
full_df['original_order'] = np.arange(len(full_df))
full_df.sort_values(['proxy_account_id', 'timestamp'], inplace=True)

# Calculate standard temporal delta between jumps
full_df['time_delta_sec'] = full_df.groupby('proxy_account_id')['timestamp'].diff().dt.total_seconds()
full_df.set_index('timestamp', inplace=True)

grouped = full_df.groupby('proxy_account_id', sort=False)

full_df['txn_count_120s'] = grouped['amount'].rolling('120s').count().values
rolling_sum = grouped['amount'].rolling('120s').sum().values
full_df['ptr_ratio'] = np.clip(rolling_sum / 100000.0, a_min=None, a_max=1.0)
full_df['jitter_sigma'] = grouped['time_delta_sec'].rolling('120s').std().values
full_df['jitter_sigma'] = full_df['jitter_sigma'].fillna(0.0)

full_df.reset_index(inplace=True)
full_df.sort_values('original_order', inplace=True)

print("4. Temporal Split & Training")
n = len(full_df)
train_end = int(0.7 * n)
val_end = int(0.85 * n)

train = full_df.iloc[:train_end]
val = full_df.iloc[train_end:val_end]
test = full_df.iloc[val_end:]

features = ['amount', 'txn_count_120s', 'ptr_ratio', 'jitter_sigma']
target = 'fraud_flag'

X_train, y_train = train[features], train[target].astype(int)
X_val, y_val = val[features], val[target].astype(int)
X_test, y_test = test[features], test[target].astype(int)

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

print("5. Export & Verify")
y_pred = model.predict(X_test)
print("\nClassification Report:")
print(classification_report(y_test, y_pred, digits=4))
f1 = f1_score(y_test, y_pred)

model_path = '/workspaces/sentinel-v1/sentinel_root/core_engine/xgboost_model.json'
model.save_model(model_path)
print(f"\nModel exported successfully to {model_path}")
print(f"Final F1-Score: {f1:.4f}")
