from fastapi import FastAPI, Request, Body
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, HTMLResponse, StreamingResponse
from fastapi.exceptions import RequestValidationError
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
import cv2
import numpy as np
import traceback
import threading
import time
import json
import os

# Firebase Admin SDK
try:
    import firebase_admin
    from firebase_admin import credentials, firestore
    FIREBASE_AVAILABLE = True
except ImportError:
    FIREBASE_AVAILABLE = False
    print("Warning: firebase-admin not installed. QR code scanning will not update Firebase.")

# ZBar QR Code Scanner (lazy import to avoid DLL loading errors on Windows)
ZBAR_AVAILABLE = False

def _try_load_zbar():
    """Try to load ZBar decoder, returns decode function or None."""
    try:
        # Try importing the module first
        import pyzbar
        # Then try to import decode
        from pyzbar.pyzbar import decode
        # Test by checking if decode is callable
        if callable(decode):
            return decode, True
        return None, False
    except (ImportError, OSError, FileNotFoundError, AttributeError, Exception) as e:
        # Catch any exception including DLL loading errors
        print(f"ZBar import failed: {type(e).__name__}: {str(e)[:100]}")
        return None, False

# Try to load ZBar
ZBAR_DECODE, ZBAR_AVAILABLE = _try_load_zbar()
if ZBAR_AVAILABLE:
    print("ZBar QR code scanner available")
else:
    print("Warning: pyzbar not available. QR code detection will use OpenCV fallback.")
    print("To enable ZBar on Windows, install ZBar DLL from: https://github.com/mchehab/zbar")

# EasyOCR for car plate detection (lazy import)
EASYOCR_AVAILABLE = False
easyocr_reader = None
easyocr_init_error = None

def _try_load_easyocr():
    """Try to load EasyOCR for car plate recognition."""
    global easyocr_init_error
    try:
        print("[EasyOCR] Attempting to import easyocr...")
        import easyocr
        print("[EasyOCR] Import successful, initializing reader (this may take a minute on first run)...")
        # Initialize EasyOCR reader (English only for license plates)
        # This will download models on first run, which can take time
        reader = easyocr.Reader(['en'], gpu=False, verbose=False)
        print("[EasyOCR] Reader initialized successfully!")
        easyocr_init_error = None
        return reader, True
    except ImportError as e:
        error_msg = f"EasyOCR not installed: {str(e)}"
        print(f"[EasyOCR] ERROR: {error_msg}")
        print("[EasyOCR] Install with: pip install easyocr")
        easyocr_init_error = error_msg
        return None, False
    except Exception as e:
        error_msg = f"EasyOCR initialization failed: {type(e).__name__}: {str(e)}"
        print(f"[EasyOCR] ERROR: {error_msg}")
        traceback.print_exc()
        easyocr_init_error = error_msg
        return None, False

# Try to load EasyOCR (lazy - will initialize when first needed)
# Don't initialize at startup to avoid blocking server startup
easyocr_reader, EASYOCR_AVAILABLE = None, False
print("[EasyOCR] EasyOCR will be initialized on first use (lazy loading)")

app = FastAPI()

# Mount static files for assets
assets_path = os.path.join(os.path.dirname(__file__), 'assets')
if os.path.exists(assets_path):
    app.mount("/assets", StaticFiles(directory=assets_path), name="assets")

# Enable CORS for Flutter app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, replace with your Flutter app's origin
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    """Global exception handler to ensure JSON responses."""
    try:
        print(f"Unhandled exception in {request.url.path}: {exc}")
        traceback.print_exc()
        error_msg = str(exc) if exc else "Unknown error"
        error_type = type(exc).__name__ if exc else "Exception"
        return JSONResponse(
            status_code=500,
            content={
                "success": False,
                "error": error_msg,
                "type": error_type,
                "path": str(request.url.path)
            }
        )
    except Exception as handler_error:
        print(f"ERROR: Exception handler itself failed: {handler_error}")
        traceback.print_exc()
        # Last resort - return plain text
        from fastapi.responses import PlainTextResponse
        return PlainTextResponse(
            content=f"Server Error: {str(handler_error)}",
            status_code=500
        )

# === Load parking area configurations ===
AREA_CONFIGS = {}
DEFAULT_AREA = None

def load_area_configs():
    """Load parking area configurations from areas.json."""
    global AREA_CONFIGS, DEFAULT_AREA
    try:
        config_path = os.path.join(os.path.dirname(__file__), 'areas.json')
        if os.path.exists(config_path):
            with open(config_path, 'r') as f:
                data = json.load(f)
                for area in data.get('areas', []):
                    area_name = area['name']
                    # Convert slot polygons from JSON format to list of tuples
                    slots = []
                    for slot in area.get('slots', []):
                        polygon = slot.get('polygon', [])
                        # Convert [[x,y], [x,y], ...] to [(x,y), (x,y), ...]
                        slot_coords = [(int(pt[0]), int(pt[1])) for pt in polygon]
                        slots.append(slot_coords)
                    AREA_CONFIGS[area_name] = {
                        'slots': slots,
                        'camera_index': area.get('camera_index', 0),
                        'frame_width': area.get('frame_width', 1920),
                        'frame_height': area.get('frame_height', 1080)
                    }
                    if DEFAULT_AREA is None:
                        DEFAULT_AREA = area_name
            print(f"Loaded {len(AREA_CONFIGS)} parking area configurations: {list(AREA_CONFIGS.keys())}")
        else:
            print(f"Warning: areas.json not found at {config_path}. Using default configuration.")
            # Fallback to default configuration
            DEFAULT_AREA = "Demo"
            AREA_CONFIGS["Demo"] = {
                'slots': [
                    [(42,51), (202,51), (202,396), (42,396)],
                    [(215,51), (366,51), (366,396), (215,396)],
                    [(390,51), (534,51), (534,396), (390,396)],
                    [(553,51), (704,51), (704,396), (553,396)],
                    [(726,51), (872,51), (872,396), (726,396)],
                    [(894,51), (1043,51), (1043,396), (894,396)],
                    [(1063,51), (1213,51), (1213,396), (1063,396)],
                    [(42,455), (202,455), (202,784), (42,784)],
                    [(215,455), (366,455), (366,784), (215,784)],
                    [(390,455), (534,455), (534,784), (390,784)],
                    [(553,455), (704,455), (704,784), (553,784)],
                    [(726,455), (872,455), (872,784), (726,784)],
                    [(894,455), (1043,455), (1043,784), (894,784)],
                    [(1063,455), (1213,455), (1213,784), (1063,784)]
                ],
                'camera_index': 0,
                'frame_width': 1920,
                'frame_height': 1080
            }
    except Exception as e:
        print(f"Error loading area configurations: {e}")
        traceback.print_exc()

# Load configurations on startup
load_area_configs()

# Initialize Firebase Admin SDK (if available)
firestore_db = None
if FIREBASE_AVAILABLE:
    try:
        # Try to initialize with service account key if exists
        service_account_path = os.path.join(os.path.dirname(__file__), 'serviceAccountKey.json')
        if os.path.exists(service_account_path):
            cred = credentials.Certificate(service_account_path)
            firebase_admin.initialize_app(cred)
            firestore_db = firestore.client()
            print("Firebase Admin SDK initialized successfully")
        else:
            print("Warning: serviceAccountKey.json not found. Firebase updates will be disabled.")
            print("To enable Firebase updates, download service account key from Firebase Console")
    except Exception as e:
        print(f"Error initializing Firebase: {e}")
        FIREBASE_AVAILABLE = False

def get_parking_spaces_for_area(area_name: str):
    """Get parking spaces configuration for a specific area."""
    # Try exact match first
    if area_name in AREA_CONFIGS:
        return AREA_CONFIGS[area_name]['slots']
    
    # Try case-insensitive match
    area_name_lower = area_name.lower()
    for key in AREA_CONFIGS.keys():
        if key.lower() == area_name_lower:
            return AREA_CONFIGS[key]['slots']
    
    # Try partial match (e.g., "DTAR (WC)" matches "DTAR")
    for key in AREA_CONFIGS.keys():
        if area_name_lower in key.lower() or key.lower() in area_name_lower:
            return AREA_CONFIGS[key]['slots']
    
    # Default to first available area or Demo
    if DEFAULT_AREA and DEFAULT_AREA in AREA_CONFIGS:
        print(f"Warning: Area '{area_name}' not found. Using default area '{DEFAULT_AREA}'.")
        return AREA_CONFIGS[DEFAULT_AREA]['slots']
    
    # Last resort: return empty list
    print(f"Error: No configuration found for area '{area_name}' and no default available.")
    return []

# === Base image size (same resolution you used when defining coordinates) ===
BASE_WIDTH = 1245
BASE_HEIGHT = 807

# === Default parking coordinates (fallback) ===
PARKING_SPACES = [
    [(42,51), (202,51), (202,396), (42,396)],
    [(215,51), (366,51), (366,396), (215,396)],
    [(390,51), (534,51), (534,396), (390,396)],
    [(553,51), (704,51), (704,396), (553,396)],
    [(726,51), (872,51), (872,396), (726,396)],
    [(894,51), (1043,51), (1043,396), (894,396)],
    [(1063,51), (1213,51), (1213,396), (1063,396)],
    [(42,455), (202,455), (202,784), (42,784)],
    [(215,455), (366,455), (366,784), (215,784)],
    [(390,455), (534,455), (534,784), (390,784)],
    [(553,455), (704,455), (704,784), (553,784)],
    [(726,455), (872,455), (872,784), (726,784)],
    [(894,455), (1043,455), (1043,784), (894,784)],
    [(1063,455), (1213,455), (1213,784), (1063,784)]
]

# === Initialize camera (iVCam on Windows) ===
# Try DirectShow backend first for Windows webcams
def init_camera():
    # iVCam usually appears as camera index 0 or 1
    for idx in [0, 1]:
        cap = cv2.VideoCapture(idx, cv2.CAP_DSHOW)
        if cap.isOpened():
            # Test read to ensure it's working
            ret, _ = cap.read()
            if ret:
                cap.set(cv2.CAP_PROP_FRAME_WIDTH, 1280)
                cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 720)
                return cap, idx
            cap.release()
    # Fallback to default backend
    cap = cv2.VideoCapture(0)
    if cap.isOpened():
        return cap, 0
    return None, None

cap, camera_index = init_camera()
camera_lock = threading.Lock()  # Lock for thread-safe camera access

