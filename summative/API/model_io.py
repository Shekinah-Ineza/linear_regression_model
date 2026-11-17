"""Load the saved pipeline and predict one row.

Task 1 writes this function and uses it on a single test row.
Task 2 imports the same function for POST /predict.
"""

from pathlib import Path

import joblib
import pandas as pd

FEATURES = [
    "country",
    "sector",
    "activity",
    "repayment_interval",
    "loan_theme_type",
    "term_in_months",
    "borrower_count",
    "female_borrower_share",
    "mpi",
    "rural_pct",
]
TARGET = "loan_amount"

API_DIR = Path(__file__).resolve().parent
MODEL_PATH = API_DIR / "best_model.pkl"
TRAIN_PATH = API_DIR / "training_data.csv"

_CACHE = {"path": None, "mtime": None, "model": None}


def load_saved_model(path=None):
    """Load the joblib pipeline shipped with the API."""
    model_path = Path(path) if path is not None else MODEL_PATH
    mtime = model_path.stat().st_mtime
    if (
        _CACHE["model"] is not None
        and _CACHE["path"] == model_path
        and _CACHE["mtime"] == mtime
    ):
        return _CACHE["model"]
    model = joblib.load(model_path)
    _CACHE["path"] = model_path
    _CACHE["mtime"] = mtime
    _CACHE["model"] = model
    return model


def remember_model(model, path=None):
    """Point the cache at a model that was just saved, including a retrained one."""
    model_path = Path(path) if path is not None else MODEL_PATH
    _CACHE["path"] = model_path
    _CACHE["mtime"] = model_path.stat().st_mtime
    _CACHE["model"] = model
    return model


def predict_one_test_row(row, model_path=None):
    """Load the saved pipeline and predict the target for one row.

    `row` is one row of model features, such as X_test.iloc[[0]] from the
    notebook, or one request body turned into a one-row DataFrame.
    """
    model = load_saved_model(model_path)
    if isinstance(row, pd.Series):
        frame = row.to_frame().T
    else:
        frame = row.copy()
    missing = [column for column in FEATURES if column not in frame.columns]
    if missing:
        raise ValueError(f"Row is missing features: {missing}")
    prediction = model.predict(frame.loc[:, FEATURES])
    return float(prediction[0])
