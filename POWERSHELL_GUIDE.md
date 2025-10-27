# 🔧 PowerShell Setup Guide

## The Problem
You're getting these errors:
- `The token '&&' is not a valid statement separator in this version`
- `Python was not found`

This is because PowerShell has different syntax than Command Prompt.

## 🚀 Quick Fix (3 Steps)

### Step 1: Navigate to Backend Folder
```powershell
cd backend
```

### Step 2: Start the Server (PowerShell Method)
```powershell
.\start_server.ps1
```

This PowerShell script will:
- Check if Python is installed
- Install required packages
- Start the Flask server
- Show server status

### Step 3: Test the Server
```powershell
.\test_server.ps1
```

Should show: "✅ Server is running!"

## 🔍 Alternative Methods

### Method 1: Manual Python Commands
```powershell
# Try different Python commands
python --version
py --version
python3 --version
```

### Method 2: Use Full Python Path
```powershell
# If you know where Python is installed
C:\Python39\python.exe app.py
C:\Python38\python.exe app.py
```

### Method 3: Install Python
1. **Download Python**: https://www.python.org/downloads/
2. **Install with "Add Python to PATH"** checked
3. **Restart PowerShell**
4. **Try again**: `python app.py`

## 🧪 Test Commands

### Test Python
```powershell
python --version
# Should show: Python 3.x.x
```

### Test Server
```powershell
.\test_server.ps1
# Should show: "✅ Server is running!"
```

### Test Manually
```powershell
Invoke-RestMethod -Uri "http://localhost:5000/health"
# Should return: {"status": "healthy", "timestamp": "..."}
```

## 📱 Start Flutter App

Once the server is running:

### Method 1: Use Batch File
```powershell
cd ..
.\start_flutter_windows.bat
```

### Method 2: Manual Start
```powershell
flutter run
```

### Method 3: Use Full Flutter Path
```powershell
C:\flutter\bin\flutter.bat run
```

## ✅ Success Indicators

### Backend Server
- ✅ Shows "Running on http://127.0.0.1:5000"
- ✅ No error messages
- ✅ Server keeps running (don't close the window)

### Flutter App
- ✅ Starts without errors
- ✅ Shows login screen
- ✅ Camera scanning works
- ✅ No "Cannot connect to server" errors

## 🔍 Troubleshooting

### Problem 1: "Python was not found"
**Solution**: Install Python and add to PATH
- Download from https://www.python.org/downloads/
- Check "Add Python to PATH" during installation
- Restart PowerShell

### Problem 2: "Flutter was not found"
**Solution**: Use full path
```powershell
C:\flutter\bin\flutter.bat run
```

### Problem 3: PowerShell execution policy
**Solution**: Allow script execution
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Problem 4: Still getting connection errors
**Solution**: Make sure both are running
1. **Backend server** running on port 5000
2. **Flutter app** running and connected
3. **No firewall** blocking port 5000

## 🎯 Expected Results

### Backend Server Output:
```
Starting Parking Detection API Server...
Available endpoints:
- POST /api/parking/simple-detect - Simple parking detection
- GET /health - Health check
* Running on http://127.0.0.1:5000
```

### Flutter App Output:
```
Launching lib\main.dart on sdk gphone64 x86 64 in debug mode...
Running Gradle task 'assembleDebug'...
```

### Success:
- ✅ Backend server running on port 5000
- ✅ Flutter app starts successfully
- ✅ Camera scanning works
- ✅ Parking detection shows results

## 🚨 If Still Not Working

### Check Server Status:
```powershell
.\test_server.ps1
```

### Check Flutter Status:
```powershell
flutter doctor
```

### Check Network:
```powershell
Test-NetConnection -ComputerName localhost -Port 5000
```

## 📁 File Structure
```
fyp/
├── backend/
│   ├── app.py
│   ├── start_server.ps1          ← New!
│   ├── test_server.ps1           ← New!
│   └── ...
├── start_flutter_windows.bat
└── POWERSHELL_GUIDE.md           ← New!
```

## 🎉 Success!

Once everything is working:
1. **Backend server** shows "Running on http://127.0.0.1:5000"
2. **Flutter app** starts and shows the login screen
3. **Camera scanning** works without "Failed to fetch" errors
4. **Parking detection** shows available/occupied spaces

The key is to use PowerShell syntax and make sure Python is installed!