# Global variables to store frozen frame and results (when confirm is clicked)
frozen_frame = None  # Processed frame with overlays (for display)
frozen_raw_frame = None  # Raw frame without overlays (for analysis)
frozen_analysis = None  # Store (occupied_count, empty_count, statuses, assigned_spot_no)
frozen_frame_lock = threading.Lock()

if cap is None:
    print("ERROR: Cannot connect to iVCam. Please ensure iVCam is running and streaming.")
else:
    print(f"Camera connected successfully (index: {camera_index})")


def read_frame_safe():
    """Thread-safe frame reading."""
    try:
        with camera_lock:
            if cap is None or not cap.isOpened():
                return False, None
            try:
                success, frame = cap.read()
                return success, frame
            except Exception as e:
                print(f"Error reading from camera: {e}")
                return False, None
    except Exception as e:
        print(f"Error in read_frame_safe: {e}")
        return False, None


def scale_points(points, frame_w, frame_h):
    """Scale polygon coordinates based on actual camera size."""
    scale_x = frame_w / BASE_WIDTH
    scale_y = frame_h / BASE_HEIGHT
    return [(int(x * scale_x), int(y * scale_y)) for x, y in points]


def analyze_parking(frame, area_name: str = None):
    """Analyze parking spots and return counts without drawing."""
    try:
        if frame is None or frame.size == 0:
            raise ValueError("Invalid frame")
        
        # Validate frame dimensions
        if len(frame.shape) < 2:
            raise ValueError("Frame has invalid dimensions")
        
        # Convert to grayscale, handling different input formats
        if len(frame.shape) == 3:
            gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        elif len(frame.shape) == 2:
            gray = frame.copy()
        else:
            raise ValueError("Unsupported frame format")
            
        frame_h, frame_w = gray.shape
        
        if frame_h <= 0 or frame_w <= 0:
            raise ValueError("Invalid frame dimensions")

        # Get parking spaces for the specified area
        parking_spaces = get_parking_spaces_for_area(area_name) if area_name else PARKING_SPACES
        if not parking_spaces:
            print(f"Warning: No parking spaces found for area '{area_name}'. Using default.")
            parking_spaces = PARKING_SPACES

        total_spots = len(parking_spaces)
        occupied_count = 0
        statuses = []

        for idx, space in enumerate(parking_spaces):
            try:
                pts = np.array(scale_points(space, frame_w, frame_h), np.int32)
                mask = np.zeros(gray.shape, np.uint8)
                cv2.fillPoly(mask, [pts], 255)

                spot_gray = cv2.bitwise_and(gray, gray, mask=mask)
                x, y, w, h = cv2.boundingRect(pts)
                
                # Ensure valid crop dimensions
                if w > 0 and h > 0 and x >= 0 and y >= 0:
                    spot_crop = spot_gray[y:y+h, x:x+w]
                    # Detect texture/variance
                    nonzero = spot_crop[np.nonzero(spot_crop)]
                    if len(nonzero) > 0:
                        variance = np.var(nonzero)
                        occupied = variance > 300
                    else:
                        occupied = False
                else:
                    occupied = False

                if occupied:
                    occupied_count += 1

                statuses.append(occupied)
            except Exception as e:
                print(f"Error processing slot {idx}: {e}")
                statuses.append(False)  # Default to empty on error

        empty_count = total_spots - occupied_count
        return occupied_count, empty_count, statuses
    except Exception as e:
        print(f"Error in analyze_parking: {e}")
        # Return default values on error
        parking_spaces = get_parking_spaces_for_area(area_name) if area_name else PARKING_SPACES
        total_default = len(parking_spaces) if parking_spaces else 14
        return 0, total_default, [False] * total_default


def detect_parking(frame, area_name: str = None):
    """Detect occupancy and draw info on a frame."""
    gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
    frame_h, frame_w = gray.shape

    # Get parking spaces for the specified area
    parking_spaces = get_parking_spaces_for_area(area_name) if area_name else PARKING_SPACES
    if not parking_spaces:
        print(f"Warning: No parking spaces found for area '{area_name}'. Using default.")
        parking_spaces = PARKING_SPACES

    total_spots = len(parking_spaces)
    occupied_count = 0

    for idx, space in enumerate(parking_spaces):
        pts = np.array(scale_points(space, frame_w, frame_h), np.int32)
        mask = np.zeros(gray.shape, np.uint8)
        cv2.fillPoly(mask, [pts], 255)

        spot_gray = cv2.bitwise_and(gray, gray, mask=mask)
        x, y, w, h = cv2.boundingRect(pts)
        spot_crop = spot_gray[y:y+h, x:x+w]

        # Detect texture/variance
        variance = np.var(spot_crop[np.nonzero(spot_crop)])
        occupied = variance > 300

        if occupied:
            occupied_count += 1

        color = (0, 0, 255) if occupied else (0, 255, 0)
        label = "Occupied" if occupied else "Empty"
        spot_number = idx + 1  # Spot numbers start from 1

        cv2.polylines(frame, [pts], True, color, 2)
        # Draw spot number (no 1, no 2, etc.)
        spot_label = f"no {spot_number}"
        cv2.putText(frame, spot_label, (pts[0][0], pts[0][1] - 30),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 2)
        # Draw status (Empty/Occupied)
        cv2.putText(frame, label, (pts[0][0], pts[0][1] - 10),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.6, color, 2)

    # --- Display total count on screen ---
    info_text = f"Occupied: {occupied_count}/{total_spots}"
    cv2.rectangle(frame, (10, 10), (250, 40), (0, 0, 0), -1)
    cv2.putText(frame, info_text, (20, 32),
                cv2.FONT_HERSHEY_SIMPLEX, 0.8, (255, 255, 255), 2)

    return frame


def generate_frames():
    """Generate MJPEG video stream."""
    if cap is None or not cap.isOpened():
        # Create error frame
        error_frame = np.zeros((480, 640, 3), dtype=np.uint8)
        cv2.putText(error_frame, "Camera not connected!", (50, 240),
                    cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 0, 255), 2)
        ret, buffer = cv2.imencode('.jpg', error_frame)
        if ret:
            yield (b'--frame\r\n'
                   b'Content-Type: image/jpeg\r\n\r\n' + buffer.tobytes() + b'\r\n')
        return
    
    while True:
        # Check if we have a frozen frame (from confirm button)
        with frozen_frame_lock:
            global frozen_frame
            if frozen_frame is not None:
                # Use frozen frame instead of reading from camera
                frame = frozen_frame.copy()
            else:
                # Read from camera as normal
                success, frame = read_frame_safe()
                if not success or frame is None:
                    print("Warning: Failed to read frame from camera")
                    break

                # === CROP OUT iVCam logo area (adjust these pixel values) ===
                # If the logo is on top and bottom, remove about 60px top and 40px bottom
                if frame.shape[0] > 100:  # Make sure we have enough rows
                    frame = frame[60:-40, :]

                # === Optionally resize for smoother display ===
                frame = cv2.resize(frame, (960, 540))

                # Run detection
                frame = detect_parking(frame)

        # Encode frame as JPEG
        ret, buffer = cv2.imencode('.jpg', frame)
        if not ret:
            continue
        frame_bytes = buffer.tobytes()

        # Stream as multipart MJPEG
        yield (b'--frame\r\n'
               b'Content-Type: image/jpeg\r\n\r\n' + frame_bytes + b'\r\n')
        
        # Small delay to prevent high CPU usage
        time.sleep(0.033)  # ~30 FPS


class AssignRequest(BaseModel):
    area: str = "Demo"


class ReserveRequest(BaseModel):
    area: str
    spot_number: str = ""  # Optional, not required anymore


@app.post("/reset-camera")
def reset_camera():
    """Reset frozen frame to restart camera feed."""
    with frozen_frame_lock:
        global frozen_frame, frozen_raw_frame, frozen_analysis
        frozen_frame = None
        frozen_raw_frame = None
        frozen_analysis = None
    return {"success": True, "message": "Camera feed restarted"}


@app.get("/health")
def health():
    """Check if camera is connected."""
    try:
        if cap is None or not cap.isOpened():
            return JSONResponse(
                status_code=200,
                content={"status": "error", "message": "Camera not connected. Ensure iVCam is running."}
            )
        return JSONResponse(
            status_code=200,
            content={"status": "ok", "camera_index": camera_index}
        )
    except Exception as e:
        print(f"Error in /health: {e}")
        return JSONResponse(
            status_code=500,
            content={"status": "error", "error": str(e)}
        )


