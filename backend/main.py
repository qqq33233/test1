from fastapi import FastAPI, Request, Body
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, HTMLResponse, StreamingResponse
from fastapi.exceptions import RequestValidationError
from pydantic import BaseModel
import cv2
import numpy as np
import traceback
import threading
import time
import json
import os

app = FastAPI()

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
frozen_analysis = None  # Store (occupied_count, empty_count, statuses)
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

        cv2.polylines(frame, [pts], True, color, 2)
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
                    # frozen_analysis is a tuple: (occupied_count, empty_count, statuses)
                    occupied_count, empty_count, statuses = frozen_analysis
                    slot_statuses_list = [bool(s) for s in statuses] if statuses else []
                    parking_spaces = get_parking_spaces_for_area(area)
                    total_spots = len(parking_spaces) if parking_spaces else len(statuses) if statuses else 14
                    
                    # Debug: Print what we're returning
                    print(f"DEBUG: Returning frozen analysis for area '{area}': empty={empty_count}, occupied={occupied_count}, total={total_spots}")
                    
                    return JSONResponse(
                        status_code=200,
                        content={
                            "success": True,
                            "area": area,
                            "available": int(empty_count),
                            "available_slots": int(empty_count),
                            "empty": int(empty_count),  # Explicitly return "empty" for frontend
                            "occupied": int(occupied_count),
                            "total": int(total_spots),
                            "slot_statuses": slot_statuses_list
                        }
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
        spot_number = request.spot_number
        
        # Scan parking area to get current availability
        if cap is None or not cap.isOpened():
            return {
                "success": False,
                "error": "Camera not connected",
                "available": 0,
                "empty": 0
            }
        
        success, frame = read_frame_safe()
        if not success or frame is None:
            return {
                "success": False,
                "error": "Failed to read frame",
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
        
        return {
            "success": True,
            "message": f"Parking status updated for {area}",
            "area": area,
            "available": empty_count,
            "empty": empty_count,  # Backend returns "empty", frontend displays as "available"
            "occupied": occupied_count,
            "total": len(get_parking_spaces_for_area(area)) if get_parking_spaces_for_area(area) else 14
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
                    occupied_count, empty_count, _ = frozen_analysis
                    return {
                        "occupied": occupied_count, 
                        "empty": empty_count,
                        "available": empty_count  # Available parking is same as empty
                    }
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
        
        try:
            with frozen_frame_lock:
                global frozen_frame, frozen_raw_frame, frozen_analysis
                frozen_frame = processed_frame.copy()  # For display
                frozen_raw_frame = raw_frame.copy()  # For re-analysis if needed
                frozen_analysis = (occupied_count, empty_count, statuses)  # Store analysis results
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
                "slot_statuses": slot_statuses_list  # Detailed status per slot (True=occupied, False=empty)
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
                background: #1976d2;
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
                background: #e3f2fd;
                border-radius: 16px;
                display: flex;
                align-items: center;
                justify-content: center;
                margin: 0 auto 24px;
                font-size: 60px;
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
                        <svg width="80" height="80" viewBox="0 0 100 100" fill="none" xmlns="http://www.w3.org/2000/svg">
                            <!-- Car -->
                            <path d="M20 60 L30 50 L70 50 L80 60 L80 75 L20 75 Z" fill="#1976d2" stroke="#1976d2" stroke-width="2"/>
                            <circle cx="35" cy="75" r="8" fill="#333"/>
                            <circle cx="65" cy="75" r="8" fill="#333"/>
                            <rect x="35" y="50" width="30" height="15" fill="#e3f2fd"/>
                            <!-- Parking Sign -->
                            <rect x="72" y="40" width="20" height="20" rx="2" fill="white" stroke="#1976d2" stroke-width="2"/>
                            <text x="82" y="55" font-family="Arial" font-size="14" font-weight="bold" fill="#1976d2" text-anchor="middle">P</text>
                        </svg>
                    </div>
                    <div class="module-title">Parking Spot Detector</div>
                </a>
                <a href="/visitor-qr" class="module-card">
                    <div class="module-icon">
                        <svg width="80" height="80" viewBox="0 0 100 100" fill="none" xmlns="http://www.w3.org/2000/svg">
                            <!-- ID Badge -->
                            <rect x="25" y="20" width="50" height="70" rx="4" fill="white" stroke="#1976d2" stroke-width="3"/>
                            <rect x="35" y="30" width="30" height="20" rx="2" fill="#e3f2fd" stroke="#1976d2" stroke-width="2"/>
                            <!-- Person Icon -->
                            <circle cx="50" cy="45" r="8" fill="#1976d2"/>
                            <path d="M35 65 Q35 55 50 55 Q65 55 65 65" stroke="#1976d2" stroke-width="3" fill="none" stroke-linecap="round"/>
                        </svg>
                    </div>
                    <div class="module-title">Visitor QR code Detector</div>
                </a>
                <a href="/car-plate" class="module-card">
                    <div class="module-icon">
                        <svg width="80" height="80" viewBox="0 0 100 100" fill="none" xmlns="http://www.w3.org/2000/svg">
                            <!-- Focus Frame -->
                            <path d="M20 40 L20 20 L40 20" stroke="#1976d2" stroke-width="4" fill="none" stroke-linecap="round" stroke-linejoin="round"/>
                            <path d="M80 40 L80 20 L60 20" stroke="#1976d2" stroke-width="4" fill="none" stroke-linecap="round" stroke-linejoin="round"/>
                            <path d="M20 60 L20 80 L40 80" stroke="#1976d2" stroke-width="4" fill="none" stroke-linecap="round" stroke-linejoin="round"/>
                            <path d="M80 60 L80 80 L60 80" stroke="#1976d2" stroke-width="4" fill="none" stroke-linecap="round" stroke-linejoin="round"/>
                            <!-- Center rectangle -->
                            <rect x="35" y="45" width="30" height="10" fill="#1976d2" opacity="0.3"/>
                        </svg>
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
                body { 
                    font-family: 'Segoe UI', Arial, sans-serif; 
                    background: #f5f5f5; 
                    padding: 20px; 
                    margin: 0;
                }
                .back-link {
                    display: inline-block;
                    margin-bottom: 20px;
                    color: #1976d2;
                    text-decoration: none;
                    font-weight: 600;
                    padding: 8px 16px;
                    border-radius: 8px;
                    transition: background 0.2s;
                }
                .back-link:hover {
                    background: #e3f2fd;
                }
                h2 {
                    color: #333;
                    margin-bottom: 20px;
                    text-align: center;
                }
                .main-container {
                    display: flex;
                    gap: 20px;
                    max-width: 1600px;
                    margin: 0 auto;
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
                    background: #1976d2;
                    color: white;
                    border: none;
                    padding: 15px 50px;
                    font-size: 18px;
                    font-weight: bold;
                    border-radius: 8px;
                    cursor: pointer;
                    box-shadow: 0px 4px 10px rgba(25, 118, 210, 0.3);
                    transition: all 0.3s;
                    margin: 20px auto 0;
                    display: block;
                }
                .confirm-btn:hover {
                    background: #1565c0;
                    transform: translateY(-2px);
                    box-shadow: 0px 6px 15px rgba(25, 118, 210, 0.4);
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
            <div style="max-width: 1600px; margin: 0 auto;">
                <a href="/" class="back-link">← Back to Console</a>
            </div>
            <h2>🚗 Real-Time Parking Detection</h2>
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


@app.get("/visitor-qr", response_class=HTMLResponse)
def visitor_qr():
    """Visitor QR code Detector placeholder page."""
    return """
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Visitor QR Code Detector</title>
        <style>
            body {
                font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
                background: #f5f5f5;
                display: flex;
                justify-content: center;
                align-items: center;
                height: 100vh;
                margin: 0;
            }
            .container {
                text-align: center;
                background: white;
                padding: 60px;
                border-radius: 16px;
                box-shadow: 0 4px 12px rgba(0,0,0,0.1);
            }
            h1 {
                color: #1976d2;
                margin-bottom: 20px;
            }
            p {
                color: #666;
                margin-bottom: 30px;
            }
            a {
                color: #1976d2;
                text-decoration: none;
                font-weight: 600;
            }
            a:hover {
                text-decoration: underline;
            }
        </style>
    </head>
    <body>
        <div class="container">
            <h1>Visitor QR Code Detector</h1>
            <p>This module is coming soon.</p>
            <a href="/">← Back to Console</a>
        </div>
    </body>
    </html>
    """


@app.get("/car-plate", response_class=HTMLResponse)
def car_plate():
    """Car Plate Detector placeholder page."""
    return """
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Car Plate Detector</title>
        <style>
            body {
                font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
                background: #f5f5f5;
                display: flex;
                justify-content: center;
                align-items: center;
                height: 100vh;
                margin: 0;
            }
            .container {
                text-align: center;
                background: white;
                padding: 60px;
                border-radius: 16px;
                box-shadow: 0 4px 12px rgba(0,0,0,0.1);
            }
            h1 {
                color: #1976d2;
                margin-bottom: 20px;
            }
            p {
                color: #666;
                margin-bottom: 30px;
            }
            a {
                color: #1976d2;
                text-decoration: none;
                font-weight: 600;
            }
            a:hover {
                text-decoration: underline;
            }
        </style>
    </head>
    <body>
        <div class="container">
            <h1>Car Plate Detector</h1>
            <p>This module is coming soon.</p>
            <a href="/">← Back to Console</a>
        </div>
    </body>
    </html>
    """


@app.get("/video_feed")
def video_feed():
    """MJPEG video stream route."""
    return StreamingResponse(generate_frames(),
                             media_type="multipart/x-mixed-replace; boundary=frame")