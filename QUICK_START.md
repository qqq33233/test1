# 🚀 Quick Start Guide

## The Problem
You're seeing: "Cannot connect to server. Please make sure the backend server is running on port 5000."

This means the backend server isn't running.

## 🔧 Fix: Start the Backend Server

### Method 1: Use the Batch File (Recommended)
```bash
cd backend
start_server_manual.bat
```

This will:
- Check if Python is installed
- Install required packages
- Start the Flask server
- Show server status

### Method 2: Manual Start
```bash
cd backend
python app.py
```

You should see:
```
Starting Parking Detection API Server...
Available endpoints:
- POST /api/parking/simple-detect - Simple parking detection
- GET /health - Health check
* Running on http://127.0.0.1:5000
```

### Method 3: If Python Not Found
1. **Install Python**: https://www.python.org/downloads/
2. **Check "Add Python to PATH"** during installation
3. **Restart PowerShell**
4. **Try again**: `python app.py`

## 🧪 Test the Server

### Test 1: Check if Server is Running
```bash
cd backend
python test_server_simple.py
```

Should show: "✅ Server is running!"

### Test 2: Manual Test
```bash
curl http://localhost:5000/health
```

Should return: `{"status": "healthy", "timestamp": "..."}`

## 📱 Start Flutter App

Once the server is running:

### Method 1: Use Batch File
```bash
cd ..
start_flutter_windows.bat
```

### Method 2: Manual Start
```bash
flutter run
```

### Method 3: If Flutter Not Found
```bash
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
```bash
C:\flutter\bin\flutter.bat run
```

### Problem 3: Server starts but Flutter can't connect
**Solution**: Check the server is running on port 5000
- Server should show "Running on http://127.0.0.1:5000"
- Test with: `curl http://localhost:5000/health`

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
* Running on http://[::1]:5000
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
```bash
cd backend
python test_server_simple.py
```

### Check Flutter Status:
```bash
flutter doctor
```

### Check Network:
```bash
ping localhost
```

The key is to make sure the backend server is running on port 5000 before starting the Flutter app!