@app.get("/api/parking/availability/{area}")
def get_parking_availability(area: str):
    """Get parking availability for a specific area (for Flutter app)."""
    try:
        # Check if we have frozen analysis results (from confirm button)
        try:
            with frozen_frame_lock:
                global frozen_analysis
                if frozen_analysis is not None:
                    # Use stored analysis results from when confirm was clicked
                    # frozen_analysis is a tuple: (occupied_count, empty_count, statuses, assigned_spot_no)
                    if len(frozen_analysis) == 4:
                        occupied_count, empty_count, statuses, assigned_spot_no = frozen_analysis
                    else:
                        # Backward compatibility: if old format, extract assigned_spot_no separately
                        occupied_count, empty_count, statuses = frozen_analysis[:3]
                        assigned_spot_no = None
                        # Calculate assigned spot if not stored
                        for i, is_occupied in enumerate(statuses):
                            if not is_occupied:
                                assigned_spot_no = str(i + 1)
                                break
                    
                    slot_statuses_list = [bool(s) for s in statuses] if statuses else []
                    parking_spaces = get_parking_spaces_for_area(area)
                    total_spots = len(parking_spaces) if parking_spaces else len(statuses) if statuses else 14
                    
                    # Debug: Print what we're returning
                    print(f"DEBUG: Returning frozen analysis for area '{area}': empty={empty_count}, occupied={occupied_count}, total={total_spots}, assigned_spot_no={assigned_spot_no}")
                    
                    response_content = {
                        "success": True,
                        "area": area,
                        "available": int(empty_count),
                        "available_slots": int(empty_count),
                        "empty": int(empty_count),  # Explicitly return "empty" for frontend
                        "occupied": int(occupied_count),
                        "total": int(total_spots),
                        "slot_statuses": slot_statuses_list
                    }
                    
                    # Add assigned spot number if available
                    if assigned_spot_no is not None:
                        response_content["assigned_spot_no"] = assigned_spot_no
                    
                    return JSONResponse(
                        status_code=200,
                        content=response_content
                    )
        except Exception as e:
            print(f"Warning: Error accessing frozen_analysis: {e}")
            # Continue to live camera fallback
        
        # If no frozen analysis, return message to click Confirm first
        print(f"DEBUG: No frozen_analysis found for area '{area}'. User needs to click 'Confirm' on backend first.")
        return JSONResponse(
            status_code=200,
            content={
                "success": False,
                "area": area,
                "available": 0,
                "occupied": 0,
                "empty": 0,
                "error": "Please click 'Confirm' button on backend console first to scan parking area",
                "message": "Click 'Confirm' on backend to scan parking area"
            }
        )
        
        # COMMENTED OUT: Live camera analysis removed - user must click Confirm first
        # This ensures consistent results and prevents incorrect values
        # If you want live camera, uncomment below:
        """
        # If no frozen frame, use live camera
        if cap is None or not cap.isOpened():
            return JSONResponse(
                status_code=200,
                content={
                    "success": False,
                    "area": area,
                    "available": 0,
                    "occupied": 0,
                    "empty": 0,
                    "error": "Camera not connected"
                }
            )
        
        success, frame = read_frame_safe()
        if not success or frame is None:
            return JSONResponse(
                status_code=200,
                content={
                    "success": False,
                    "area": area,
                    "available": 0,
                    "occupied": 0,
                    "empty": 0,
                    "error": "Failed to read frame"
                }
            )
        
        # Crop iVCam logo if needed
        try:
            if len(frame.shape) >= 2 and frame.shape[0] > 100:
                frame = frame[60:-40, :]
        except Exception as e:
            print(f"Error cropping frame in /api/parking/availability: {e}")
            # Continue with original frame
        
        # Validate frame after crop
        if frame is None or frame.size == 0 or len(frame.shape) < 2:
            return JSONResponse(
                status_code=200,
                content={
                    "success": False,
                    "area": area,
                    "available": 0,
                    "occupied": 0,
                    "empty": 0,
                    "error": "Invalid frame after crop"
                }
            )
        
        # Resize to match processing size
        try:
            frame = cv2.resize(frame, (960, 540))
        except Exception as e:
            print(f"Error resizing frame in /api/parking/availability: {e}")
            return JSONResponse(
                status_code=200,
                content={
                    "success": False,
                    "area": area,
                    "available": 0,
                    "occupied": 0,
                    "empty": 0,
                    "error": f"Resize error: {str(e)}"
                }
            )
        
        try:
            occupied_count, empty_count, statuses = analyze_parking(frame, area_name=area)
            slot_statuses_list = [bool(s) for s in statuses] if statuses else []
            parking_spaces = get_parking_spaces_for_area(area)
            total_spots = len(parking_spaces) if parking_spaces else 14
            
            # Debug: Print what we're returning
            print(f"DEBUG: Returning live camera analysis for area '{area}': empty={empty_count}, occupied={occupied_count}, total={total_spots}")
            
            return JSONResponse(
                status_code=200,
                content={
                    "success": True,
                    "area": area,
                    "available": int(empty_count),
                    "available_slots": int(empty_count),  # For Flutter compatibility
                    "empty": int(empty_count),  # Explicitly return "empty" for frontend
                    "occupied": int(occupied_count),
                    "total": int(total_spots),
                    "slot_statuses": slot_statuses_list
                }
            )
        """
        
    except Exception as e:
        print(f"Error in /api/parking/availability endpoint: {e}")
        import traceback
        traceback.print_exc()
        return JSONResponse(
                status_code=200,
                content={
                    "success": False,
                    "area": area,
                    "available": 0,
                    "occupied": 0,
                    "empty": 0,
                    "error": f"Analysis error: {str(e)}"
                }
            )
    except Exception as e:
        print(f"Error in /api/parking/availability/{area}: {e}")
        import traceback
        traceback.print_exc()
        return JSONResponse(
            status_code=200,
            content={
                "success": False,
                "area": area if area else "unknown",
                "available": 0,
                "occupied": 0,
                "empty": 0,
                "error": str(e)
            }
        )


@app.post("/api/parking/assign")
def assign_parking(request: AssignRequest):
    """Assign a parking spot to user (for Flutter app)."""
    try:
        area = request.area
        
        if cap is None or not cap.isOpened():
            return {
                "success": False,
                "error": "Camera not connected",
                "assigned_spot": None
            }
        
        success, frame = read_frame_safe()
        if not success or frame is None:
            return {
                "success": False,
                "error": "Failed to read frame",
                "assigned_spot": None
            }
        
        # Crop iVCam logo if needed
        if frame.shape[0] > 100:
            frame = frame[60:-40, :]
        
        if frame is None or frame.size == 0:
            return {
                "success": False,
                "error": "Invalid frame after crop",
                "assigned_spot": None
            }
        
        # Resize to match processing size
        frame = cv2.resize(frame, (960, 540))
        
        occupied_count, empty_count, statuses = analyze_parking(frame, area_name=area)
        
        # Find first available slot (indexed from 1)
        assigned_spot = None
        for i, is_occupied in enumerate(statuses):
            if not is_occupied:
                assigned_spot = str(i + 1)  # Slot numbers start from 1
                break
        
        if assigned_spot is None:
            return {
                "success": False,
                "error": "No available parking spots",
                "assigned_spot": None
            }
        
        return {
            "success": True,
            "assigned_spot": assigned_spot,
            "area": area,
            "available": empty_count,
            "occupied": occupied_count
        }
    except Exception as e:
        print(f"Error in /api/parking/assign: {e}")
        import traceback
        traceback.print_exc()
        return {
            "success": False,
            "error": str(e),
            "assigned_spot": None
        }


@app.post("/api/parking/reserve")
def reserve_parking(request: ReserveRequest):
    """Reserve a parking spot and return available parking count (for Flutter app)."""
    try:
        area = request.area
        spot_number = request.spot_number  # Spot number from frontend (the displayed one)
        
        # Priority 1: Use the spot number passed from frontend (the one displayed to user)
        # Priority 2: Use the assigned spot number from frozen_analysis (from Confirm button)
        # This ensures we ALWAYS use the same spot number that was displayed
        assigned_spot_no = None
        occupied_count = 0
        empty_count = 0
        
        # Get counts from frozen_analysis if available
        try:
            with frozen_frame_lock:
                global frozen_analysis
                if frozen_analysis is not None:
                    # frozen_analysis is a tuple: (occupied_count, empty_count, statuses, assigned_spot_no)
                    if len(frozen_analysis) == 4:
                        occupied_count, empty_count, _, frozen_assigned_spot = frozen_analysis
                    else:
                        # Backward compatibility
                        occupied_count, empty_count, statuses = frozen_analysis[:3]
                        frozen_assigned_spot = None
                        # Calculate assigned spot if not stored
                        for i, is_occupied in enumerate(statuses):
                            if not is_occupied:
                                frozen_assigned_spot = str(i + 1)
                                break
                    
                    # Priority 1: Use spot number from frontend (the displayed one)
                    if spot_number and spot_number.strip():
                        assigned_spot_no = spot_number.strip()
                        print(f"DEBUG: Using spot number from frontend (displayed): {assigned_spot_no}")
                    # Priority 2: Use spot number from frozen_analysis
                    elif frozen_assigned_spot:
                        assigned_spot_no = frozen_assigned_spot
                        print(f"DEBUG: Using assigned spot from frozen_analysis: {assigned_spot_no}")
        except Exception as e:
            print(f"Warning: Error accessing frozen_analysis in /api/parking/reserve: {e}")
            # Continue to fallback analysis
        
        # If still no spot number, do a fresh analysis (fallback - should not happen in normal flow)
        if assigned_spot_no is None:
            print("DEBUG: No frozen_analysis found, doing fresh analysis")
            if cap is None or not cap.isOpened():
                return {
                    "success": False,
                    "error": "Camera not connected. Please click 'Confirm' on backend console first.",
                    "available": 0,
                    "empty": 0
                }
            
            success, frame = read_frame_safe()
            if not success or frame is None:
                return {
                    "success": False,
                    "error": "Failed to read frame. Please click 'Confirm' on backend console first.",
                    "available": 0,
                    "empty": 0
                }
            
            # Crop iVCam logo if needed
            if frame.shape[0] > 100:
                frame = frame[60:-40, :]
            
            if frame is None or frame.size == 0:
                return {
                    "success": False,
                    "error": "Invalid frame after crop",
                    "available": 0,
                    "empty": 0
                }
            
            # Resize to match processing size
            frame = cv2.resize(frame, (960, 540))
            
            # Get parking status
            occupied_count, empty_count, statuses = analyze_parking(frame, area_name=area)
            
            # Auto-assign first available parking spot number (1-14)
            for i, is_occupied in enumerate(statuses):
                if not is_occupied:
                    assigned_spot_no = str(i + 1)  # Spot numbers start from 1
                    break
        
        return {
            "success": True,
            "message": f"Parking status updated for {area}",
            "area": area,
            "available": empty_count,
            "empty": empty_count,  # Backend returns "empty", frontend displays as "available"
            "occupied": occupied_count,
            "total": len(get_parking_spaces_for_area(area)) if get_parking_spaces_for_area(area) else 14,
            "assigned_spot_no": assigned_spot_no  # Use the spot number from frozen_analysis (same as displayed)
        }
    except Exception as e:
        print(f"Error in /api/parking/reserve: {e}")
        import traceback
        traceback.print_exc()
        return {
            "success": False,
            "error": str(e),
            "available": 0,
            "empty": 0
        }


