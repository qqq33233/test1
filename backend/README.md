FastAPI Parking Backend

Overview
- Scans a camera feed (e2eSoft iVCam) to detect occupied/available parking slots using YOLO + OpenCV.
- Persists slot states and bookings in SQLite.
- Exposes REST endpoints for the Flutter app.

Requirements
- Python 3.11.x (confirmed working on 3.11.0)
- Windows with iVCam installed and running (appears as a webcam device)

Quick start (Windows PowerShell)
1) Create a venv and install deps
   ```powershell
   cd backend
   py -3.11 -m venv .venv
   .\.venv\Scripts\Activate.ps1
   python -m pip install --upgrade pip
   pip install -r requirements.txt
   ```
2) Verify camera index
   - iVCam usually shows up as device index 0 or 1.
   - Update `areas.json` -> `camera_index` accordingly.

3) Run server
   ```powershell
   uvicorn main:app --host 0.0.0.0 --port 8000 --reload
   ```

Endpoints
- GET /health
- GET /areas
- POST /scan { area }
- POST /assign { area, userId }
- POST /release { area, slotId }

Calibration
- Slots are defined as polygons per area in `areas.json` using image pixel coordinates.
- Start with the provided demo and adjust points to match your camera view.



