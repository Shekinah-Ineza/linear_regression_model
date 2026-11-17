My mission is to help women and rural micro-entrepreneurs get a fair working-capital offer through Kiva field partners.
Loan officers have to choose the US dollar amount to request before a loan is posted. Too high is slow to fund and hard to repay; too low leaves the business short.
This project predicts that loan amount from the business, the borrower group, the repayment terms, the local Multidimensional Poverty Index, and how rural the community is.
The user of the prediction is a Kiva field-partner loan officer, who checks a recommended amount before posting the loan.

The model is trained on Kiva's Data Science for Good files: 671,205 loans joined to regional poverty (MPI) and rural-share tables. Source: https://www.kaggle.com/datasets/kiva/data-science-for-good-kiva-crowdfunding

Swagger UI: https://YOUR-SERVICE-NAME.onrender.com/docs

Video demo: https://www.youtube.com/watch?v=YOUR_VIDEO_ID

## Run the mobile app

1. Install Flutter, then start an Android or iOS emulator, or plug in a phone. The app is not a web app.
2. Open `summative/FlutterApp`. If `android/` and `ios/` are not there yet, run `flutter create --project-name kiva_loan_app .` in that folder. This keeps `lib/main.dart`.
3. In `summative/FlutterApp/lib/main.dart`, set `apiBaseUrl` to your Render URL, with no trailing slash. For an Android emulator calling an API on this computer, use `http://10.0.2.2:8000`. For the iOS simulator, use `http://127.0.0.1:8000`.
4. Run `flutter pub get`, then `flutter run`.
5. Fill all ten fields and press Predict. The amount appears in the prediction box.
6. A missing value, a value of the wrong type, or a number outside the allowed range is shown in that same box. Try a blank term, the text `abc` in term, or borrower count `0`.

Hints in the fields are a real example: Kenya, Agriculture, Farming, monthly, General, term 14, 1 borrower, female share 1, MPI 0.06, rural percent 69. That request predicts about 429 USD.

## Before you submit

Replace the Swagger line and the video line above after you deploy and record. A localhost link does not score. On Render, create a free Web Service, set the root directory to `summative/API`, the build command to `pip install -r requirements.txt`, and the start command to `uvicorn prediction:app --host 0.0.0.0 --port $PORT`. Open `/docs` once before the recording, because a free service sleeps after 15 minutes and can take up to a minute to wake. The free plan also deletes local file changes on sleep, so a retrained model lasts only until the next cold start. Startup loads `best_model.pkl` from the repository.

`RENDER_EXTERNAL_URL` is added to the CORS origin list when Render sets it. If you name the service something other than `kiva-loan-amount`, you can also replace `https://kiva-loan-amount.onrender.com` in `summative/API/prediction.py`.

## What the models did

The saved model is a `RandomForestRegressor` pipeline (one-hot encoding, a scaler fit on the training rows only, and the forest). It has the lowest test mean squared error.

| Model | Train MSE | Test MSE | Test RMSE (USD) |
| --- | ---: | ---: | ---: |
| Random forest | 196,155 | 204,146 | 452 |
| Decision tree | 198,149 | 216,932 | 466 |
| SGDRegressor | 339,946 | 305,423 | 553 |
| LinearRegression | 339,886 | 305,580 | 553 |

Borrower count is the numeric feature most correlated with loan amount (0.52). Median requests run from about 200 USD in Personal Use to about 950 USD in Wholesale. `funded_amount` correlates 0.95 with the target and matches it on 92.9% of rows, so it was dropped, along with `lender_count`. The forest's train and test errors stay close, so the lower test error is not from memorizing the 24,000 training rows. One held-out row (El Salvador, Agriculture, Poultry, monthly, 14 months, one woman borrower) predicts 533 USD against an actual 500 USD.

SGD was tuned on the learning-rate schedule, `eta0`, L2 `alpha`, and epochs. The best row was `invscaling`, `eta0` 0.001, `alpha` 0.0001, and 40 epochs (test MSE about 305,423). `eta0` of 0.1 diverged. Raising `alpha` from 0.0001 to 0.01 raised test MSE slightly. 40 epochs beat 15, and the loss curve's test MSE fell from about 322,112 to about 306,019. The two linear models agree once the step size is stable. They lose to the trees because the amount depends on combinations, not one straight line.

## Answers to record in the video

Keep the camera on, share the whole screen, and stay under 7 minutes. Show the phone or emulator making a valid prediction and a bad input, the Flutter `_predict` method, Swagger doing a valid prediction and a wrong type, then the notebook heatmap, loss curve, and test-MSE table.

1. The test loss is high for quoting an exact disbursement. Test MSE is about 204,146, an RMSE of about 452 USD, against a median loan of 500 USD. To reduce it, train on more than the 30,000-row sample and use the free-text loan purpose. Do not add funded amount or lender count. Those leak the answer.
2. The tuned settings are the SGD schedule, `eta0`, `alpha`, and epochs, as above. A large learning rate diverged. A larger penalty and fewer epochs each made the test loss a little worse. The loss curve falls and then flattens.
3. `POST /retrain` takes a CSV with the same columns as `summative/API/training_data.csv`, including `loan_amount`. The saved model is a random forest, so the API refits it on the original training rows plus the new rows. The next `/predict` uses that model with no redeploy. On the free plan the update is discarded when the service sleeps.
4. CORS does not apply to the Flutter phone app, because it is not a browser. The middleware still lists origins, methods (`GET`, `POST`, `OPTIONS`), headers (`Accept`, `Authorization`, `Content-Type`), and credentials. There is no wildcard origin, so a random website cannot call the API from a visitor's browser.

## Run the API and the notebook locally

From `summative`:

```
uv sync --all-groups
uv run uvicorn prediction:app --app-dir API --host 127.0.0.1 --port 8000
```

Swagger is then at http://127.0.0.1:8000/docs. The four Kiva CSVs must sit in `Desktop/archive` if you re-run `summative/linear_regression/multivariate.ipynb`. `requirements.txt` was exported with `uv export --format requirements.txt --no-hashes -o API/requirements.txt`.