@app.get("/status")
def status():
    """Get current parking status counts."""
    try:
        # Check if we have frozen analysis results first (from confirm button)
        try:
            with frozen_frame_lock:
                global frozen_analysis
                if frozen_analysis is not None:
                    # Use stored analysis results from when confirm was clicked
                    # frozen_analysis is a tuple: (occupied_count, empty_count, statuses, assigned_spot_no)
                    if len(frozen_analysis) == 4:
                        occupied_count, empty_count, _, assigned_spot_no = frozen_analysis
                    else:
                        occupied_count, empty_count, _ = frozen_analysis[:3]
                        assigned_spot_no = None
                    
                    result = {
                        "occupied": occupied_count, 
                        "empty": empty_count,
                        "available": empty_count  # Available parking is same as empty
                    }
                    
                    # Add assigned spot number if available
                    if assigned_spot_no is not None:
                        result["assigned_spot_no"] = assigned_spot_no
                    
                    return result
        except Exception as e:
            print(f"Warning: Error accessing frozen_analysis in /status: {e}")
            # Continue to live camera fallback
        
        # If no frozen frame, use live camera
        if cap is None or not cap.isOpened():
            return {"occupied": 0, "empty": 0, "available": 0, "error": "Camera not connected"}
        
        success, frame = read_frame_safe()
        if not success or frame is None:
            return {"occupied": 0, "empty": 0, "available": 0, "error": "Failed to read frame"}
        
        # Crop iVCam logo if needed
        try:
            if len(frame.shape) >= 2 and frame.shape[0] > 100:
                frame = frame[60:-40, :]
        except Exception as e:
            print(f"Error cropping frame in /status: {e}")
            # Continue with original frame
        
        # Validate frame after crop
        if frame is None or frame.size == 0 or len(frame.shape) < 2:
            return {"occupied": 0, "empty": 0, "available": 0, "error": "Invalid frame after crop"}
        
        # Resize to match processing size
        try:
            frame = cv2.resize(frame, (960, 540))
        except Exception as e:
            print(f"Error resizing frame in /status: {e}")
            return {"occupied": 0, "empty": 0, "available": 0, "error": f"Resize error: {str(e)}"}
        
        try:
            occupied_count, empty_count, _ = analyze_parking(frame)
            return {
                "occupied": occupied_count, 
                "empty": empty_count,
                "available": empty_count  # Available parking is same as empty
            }
        except Exception as e:
            print(f"Error analyzing parking in /status: {e}")
            import traceback
            traceback.print_exc()
            return {"occupied": 0, "empty": 0, "available": 0, "error": f"Analysis error: {str(e)}"}
    except Exception as e:
        print(f"Error in /status endpoint: {e}")
        import traceback
        traceback.print_exc()
        return {"occupied": 0, "empty": 0, "available": 0, "error": str(e)}


@app.post("/confirm")
def confirm():
    """Confirm and return parking status for frontend."""
    try:
        if cap is None or not cap.isOpened():
            return {
                "success": False,
                "occupied": 0, 
                "empty": 0, 
                "available": 0,
                "error": "Camera not connected"
            }
        
        success, frame = read_frame_safe()
        if not success or frame is None:
            return {
                "success": False,
                "occupied": 0, 
                "empty": 0, 
                "available": 0,
                "error": "Failed to read frame"
            }
        
        # Crop iVCam logo if needed
        try:
            if len(frame.shape) >= 2 and frame.shape[0] > 100:
                frame = frame[60:-40, :]
        except Exception as e:
            print(f"Error cropping frame in /confirm: {e}")
            # Continue with original frame
        
        # Validate frame after crop
        if frame is None or frame.size == 0 or len(frame.shape) < 2:
            return {
                "success": False,
                "occupied": 0, 
                "empty": 0, 
                "available": 0,
                "error": "Invalid frame after crop"
            }
        
        # Resize to match processing size
        try:
            frame = cv2.resize(frame, (960, 540))
        except Exception as e:
            print(f"Error resizing frame in /confirm: {e}")
            return {
                "success": False,
                "occupied": 0, 
                "empty": 0, 
                "available": 0,
                "error": f"Resize error: {str(e)}"
            }
        
        # Store raw frame before processing
        raw_frame = frame.copy()
        
        # Analyze parking before processing for display
        try:
            occupied_count, empty_count, statuses = analyze_parking(frame)
        except Exception as e:
            print(f"Error analyzing parking in /confirm: {e}")
            import traceback
            traceback.print_exc()
            return {
                "success": False,
                "occupied": 0, 
                "empty": 0, 
                "available": 0,
                "error": f"Analysis error: {str(e)}"
            }
        
        # Freeze the frame (store both raw and processed versions)
        try:
            processed_frame = detect_parking(frame.copy())  # Frame with detection overlays
        except Exception as e:
            print(f"Error in detect_parking in /confirm: {e}")
            import traceback
            traceback.print_exc()
            # Use original frame if detection fails
            processed_frame = frame.copy()
        
        # Auto-assign first available parking spot number (1-14)
        assigned_spot_no = None
        for i, is_occupied in enumerate(statuses):
            if not is_occupied:
                assigned_spot_no = str(i + 1)  # Spot numbers start from 1
                break
        
        try:
            with frozen_frame_lock:
                global frozen_frame, frozen_raw_frame, frozen_analysis
                frozen_frame = processed_frame.copy()  # For display
                frozen_raw_frame = raw_frame.copy()  # For re-analysis if needed
                frozen_analysis = (occupied_count, empty_count, statuses, assigned_spot_no)  # Store analysis results including assigned spot
        except Exception as e:
            print(f"Error storing frozen frame in /confirm: {e}")
            # Continue even if storage fails
        
        # Ensure all values are JSON-serializable
        slot_statuses_list = [bool(s) for s in statuses] if statuses else []
        return JSONResponse(
            status_code=200,
            content={
                "success": True,
                "occupied": int(occupied_count), 
                "empty": int(empty_count),
                "available": int(empty_count),  # Available parking spots
                "total": int(len(PARKING_SPACES)),
                "slot_statuses": slot_statuses_list,  # Detailed status per slot (True=occupied, False=empty)
                "assigned_spot_no": assigned_spot_no  # Auto-assigned spot number (1-14) or None if no spots available
            }
        )
    except Exception as e:
        print(f"Error in /confirm endpoint: {e}")
        import traceback
        traceback.print_exc()
        return JSONResponse(
            status_code=200,
            content={
                "success": False,
                "occupied": 0, 
                "empty": 0, 
                "available": 0,
                "error": str(e)
            }
        )


@app.get("/", response_class=HTMLResponse)
def index():
    """Home page with multiple backend function modules."""
    return """
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Console - Backend Services</title>
        <style>
            * {
                margin: 0;
                padding: 0;
                box-sizing: border-box;
            }
            body {
                font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
                background: #f5f5f5;
            }
            .header {
                background: #4E6691;
                color: white;
                padding: 20px 40px;
                box-shadow: 0 2px 8px rgba(0,0,0,0.1);
            }
            .header h1 {
                font-size: 28px;
                font-weight: 600;
            }
            .main-content {
                max-width: 1200px;
                margin: 60px auto;
                padding: 0 40px;
            }
            .modules-container {
                display: flex;
                justify-content: center;
                align-items: center;
                gap: 40px;
                flex-wrap: wrap;
            }
            .module-card {
                background: white;
                border-radius: 16px;
                padding: 40px;
                text-align: center;
                cursor: pointer;
                transition: all 0.3s ease;
                box-shadow: 0 4px 12px rgba(0,0,0,0.1);
                width: 280px;
                text-decoration: none;
                color: inherit;
                display: block;
            }
            .module-card:hover {
                transform: translateY(-8px);
                box-shadow: 0 8px 24px rgba(0,0,0,0.15);
            }
            .module-icon {
                width: 120px;
                height: 120px;
                background: #E9F4FF;
                border-radius: 16px;
                display: flex;
                align-items: center;
                justify-content: center;
                margin: 0 auto 24px;
                font-size: 60px;
            }
            .module-icon img {
                width: 80px;
                height: 80px;
                object-fit: contain;
            }
            .module-title {
                font-size: 18px;
                font-weight: 600;
                color: #333;
                margin-top: 16px;
            }
        </style>
    </head>
    <body>
        <div class="header">
            <h1>Console</h1>
        </div>
        <div class="main-content">
            <div class="modules-container">
                <a href="/console" class="module-card">
                    <div class="module-icon">
                        <img src="/assets/parking_logo.png" alt="Parking Spot Detector">
                    </div>
                    <div class="module-title">Parking Spot Detector</div>
                </a>
                <a href="/visitor-qr" class="module-card">
                    <div class="module-icon">
                        <img src="/assets/visitor_logo.png" alt="QR Code Detector">
                    </div>
                    <div class="module-title">QR Code Detector</div>
                </a>
                <a href="/car-plate" class="module-card">
                    <div class="module-icon">
                        <img src="/assets/scan_logo.png" alt="Car Plate Detector">
                    </div>
                    <div class="module-title">Car Plate Detector</div>
                </a>
            </div>
        </div>
    </body>
    </html>
    """

