# Firebase Admin SDK Setup Guide

## Problem
The backend needs `serviceAccountKey.json` to update visitor status in Firebase when QR codes are scanned and approved.

## Solution: Download Service Account Key from Firebase Console

### Step 1: Open Firebase Console
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project (e.g., `finalyp-580ad`)

### Step 2: Get Service Account Key
1. Click the **⚙️ Settings** (gear icon) in the top left
2. Select **Project settings**
3. Go to the **Service accounts** tab
4. Click **Generate new private key** button
5. A dialog will appear - click **Generate key**
6. This will download a JSON file (usually named like `finalyp-580ad-firebase-adminsdk-xxxxx.json`)

### Step 3: Place the File in Backend Folder
1. Rename the downloaded file to `serviceAccountKey.json`
2. Move/copy it to the `backend` folder (same folder as `main.py`)
3. The path should be: `backend/serviceAccountKey.json`

### Step 4: Restart Backend Server
1. Stop your backend server (Ctrl+C)
2. Restart it:
   ```powershell
   cd backend
   .\.venv\Scripts\Activate.ps1
   uvicorn main:app --host 0.0.0.0 --port 5000 --reload
   ```
3. Check the console - you should see: **"Firebase Admin SDK initialized successfully"**

### Step 5: Verify
1. Try scanning a QR code again
2. Click "Approve"
3. The error message should be gone
4. Check Firebase Console - the `vstStatus` should change from "Up Coming" to "History"
5. The visitor should appear in the Visitor History page in the Flutter app

## Security Note
⚠️ **Important**: Never commit `serviceAccountKey.json` to Git! It contains sensitive credentials.
- Add `serviceAccountKey.json` to `.gitignore`
- Each developer needs to download their own service account key

## Troubleshooting
- **Still getting error?** Make sure the file is named exactly `serviceAccountKey.json` (case-sensitive)
- **Permission denied?** Make sure the service account has Firestore read/write permissions
- **Backend not starting?** Check that `firebase-admin` package is installed: `pip install firebase-admin==6.5.0`





