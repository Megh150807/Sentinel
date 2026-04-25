import xgboost as xgb
import numpy as np

def main():
    # Generate dummy data for [transaction_amount, passes_through_count, time_interval_ms]
    np.random.seed(42)
    X = np.random.rand(100, 3) * 100
    y = np.random.randint(2, size=100)

    dtrain = xgb.DMatrix(X, label=y)
    param = {
        'max_depth': 3,
        'eta': 0.3,
        'objective': 'binary:logistic',
        'eval_metric': 'logloss'
    }
    
    num_round = 20
    bst = xgb.train(param, dtrain, num_round)

    # Save to JSON format for the C++ XGBoost C-API
    bst.save_model('xgboost.json')
    print("Exported model to xgboost.json for C++ core ingestion.")

if __name__ == "__main__":
    main()