@app.get("/console", response_class=HTMLResponse)
def console():
    """Parking Spot Detector console page."""
    return """
    <html>
        <head>
            <title>🚗 Real-Time Parking Detection</title>
            <style>
                * {
                    margin: 0;
                    padding: 0;
                    box-sizing: border-box;
                }
                body { 
                    font-family: 'Segoe UI', Arial, sans-serif; 
                    background: #f5f5f5; 
                    margin: 0;
                }
                .header {
                    background: #4E6691;
                    color: white;
                    padding: 16px 20px;
                    display: flex;
                    align-items: center;
                    gap: 12px;
                }
                .back-arrow {
                    cursor: pointer;
                    font-size: 24px;
                    color: white;
                    text-decoration: none;
                }
                .header-title {
                    font-size: 20px;
                    font-weight: 600;
                }
                .main-container {
                    display: flex;
                    gap: 12px;
                    max-width: 1600px;
                    margin: 20px auto;
                    padding: 0 20px;
                    align-items: flex-start;
                }
                .video-container {
                    flex: 1;
                    min-width: 0;
                }
                img {
                    width: 100%%;
                    height: auto;
                    border-radius: 12px;
                    box-shadow: 0px 4px 20px rgba(0,0,0,0.2);
                    display: block;
                }
                .status-container {
                    background: white;
                    border-radius: 12px;
                    padding: 30px 40px;
                    box-shadow: 0px 4px 15px rgba(0,0,0,0.1);
                    width: 350px;
                    flex-shrink: 0;
                }
                .status-row {
                    display: flex;
                    justify-content: space-between;
                    align-items: center;
                    padding: 15px 0;
                    border-bottom: 1px solid #e0e0e0;
                }
                .status-row:last-child {
                    border-bottom: none;
                }
                .status-label {
                    font-size: 20px;
                    font-weight: 600;
                    color: #555;
                }
                .status-value {
                    font-size: 28px;
                    font-weight: bold;
                    padding: 5px 15px;
                    border-radius: 8px;
                }
                .occupied-label { color: #d32f2f; }
                .occupied-value { 
                    background: #ffebee; 
                    color: #c62828; 
                }
                .empty-label { color: #388e3c; }
                .empty-value { 
                    background: #e8f5e9; 
                    color: #2e7d32; 
                }
                .confirm-btn {
                    background: #4E6691;
                    color: white;
                    border: none;
                    padding: 15px 50px;
                    font-size: 18px;
                    font-weight: bold;
                    border-radius: 8px;
                    cursor: pointer;
                    box-shadow: 0px 4px 10px rgba(78, 102, 145, 0.3);
                    transition: all 0.3s;
                    margin: 20px auto 0;
                    display: block;
                }
                .confirm-btn:hover {
                    background: #3d5474;
                    transform: translateY(-2px);
                    box-shadow: 0px 6px 15px rgba(78, 102, 145, 0.4);
                }
                .confirm-btn:active {
                    transform: translateY(0);
                }
                .confirm-btn:disabled {
                    opacity: 0.6;
                    cursor: not-allowed;
                }
                .result-message {
                    margin-top: 15px;
                    padding: 12px;
                    border-radius: 8px;
                    font-weight: 500;
                    font-size: 14px;
                    display: none;
                    text-align: center;
                }
                .result-success {
                    background: #e8f5e9;
                    color: #2e7d32;
                    border: 2px solid #4caf50;
                }
                .result-error {
                    background: #ffebee;
                    color: #c62828;
                    border: 2px solid #f44336;
                }
                @media (max-width: 1024px) {
                    .main-container {
                        flex-direction: column;
                    }
                    .status-container {
                        width: 100%%;
                    }
                }
            </style>
            <script>
                async function updateStatus() {
                    try {
                        const response = await fetch('/status');
                        if (!response.ok) {
                            throw new Error(`HTTP error! status: ${response.status}`);
                        }
                        const text = await response.text();
                        let data;
                        try {
                            data = JSON.parse(text);
                        } catch (e) {
                            console.error('Invalid JSON response:', text.substring(0, 100));
                            throw new Error('Invalid response from server');
                        }
                        document.getElementById('occupied-value').textContent = data.occupied || 0;
                        document.getElementById('empty-value').textContent = data.empty || 0;
                    } catch (error) {
                        console.error('Failed to fetch status:', error);
                        document.getElementById('occupied-value').textContent = '-';
                        document.getElementById('empty-value').textContent = '-';
                    }
                }
                
                async function confirmParking() {
                    const btn = document.getElementById('confirmBtn');
                    const msg = document.getElementById('resultMsg');
                    btn.disabled = true;
                    btn.textContent = 'Processing...';
                    msg.style.display = 'none';
                    
                    try {
                        const response = await fetch('/confirm', {
                            method: 'POST',
                            headers: {
                                'Content-Type': 'application/json'
                            }
                        });
                        
                        if (!response.ok) {
                            throw new Error(`HTTP error! status: ${response.status}`);
                        }
                        
                        const text = await response.text();
                        let data;
                        try {
                            data = JSON.parse(text);
                        } catch (e) {
                            console.error('Invalid JSON response:', text.substring(0, 100));
                            throw new Error('Server returned invalid response. Check console for details.');
                        }
                        
                        if (data.success) {
                            msg.className = 'result-message result-success';
                            msg.innerHTML = `✓ Confirmed!<br>Occupied: ${data.occupied} | Available: ${data.available}`;
                            msg.style.display = 'block';
                            console.log('Parking Status:', data);
                        } else {
                            msg.className = 'result-message result-error';
                            msg.textContent = 'Error: ' + (data.error || 'Unknown error');
                            msg.style.display = 'block';
                        }
                    } catch (error) {
                        msg.className = 'result-message result-error';
                        msg.textContent = 'Error: ' + error.message;
                        msg.style.display = 'block';
                    } finally {
                        btn.disabled = false;
                        btn.textContent = 'Confirm';
                    }
                }
                
                async function resetCamera() {
                    try {
                        await fetch('/reset-camera', {
                            method: 'POST',
                            headers: {'Content-Type': 'application/json'}
                        });
                        console.log('Camera feed restarted');
                    } catch (error) {
                        console.error('Failed to reset camera:', error);
                    }
                }
                
                // Reset camera on page load/refresh
                window.addEventListener('load', function() {
                    resetCamera();
                });
                
                // Update status every 2 seconds
                setInterval(updateStatus, 2000);
                // Initial update
                updateStatus();
            </script>
        </head>
        <body>
            <div class="header">
                <a href="/" class="back-arrow">←</a>
                <div class="header-title">Parking Spot Detector</div>
            </div>
            <div class="main-container">
                <div class="video-container">
                    <img src="/video_feed" alt="Parking lot video feed">
                </div>
                <div class="status-container">
                    <div class="status-row">
                        <span class="status-label occupied-label">Occupied:</span>
                        <span class="status-value occupied-value" id="occupied-value">-</span>
                    </div>
                    <div class="status-row">
                        <span class="status-label empty-label">Empty:</span>
                        <span class="status-value empty-value" id="empty-value">-</span>
                    </div>
                    <button class="confirm-btn" id="confirmBtn" onclick="confirmParking()">Confirm</button>
                    <div class="result-message" id="resultMsg"></div>
                </div>
            </div>
        </body>
    </html>
    """


# === Visitor QR Code Detection Variables ===
visitor_qr_camera = None
visitor_qr_camera_index = None
visitor_qr_camera_lock = threading.Lock()
scanned_qr_codes = {}  # Store scanned QR codes to prevent duplicate processing
scanned_qr_lock = threading.Lock()

def init_visitor_qr_camera():
    """Initialize camera for visitor QR code scanning."""
    global visitor_qr_camera, visitor_qr_camera_index
    # Try to use same camera as parking detection, or try different index
    for idx in [0, 1, 2]:
        try:
            test_cap = cv2.VideoCapture(idx, cv2.CAP_DSHOW)
            if test_cap.isOpened():
                ret, _ = test_cap.read()
                if ret:
                    test_cap.set(cv2.CAP_PROP_FRAME_WIDTH, 1280)
                    test_cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 720)
                    visitor_qr_camera = test_cap
                    visitor_qr_camera_index = idx
                    print(f"Visitor QR camera connected (index: {idx})")
                    return True
                test_cap.release()
        except Exception as e:
            print(f"Error testing camera {idx}: {e}")
            continue
    print("Warning: Could not initialize visitor QR camera")
    return False

# Initialize visitor QR camera
init_visitor_qr_camera()

def detect_qr_code(frame):
    """Detect QR codes in frame using ZBar (pyzbar) as primary, OpenCV as fallback."""
    try:
        # Try ZBar first (more accurate)
        if ZBAR_AVAILABLE and ZBAR_DECODE is not None:
            try:
                # Convert BGR to RGB for pyzbar
                rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
                decoded_objects = ZBAR_DECODE(rgb_frame)
                
                if decoded_objects:
                    # Return first QR code found
                    qr_data = decoded_objects[0].data.decode('utf-8')
                    # Get bounding box points
                    points = decoded_objects[0].polygon
                    if points:
                        # Convert to numpy array format
                        pts = np.array([(p.x, p.y) for p in points], dtype=np.int32)
                        return qr_data, pts
                    return qr_data, None
            except Exception as zbar_error:
                print(f"ZBar detection error: {zbar_error}, falling back to OpenCV")
        
        # Fallback to OpenCV QRCodeDetector
        detector = cv2.QRCodeDetector()
        retval, decoded_info, points, straight_qrcode = detector.detectAndDecodeMulti(frame)
        
        if retval and decoded_info:
            # Return first detected QR code
            for i, data in enumerate(decoded_info):
                if data:  # Non-empty QR code data
                    return data, points[i] if points is not None and i < len(points) else None
        return None, None
    except Exception as e:
        print(f"Error detecting QR code: {e}")
        traceback.print_exc()
        return None, None

def generate_visitor_qr_frames():
    """Generate video stream with QR code detection overlay."""
    if visitor_qr_camera is None or not visitor_qr_camera.isOpened():
        error_frame = np.zeros((480, 640, 3), dtype=np.uint8)
        cv2.putText(error_frame, "Camera not connected!", (50, 240),
                    cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 0, 255), 2)
        ret, buffer = cv2.imencode('.jpg', error_frame)
        if ret:
            yield (b'--frame\r\n'
                   b'Content-Type: image/jpeg\r\n\r\n' + buffer.tobytes() + b'\r\n')
        return
    
    while True:
        try:
            with visitor_qr_camera_lock:
                if visitor_qr_camera is None or not visitor_qr_camera.isOpened():
                    break
                success, frame = visitor_qr_camera.read()
                if not success or frame is None:
                    break
                
                # Crop out iVCam logo if present
                if frame.shape[0] > 100:
                    frame = frame[60:-40, :]
                
                # Resize for display
                display_frame = cv2.resize(frame.copy(), (960, 540))
                
                # Detect QR code
                qr_data, qr_points = detect_qr_code(frame)
                
                if qr_data:
                    # Draw QR code bounding box
                    if qr_points is not None:
                        pts = qr_points.astype(int)
                        # Scale points to display size
                        scale_x = 960 / frame.shape[1]
                        scale_y = 540 / frame.shape[0]
                        pts_scaled = (pts * [scale_x, scale_y]).astype(int)
                        cv2.polylines(display_frame, [pts_scaled], True, (0, 255, 0), 3)
                    
                    # Display QR code data
                    cv2.putText(display_frame, f"QR: {qr_data}", (10, 30),
                               cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)
                    
                    # Update last scanned QR for API access (detection only, no auto-processing)
                    current_time = time.time()
                    with scanned_qr_lock:
                        if qr_data not in scanned_qr_codes or (current_time - scanned_qr_codes[qr_data]) > 5:
                            # New QR code or old one (>5 seconds), update for display
                            scanned_qr_codes[qr_data] = current_time
                            # Update last scanned QR for API access
                            with last_scanned_qr_lock:
                                global last_scanned_qr, last_scanned_qr_time
                                last_scanned_qr = qr_data
                                last_scanned_qr_time = current_time
            
            # Encode frame
            ret, buffer = cv2.imencode('.jpg', display_frame)
            if not ret:
                continue
            yield (b'--frame\r\n'
                   b'Content-Type: image/jpeg\r\n\r\n' + buffer.tobytes() + b'\r\n')
            
            time.sleep(0.033)  # ~30 FPS
        except Exception as e:
            print(f"Error in visitor QR frame generation: {e}")
            break

