# 🪟 Windows Setup Guide

## The Problem
You're getting these errors:
- `Python was not found`
- `flutter : The term 'flutter' is not recognized`

This means Python and Flutter are not in your system PATH.

## 🚀 Quick Fix (3 Steps)

### Step 1: Start Backend Server
```bash
# Navigate to backend folder
cd backend

# Run the Windows batch file
start_server_windows.bat
```

This will automatically find and use your Python installation.

### Step 2: Start Flutter App
```bash
# Go back to project root
cd ..

# Run the Flutter batch file
start_flutter_windows.bat
```

This will automatically find and use your Flutter installation.

### Step 3: Test the Connection
Once both are running, try scanning a parking area in the Flutter app.

## 🔧 Manual Setup (If Batch Files Don't Work)

### Install Python (if not installed)
1. **Download Python**: https://www.python.org/downloads/
2. **Install with "Add to PATH"** checked
3. **Restart PowerShell**
4. **Test**: `python --version`

### Install Flutter (if not installed)
1. **Download Flutter**: https://flutter.dev/docs/get-started/install/windows
2. **Extract to C:\flutter**
3. **Add to PATH**: Add `C:\flutter\bin` to your PATH
4. **Restart PowerShell**
5. **Test**: `flutter --version`

## 🧪 Test Commands

### Test Python
```bash
python --version
# Should show: Python 3.x.x
```

### Test Flutter
```bash
flutter --version
# Should show: Flutter 3.x.x
```

### Test Server
```bash
cd backend
python app.py
# Should show: Running on http://127.0.0.1:5000
```

### Test Flutter App
```bash
flutter run
# Should start the Flutter app
```

## 🔍 Troubleshooting

### Problem 1: Python not found
**Solution**: Install Python and add to PATH
- Download from https://www.python.org/downloads/
- Check "Add Python to PATH" during installation
- Restart PowerShell

### Problem 2: Flutter not found
**Solution**: Install Flutter and add to PATH
- Download from https://flutter.dev/docs/get-started/install/windows
- Extract to C:\flutter
- Add C:\flutter\bin to PATH
- Restart PowerShell

### Problem 3: PATH not working
**Solution**: Use full paths
```bash
# Instead of: python app.py
# Use: C:\Python39\python.exe app.py

# Instead of: flutter run
# Use: C:\flutter\bin\flutter.bat run
```

## 📁 File Structure
```
fyp/
├── backend/
│   ├── app.py
│   ├── start_server_windows.bat
│   └── ...
├── lib/
│   ├── main.dart
│   ├── stut_login.dart
│   └── ...
├── start_flutter_windows.bat
└── WINDOWS_SETUP_GUIDE.md
```

## 🎯 Expected Results

### Backend Server
```
Starting Parking Detection API Server...
Available endpoints:
- POST /api/parking/simple-detect - Simple parking detection
- GET /health - Health check
* Running on http://127.0.0.1:5000
```

### Flutter App
```
Launching lib\main.dart on sdk gphone64 x86 64 in debug mode...
Running Gradle task 'assembleDebug'...
```

### Success
- ✅ Backend server running on port 5000
- ✅ Flutter app starts successfully
- ✅ Camera scanning works
- ✅ Parking detection shows results

## 🚨 If Still Not Working

### Option 1: Use Full Paths
```bash
# Find your Python path
where python
# Use full path: C:\Python39\python.exe app.py

# Find your Flutter path
where flutter
# Use full path: C:\flutter\bin\flutter.bat run
```

### Option 2: Install Missing Software
- **Python**: https://www.python.org/downloads/
- **Flutter**: https://flutter.dev/docs/get-started/install/windows

### Option 3: Use Android Studio
- Open project in Android Studio
- Run the Flutter app from there
- Start backend server in terminal

## 🎉 Success!

Once everything is working:
1. **Backend server** shows "Running on http://127.0.0.1:5000"
2. **Flutter app** starts and shows the login screen
3. **Camera scanning** works without "Failed to fetch" errors
4. **Parking detection** shows available/occupied spaces

The simple detection method will work much better than the complex coordinate-based system!