@app.get("/visitor-qr", response_class=HTMLResponse)
def visitor_qr():
    """Visitor QR code Detector page."""
    return """
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Visitor QR Code Detector</title>
        <style>
            * {
                margin: 0;
                padding: 0;
                box-sizing: border-box;
            }
            body {
                font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
                background: #f5f5f5;
                margin: 0;
            }
            .header {
                background: #4E6691;
                color: white;
                padding: 16px 20px;
                display: flex;
                align-items: center;
                gap: 12px;
            }
            .back-arrow {
                cursor: pointer;
                font-size: 24px;
                color: white;
                text-decoration: none;
            }
            .header-title {
                font-size: 20px;
                font-weight: 600;
            }
            .container {
                max-width: 1200px;
                margin: 20px auto;
                padding: 0 20px;
                background: white;
                padding: 20px;
                border-radius: 12px;
                box-shadow: 0 2px 8px rgba(0,0,0,0.1);
            }
            .video-container {
                text-align: center;
                margin: 20px 0;
            }
            .video-stream {
                max-width: 100%;
                border: 2px solid #ddd;
                border-radius: 8px;
            }
            .controls {
                margin: 20px 0;
                text-align: center;
            }
            .status {
                padding: 10px;
                margin: 10px 0;
                border-radius: 4px;
                background: #e3f2fd;
                color: #1976d2;
            }
            .scan-success {
                background: #c8e6c9;
                color: #2e7d32;
            }
            .scan-error {
                background: #ffcdd2;
                color: #c62828;
            }
            button {
                padding: 10px 20px;
                font-size: 16px;
                background: #4E6691;
                color: white;
                border: none;
                border-radius: 4px;
                cursor: pointer;
                transition: all 0.3s;
            }
            button:hover {
                background: #3d5474;
            }
            button:disabled {
                background: #9e9e9e;
                cursor: not-allowed;
            }
        </style>
    </head>
    <body>
        <div class="header">
            <a href="/" class="back-arrow">←</a>
            <div class="header-title">Visitor QR Code Detector</div>
        </div>
        <div class="container">
            <div class="video-container">
                <img src="/visitor_qr_video_feed" class="video-stream" alt="QR Code Scanner">
            </div>
            <div id="status" class="status">Point camera at QR code to scan...</div>
            <div class="controls">
                <button id="approveBtn" onclick="approveVisitor()">Approve</button>
            </div>
        </div>
        <script>
            function checkQRStatus() {
                fetch('/api/visitor/check-scan')
                    .then(response => response.json())
                    .then(data => {
                        const statusDiv = document.getElementById('status');
                        const approveBtn = document.getElementById('approveBtn');
                        if (data.success && data.scanned) {
                            statusDiv.textContent = 'QR Code detected: ' + data.qr_code + ' - Ready for approval';
                            statusDiv.className = 'status scan-success';
                            approveBtn.disabled = false;
                        } else {
                            statusDiv.textContent = 'No QR code detected. Point camera at QR code.';
                            statusDiv.className = 'status';
                            approveBtn.disabled = true;
                        }
                    })
                    .catch(error => {
                        console.error('Error:', error);
                    });
            }
            
            function approveVisitor() {
                const approveBtn = document.getElementById('approveBtn');
                const statusDiv = document.getElementById('status');
                
                // Disable button during processing
                approveBtn.disabled = true;
                approveBtn.textContent = 'Processing...';
                
                fetch('/api/visitor/check-scan')
                    .then(response => response.json())
                    .then(data => {
                        if (data.success && data.scanned && data.qr_code) {
                            // Approve the visitor
                            return fetch('/api/visitor/approve', {
                                method: 'POST',
                                headers: {
                                    'Content-Type': 'application/json'
                                },
                                body: JSON.stringify({ qr_code: data.qr_code })
                            });
                        } else {
                            throw new Error('No QR code detected. Please scan a QR code first.');
                        }
                    })
                    .then(response => response.json())
                    .then(result => {
                        const statusDiv = document.getElementById('status');
                        if (result.success) {
                            statusDiv.textContent = 'Visitor approved successfully! ' + result.qr_code + ' - Status updated to History.';
                            statusDiv.className = 'status scan-success';
                            // Reset button after 2 seconds
                            setTimeout(() => {
                                approveBtn.disabled = false;
                                approveBtn.textContent = 'Approve';
                            }, 2000);
                        } else {
                            statusDiv.textContent = 'Error: ' + (result.message || result.error || 'Failed to approve visitor');
                            statusDiv.className = 'status scan-error';
                            approveBtn.disabled = false;
                            approveBtn.textContent = 'Approve';
                        }
                    })
                    .catch(error => {
                        console.error('Error:', error);
                        const statusDiv = document.getElementById('status');
                        statusDiv.textContent = 'Error: ' + error.message;
                        statusDiv.className = 'status scan-error';
                        approveBtn.disabled = false;
                        approveBtn.textContent = 'Approve';
                    });
            }
            
            // Auto-check every 2 seconds
            setInterval(checkQRStatus, 2000);
        </script>
    </body>
    </html>
    """


# === Car Plate Detection Variables ===
car_plate_camera = None
car_plate_camera_index = None
car_plate_camera_lock = threading.Lock()
last_detected_plate = None
last_detected_plate_time = 0
last_detected_plate_lock = threading.Lock()

def init_car_plate_camera():
    """Initialize camera for car plate scanning."""
    global car_plate_camera, car_plate_camera_index
    print("[Car Plate Camera] Initializing camera...")
    
    # If camera is already initialized and working, don't reinitialize
    if car_plate_camera is not None and car_plate_camera.isOpened():
        try:
            # Test if we can read a frame
            ret, _ = car_plate_camera.read()
            if ret:
                print(f"[Car Plate Camera] Camera already initialized and working (index: {car_plate_camera_index})")
                return True
        except:
            pass
    
    # Try to use same camera as parking detection first (share the camera object)
    if cap is not None and cap.isOpened():
        try:
            # Test if we can read from it
            ret, _ = cap.read()
            if ret:
                car_plate_camera = cap
                car_plate_camera_index = camera_index
                print(f"[Car Plate Camera] ✓ Using same camera as parking detection (index: {camera_index})")
                return True
        except Exception as e:
            print(f"[Car Plate Camera] Parking camera exists but error reading: {e}")
    
    # Otherwise, try to find a camera
    print("[Car Plate Camera] Searching for available camera...")
    for idx in [0, 1, 2]:
        try:
            print(f"[Car Plate Camera] Trying camera index {idx}...")
            test_cap = cv2.VideoCapture(idx, cv2.CAP_DSHOW)
            if test_cap.isOpened():
                ret, test_frame = test_cap.read()
                if ret and test_frame is not None:
                    test_cap.set(cv2.CAP_PROP_FRAME_WIDTH, 1280)
                    test_cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 720)
                    # Release old camera if exists
                    if car_plate_camera is not None:
                        try:
                            car_plate_camera.release()
                        except:
                            pass
                    car_plate_camera = test_cap
                    car_plate_camera_index = idx
                    print(f"[Car Plate Camera] ✓ Camera connected successfully (index: {idx})")
                    return True
                else:
                    print(f"[Car Plate Camera] Camera {idx} opened but failed to read frame")
                    test_cap.release()
            else:
                print(f"[Car Plate Camera] Camera {idx} could not be opened")
        except Exception as e:
            print(f"[Car Plate Camera] Error testing camera {idx}: {e}")
            continue
    
    print("[Car Plate Camera] ✗ WARNING: Could not initialize car plate camera")
    print("[Car Plate Camera] Make sure iVCam is running and connected")
    return False

# Initialize car plate camera (lazy - will initialize when video feed is accessed)
# Don't initialize at startup to avoid conflicts
print("[Car Plate Camera] Camera will be initialized when video feed is accessed")

def detect_car_plate(frame):
    """Detect car plate number from frame using EasyOCR."""
    global easyocr_reader, EASYOCR_AVAILABLE, easyocr_init_error
    try:
        # Lazy initialization - try to load EasyOCR if not already loaded
        if easyocr_reader is None:
            print("[Car Plate Detection] EasyOCR not initialized, attempting to load...")
            easyocr_reader, EASYOCR_AVAILABLE = _try_load_easyocr()
        
        if not EASYOCR_AVAILABLE or easyocr_reader is None:
            error_msg = easyocr_init_error or "EasyOCR not available"
            print(f"[Car Plate Detection] {error_msg}")
            return None
        
        # Try multiple preprocessing methods - start with original frame first
        images_to_try = []
        
        # 1. Original frame (try this first - often works best)
        images_to_try.append(("original", frame))
        
        # 2. Grayscale
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        images_to_try.append(("grayscale", gray))
        
        # 3. Enhanced contrast (CLAHE)
        clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8,8))
        enhanced = clahe.apply(gray)
        images_to_try.append(("enhanced", enhanced))
        
        # 4. Thresholded
        _, thresh = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
        images_to_try.append(("threshold", thresh))
        
        # 5. Adaptive threshold
        adaptive_thresh = cv2.adaptiveThreshold(gray, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, cv2.THRESH_BINARY, 11, 2)
        images_to_try.append(("adaptive", adaptive_thresh))
        
        all_candidates = []
        
        # Try OCR on each preprocessed image
        for method_name, img in images_to_try:
            try:
                results = easyocr_reader.readtext(img, paragraph=False)
                print(f"[Car Plate Detection] Method: {method_name}, Found {len(results)} text regions")
                
                for (bbox, text, confidence) in results:
                    # Keep original text for display, but also create cleaned version
                    original_text = text.strip().upper()
                    # Clean text: keep only alphanumeric and spaces
                    cleaned_text = ''.join(c.upper() if c.isalnum() or c.isspace() else '' for c in text).strip()
                    # Remove extra spaces
                    cleaned_text = ' '.join(cleaned_text.split())
                    
                    # Debug: print ALL detected text
                    print(f"  - Detected: '{text}' -> '{cleaned_text}' (confidence: {confidence:.3f})")
                    
                    # Very permissive: accept ANY text that has both letters AND numbers
                    # This is the key requirement for license plates
                    has_letter = any(c.isalpha() for c in cleaned_text)
                    has_digit = any(c.isdigit() for c in cleaned_text)
                    
                    # Accept if it has both letters and numbers (license plate requirement)
                    if has_letter and has_digit:
                        # Accept text with 3-12 characters (very permissive)
                        if len(cleaned_text.replace(' ', '')) >= 3 and len(cleaned_text.replace(' ', '')) <= 12:
                            # Accept with very low confidence threshold (0.1)
                            if confidence > 0.1:
                                all_candidates.append((cleaned_text, confidence, method_name, original_text))
                                print(f"    ✓ ACCEPTED: '{cleaned_text}' (confidence: {confidence:.3f}, method: {method_name})")
            except Exception as e:
                print(f"Error processing {method_name} image: {e}")
                traceback.print_exc()
                continue
        
        # Return the highest confidence result
        if all_candidates:
            # Sort by confidence (highest first)
            all_candidates.sort(key=lambda x: x[1], reverse=True)
            detected_plate, confidence, method, original = all_candidates[0]
            print(f"[Car Plate Detection] ✓ SUCCESS! Selected: '{detected_plate}' (confidence: {confidence:.3f}, method: {method})")
            
            # Format the plate nicely: "ABC 1234" style
            # Remove all spaces first
            plate_no_spaces = detected_plate.replace(' ', '').replace('-', '')
            
            # Try to format as "ABC 1234" if it has at least 6 characters
            if len(plate_no_spaces) >= 6:
                # Check if first 3 are letters and rest are numbers
                if plate_no_spaces[:3].isalpha() and plate_no_spaces[3:].isdigit():
                    formatted = plate_no_spaces[:3] + ' ' + plate_no_spaces[3:]
                    return formatted
                # Or try to split at any point where letters end and numbers begin
                for i in range(2, min(5, len(plate_no_spaces))):
                    if plate_no_spaces[:i].isalpha() and plate_no_spaces[i:].isdigit():
                        formatted = plate_no_spaces[:i] + ' ' + plate_no_spaces[i:]
                        return formatted
            
            # If formatting doesn't work, return the cleaned text as-is
            return detected_plate
        else:
            print("[Car Plate Detection] ✗ FAILED: No text with both letters AND numbers found")
            print("[Car Plate Detection] Make sure the plate is clearly visible with both letters and numbers")
            return None
            
    except Exception as e:
        print(f"Error detecting car plate: {e}")
        traceback.print_exc()
        return None

def generate_car_plate_frames():
    """Generate video stream with car plate detection overlay."""
    print("[Car Plate Video Feed] Video feed requested, initializing camera...")
    # Try to initialize camera if not available
    if car_plate_camera is None or not car_plate_camera.isOpened():
        print("[Car Plate Video Feed] Camera not available, attempting to initialize...")
        init_car_plate_camera()
    
    if car_plate_camera is None or not car_plate_camera.isOpened():
        error_frame = np.zeros((480, 640, 3), dtype=np.uint8)
        cv2.putText(error_frame, "Camera not connected!", (50, 200),
                    cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 0, 255), 2)
        cv2.putText(error_frame, "Ensure iVCam is running", (30, 250),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 0, 255), 2)
        ret, buffer = cv2.imencode('.jpg', error_frame)
        if ret:
            yield (b'--frame\r\n'
                   b'Content-Type: image/jpeg\r\n\r\n' + buffer.tobytes() + b'\r\n')
        # Keep streaming error frame
        while True:
            time.sleep(1)
            ret, buffer = cv2.imencode('.jpg', error_frame)
            if ret:
                yield (b'--frame\r\n'
                       b'Content-Type: image/jpeg\r\n\r\n' + buffer.tobytes() + b'\r\n')
        return
    
    while True:
        try:
            with car_plate_camera_lock:
                if car_plate_camera is None or not car_plate_camera.isOpened():
                    # Try to reinitialize
                    init_car_plate_camera()
                    if car_plate_camera is None or not car_plate_camera.isOpened():
                        time.sleep(0.1)
                        continue
                
                success, frame = car_plate_camera.read()
                if not success or frame is None:
                    print("[Car Plate Video Feed] Failed to read frame, retrying...")
                    time.sleep(0.1)
                    continue
                
                # Crop out iVCam logo if present
                if frame.shape[0] > 100:
                    frame = frame[60:-40, :]
                
                # Resize for display
                display_frame = cv2.resize(frame.copy(), (960, 540))
                
                # Don't run OCR on every frame - it's too slow
                # Only show the camera feed, OCR will run when scan button is clicked
                # Draw instruction text on frame
                cv2.putText(display_frame, "Point camera at car plate", (10, 30),
                           cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 2)
                cv2.putText(display_frame, "Click 'Scan Car Plate' to detect", (10, 60),
                           cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 2)
                
                # Show last detected plate if available (from scan button)
                with last_detected_plate_lock:
                    if last_detected_plate:
                        current_time = time.time()
                        # Only show if detected within last 10 seconds
                        if (current_time - last_detected_plate_time) < 10:
                            cv2.putText(display_frame, f"Last detected: {last_detected_plate}", (10, 90),
                                       cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 255, 0), 2)
            
            # Encode frame
            ret, buffer = cv2.imencode('.jpg', display_frame)
            if not ret:
                continue
            yield (b'--frame\r\n'
                   b'Content-Type: image/jpeg\r\n\r\n' + buffer.tobytes() + b'\r\n')
            
            time.sleep(0.033)  # ~30 FPS
        except Exception as e:
            print(f"Error in car plate frame generation: {e}")
            break

@app.get("/car-plate", response_class=HTMLResponse)
def car_plate():
    """Car Plate Detector page."""
    return """
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Car Plate Detector</title>
        <style>
            * {
                margin: 0;
                padding: 0;
                box-sizing: border-box;
            }
            body {
                font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
                background: #f5f5f5;
                margin: 0;
            }
            .header {
                background: #4E6691;
                color: white;
                padding: 16px 20px;
                display: flex;
                align-items: center;
                gap: 12px;
            }
            .back-arrow {
                cursor: pointer;
                font-size: 24px;
                color: white;
                text-decoration: none;
            }
            .header-title {
                font-size: 20px;
                font-weight: 600;
            }
            .container {
                max-width: 1200px;
                margin: 20px auto;
                padding: 0 20px;
                background: white;
                padding: 20px;
                border-radius: 12px;
                box-shadow: 0 2px 8px rgba(0,0,0,0.1);
            }
            .video-container {
                text-align: center;
                margin: 20px 0;
            }
            .video-stream {
                max-width: 100%;
                border: 2px solid #ddd;
                border-radius: 8px;
            }
            .controls {
                margin: 20px 0;
                text-align: center;
            }
            .status {
                padding: 10px;
                margin: 10px 0;
                border-radius: 4px;
                background: #e3f2fd;
                color: #1976d2;
            }
            .scan-success {
                background: #c8e6c9;
                color: #2e7d32;
            }
            button {
                padding: 10px 20px;
                font-size: 16px;
                background: #4E6691;
                color: white;
                border: none;
                border-radius: 4px;
                cursor: pointer;
                transition: all 0.3s;
            }
            button:hover {
                background: #3d5474;
            }
            button:disabled {
                background: #9e9e9e;
                cursor: not-allowed;
            }
        </style>
    </head>
    <body>
        <div class="header">
            <a href="/" class="back-arrow">←</a>
            <div class="header-title">Car Plate Detector</div>
        </div>
        <div class="container">
            <div class="video-container">
                <img src="/car_plate_video_feed" class="video-stream" alt="Car Plate Scanner">
            </div>
            <div id="status" class="status">Point camera at car plate to scan...</div>
            <div class="controls">
                <button id="scanBtn" onclick="scanCarPlate()">Scan Car Plate</button>
            </div>
        </div>
        <script>
            function scanCarPlate() {
                const scanBtn = document.getElementById('scanBtn');
                const statusDiv = document.getElementById('status');
                
                scanBtn.disabled = true;
                scanBtn.textContent = 'Scanning...';
                statusDiv.textContent = 'Scanning car plate...';
                statusDiv.className = 'status';
                
                fetch('/api/car-plate/scan', {
                    method: 'POST',
                    headers: {'Content-Type': 'application/json'}
                })
                .then(response => response.json())
                .then(data => {
                    if (data.success && data.plate_number) {
                        statusDiv.textContent = 'Car plate detected: ' + data.plate_number;
                        statusDiv.className = 'status scan-success';
                    } else {
                        statusDiv.textContent = 'No car plate detected. Please try again.';
                        statusDiv.className = 'status';
                    }
                })
                .catch(error => {
                    console.error('Error:', error);
                    statusDiv.textContent = 'Error scanning car plate: ' + error.message;
                    statusDiv.className = 'status';
                })
                .finally(() => {
                    scanBtn.disabled = false;
                    scanBtn.textContent = 'Scan Car Plate';
                });
            }
        </script>
    </body>
    </html>
    """


@app.get("/video_feed")
def video_feed():
    """MJPEG video stream route."""
    return StreamingResponse(generate_frames(),
                             media_type="multipart/x-mixed-replace; boundary=frame")

@app.get("/visitor_qr_video_feed")
def visitor_qr_video_feed():
    """MJPEG video stream route for visitor QR code scanning."""
    return StreamingResponse(generate_visitor_qr_frames(),
                             media_type="multipart/x-mixed-replace; boundary=frame")

@app.get("/car_plate_video_feed")
def car_plate_video_feed():
    """MJPEG video stream route for car plate scanning."""
    return StreamingResponse(generate_car_plate_frames(),
                             media_type="multipart/x-mixed-replace; boundary=frame")

# Store last scanned QR code for API access
last_scanned_qr = None
last_scanned_qr_time = 0
last_scanned_qr_lock = threading.Lock()

@app.post("/api/visitor/scan-qr")
async def scan_visitor_qr(request: Request):
    """Manually trigger QR code scan and process."""
    try:
        data = await request.json()
        qr_code = data.get('qr_code')
        
        if not qr_code:
            return JSONResponse(
                status_code=400,
                content={"success": False, "error": "QR code is required"}
            )
        
        # Process the QR code
        result = await process_visitor_qr(qr_code)
        return JSONResponse(content=result)
    except Exception as e:
        print(f"Error in scan_visitor_qr: {e}")
        traceback.print_exc()
        return JSONResponse(
            status_code=500,
            content={"success": False, "error": str(e)}
        )

@app.get("/api/visitor/check-scan")
async def check_visitor_scan():
    """Check the latest scanned QR code."""
    try:
        with last_scanned_qr_lock:
            current_time = time.time()
            # Only return QR codes scanned in the last 30 seconds (extended for manual approval)
            if last_scanned_qr and (current_time - last_scanned_qr_time) < 30:
                return JSONResponse(content={
                    "success": True,
                    "scanned": True,
                    "qr_code": last_scanned_qr,
                    "message": "QR code detected"
                })
            return JSONResponse(content={
                "success": True,
                "scanned": False,
                "message": "No QR code detected"
            })
    except Exception as e:
        return JSONResponse(
            status_code=500,
            content={"success": False, "error": str(e)}
        )

@app.post("/api/visitor/approve")
async def approve_visitor(request: Request):
    """Approve visitor entry and update status to History."""
    try:
        data = await request.json()
        qr_code = data.get('qr_code')
        
        if not qr_code:
            return JSONResponse(
                status_code=400,
                content={"success": False, "error": "QR code is required"}
            )
        
        # Process the QR code (update Firebase status to History)
        result = await process_visitor_qr(qr_code)
        
        if result.get("success"):
            return JSONResponse(content={
                "success": True,
                "message": f"Visitor {qr_code} approved successfully. Status updated to History.",
                "qr_code": qr_code
            })
        else:
            return JSONResponse(
                status_code=400,
                content={
                    "success": False,
                    "error": result.get("message") or result.get("error") or "Failed to approve visitor",
                    "qr_code": qr_code
                }
            )
    except Exception as e:
        print(f"Error in approve_visitor: {e}")
        traceback.print_exc()
        return JSONResponse(
            status_code=500,
            content={"success": False, "error": str(e)}
        )

@app.post("/api/car-plate/scan")
async def scan_car_plate():
    """Scan car plate from camera and return detected plate number."""
    try:
        # Check if EasyOCR is available (try lazy initialization)
        global easyocr_reader, EASYOCR_AVAILABLE, easyocr_init_error
        if easyocr_reader is None:
            print("[API] EasyOCR not initialized, attempting to load...")
            easyocr_reader, EASYOCR_AVAILABLE = _try_load_easyocr()
        
        if not EASYOCR_AVAILABLE or easyocr_reader is None:
            error_msg = easyocr_init_error or "EasyOCR not available. Please install: pip install easyocr"
            return JSONResponse(
                status_code=200,
                content={
                    "success": False,
                    "error": error_msg,
                    "plate_number": None
                }
            )
        
        # Check camera
        if car_plate_camera is None or not car_plate_camera.isOpened():
            # Try to reinitialize camera
            init_car_plate_camera()
            if car_plate_camera is None or not car_plate_camera.isOpened():
                return JSONResponse(
                    status_code=200,
                    content={
                        "success": False,
                        "error": "Camera not connected. Ensure iVCam is running.",
                        "plate_number": None
                    }
                )
        
        # Read frame from camera
        with car_plate_camera_lock:
            success, frame = car_plate_camera.read()
            if not success or frame is None:
                return JSONResponse(
                    status_code=200,
                    content={
                        "success": False,
                        "error": "Failed to read frame from camera",
                        "plate_number": None
                    }
                )
            
            # Crop iVCam logo if needed
            if frame.shape[0] > 100:
                frame = frame[60:-40, :]
        
        print(f"[Car Plate Scan] Frame size: {frame.shape}, Starting detection...")
        
        # Detect car plate
        plate_number = detect_car_plate(frame)
        
        if plate_number:
            # Update last detected plate
            current_time = time.time()
            with last_detected_plate_lock:
                global last_detected_plate, last_detected_plate_time
                last_detected_plate = plate_number
                last_detected_plate_time = current_time
            
            print(f"[Car Plate Scan] Successfully detected: {plate_number}")
            return JSONResponse(
                status_code=200,
                content={
                    "success": True,
                    "plate_number": plate_number,
                    "message": f"Car plate detected: {plate_number}"
                }
            )
        else:
            print("[Car Plate Scan] No plate detected. Check console for detailed debug info.")
            return JSONResponse(
                status_code=200,
                content={
                    "success": False,
                    "error": "No car plate detected. Check console logs for details. Ensure the plate is clearly visible and well-lit.",
                    "plate_number": None
                }
            )
    except Exception as e:
        print(f"Error in /api/car-plate/scan: {e}")
        traceback.print_exc()
        return JSONResponse(
            status_code=500,
            content={
                "success": False,
                "error": str(e),
                "plate_number": None
            }
        )

@app.get("/api/car-plate/check-scan")
async def check_car_plate_scan():
    """Check the latest scanned car plate number."""
    try:
        with last_detected_plate_lock:
            current_time = time.time()
            # Only return plates scanned in the last 30 seconds
            if last_detected_plate and (current_time - last_detected_plate_time) < 30:
                return JSONResponse(content={
                    "success": True,
                    "scanned": True,
                    "plate_number": last_detected_plate,
                    "message": "Car plate detected"
                })
            return JSONResponse(content={
                "success": True,
                "scanned": False,
                "message": "No car plate detected"
            })
    except Exception as e:
        return JSONResponse(
            status_code=500,
            content={"success": False, "error": str(e)}
        )

@app.get("/api/car-plate/status")
async def check_easyocr_status():
    """Check EasyOCR initialization status and camera status."""
    global easyocr_reader, EASYOCR_AVAILABLE, easyocr_init_error
    # Try to initialize if not already done
    if easyocr_reader is None:
        print("[Status Check] EasyOCR not initialized, attempting to load...")
        easyocr_reader, EASYOCR_AVAILABLE = _try_load_easyocr()
    
    # Check camera status
    camera_status = "connected" if (car_plate_camera is not None and car_plate_camera.isOpened()) else "disconnected"
    if camera_status == "disconnected":
        # Try to reinitialize
        init_car_plate_camera()
        camera_status = "connected" if (car_plate_camera is not None and car_plate_camera.isOpened()) else "disconnected"
    
    return JSONResponse(content={
        "easyocr_available": EASYOCR_AVAILABLE,
        "easyocr_initialized": easyocr_reader is not None,
        "camera_status": camera_status,
        "camera_index": car_plate_camera_index,
        "error": easyocr_init_error,
        "message": f"EasyOCR: {'ready' if EASYOCR_AVAILABLE else 'not available'}, Camera: {camera_status}"
    })

async def process_visitor_qr(qr_code: str):
    """Process scanned QR code and update visitor status to History."""
    try:
        print(f"[Visitor QR] Processing QR code: {qr_code}")
        
        # Update last scanned QR
        with last_scanned_qr_lock:
            global last_scanned_qr, last_scanned_qr_time
            last_scanned_qr = qr_code
            last_scanned_qr_time = time.time()
        
        # Update Firebase if available
        if firestore_db is None:
            print(f"[Visitor QR] Firebase not available. QR code {qr_code} detected but not updated.")
            return {
                "success": False,
                "message": f"QR code {qr_code} detected. (Firebase update disabled - install serviceAccountKey.json)",
                "qr_code": qr_code
            }
        
        try:
            # Find visitor reservation by vstQR
            print(f"[Visitor QR] Searching for visitor reservation with vstQR: {qr_code}")
            reservations_ref = firestore_db.collection('visitorReservation')
            query = reservations_ref.where('vstQR', '==', qr_code).limit(1)
            
            # Use get() instead of stream() for simpler synchronous access
            docs = query.get()
            
            print(f"[Visitor QR] Found {len(docs)} document(s) matching vstQR: {qr_code}")
            
            if len(docs) == 0:
                # Also try searching by vstRsvtID in case the field name is different
                print(f"[Visitor QR] Trying alternative search by vstRsvtID...")
                query2 = reservations_ref.where('vstRsvtID', '==', qr_code).limit(1)
                docs = query2.get()
                print(f"[Visitor QR] Found {len(docs)} document(s) matching vstRsvtID: {qr_code}")
            
            updated = False
            for doc in docs:
                doc_data = doc.to_dict()
                print(f"[Visitor QR] Found document ID: {doc.id}")
                print(f"[Visitor QR] Current vstStatus: {doc_data.get('vstStatus', 'N/A')}")
                print(f"[Visitor QR] Document stdID: {doc_data.get('stdID', 'NOT SET')}")
                print(f"[Visitor QR] Document data: {doc_data}")
                
                # Check if this is first scan (no startTime) or second scan (has startTime but no endTime)
                from datetime import datetime
                from google.cloud.firestore import SERVER_TIMESTAMP
                
                start_time = doc_data.get('startTime')
                end_time = doc_data.get('endTime')
                
                scan_type = None
                if start_time is None:
                    # First scan: Set startTime (car in), keep status as "Up Coming"
                    current_time_utc = datetime.utcnow()
                    update_data = {
                        'startTime': current_time_utc,
                    }
                    doc.reference.update(update_data)
                    print(f"[Visitor QR] First scan - Set startTime (car in) for reservation {doc.id}")
                    scan_type = "first"
                    updated = True
                elif end_time is None:
                    # Second scan: Set endTime (car out) and change status to "History"
                    current_time_utc = datetime.utcnow()
                    update_data = {
                        'endTime': current_time_utc,
                        'vstStatus': 'History',
                    }
                    doc.reference.update(update_data)
                    print(f"[Visitor QR] Second scan - Set endTime (car out) and updated status to History for reservation {doc.id}")
                    scan_type = "second"
                    updated = True
                else:
                    # Already scanned twice, just acknowledge
                    print(f"[Visitor QR] QR code already scanned twice for reservation {doc.id}")
                    scan_type = "already_scanned"
                    updated = True
                break
            
            if updated:
                if scan_type == "first":
                    message = f"QR code {qr_code} scanned - Car In recorded. Scan again to record Car Out."
                elif scan_type == "second":
                    message = f"QR code {qr_code} scanned - Car Out recorded. Visitor moved to History."
                else:
                    message = f"QR code {qr_code} already scanned twice."
                
                return {
                    "success": True,
                    "message": message,
                    "qr_code": qr_code,
                    "scan_type": scan_type
                }
            else:
                print(f"[Visitor QR] ERROR: No document found with vstQR or vstRsvtID matching: {qr_code}")
                return {
                    "success": False,
                    "message": f"QR code {qr_code} not found in visitor reservations. Please check the QR code value.",
                    "qr_code": qr_code
                }
        except Exception as firebase_error:
            print(f"[Visitor QR] Firebase update error: {firebase_error}")
            traceback.print_exc()
            return {
                "success": False,
                "error": f"Firebase update failed: {str(firebase_error)}",
                "qr_code": qr_code
            }
    except Exception as e:
        print(f"[Visitor QR] Error processing visitor QR: {e}")
        traceback.print_exc()
        return {
            "success": False,
            "error": str(e)
        }