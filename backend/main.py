from __future__ import annotations

import json
import os
import sqlite3
import time
from dataclasses import dataclass
from typing import Dict, List, Tuple

import cv2
import numpy as np
from fastapi import FastAPI, HTTPException
from fastapi.responses import HTMLResponse, Response, RedirectResponse
from pydantic import BaseModel
from shapely.geometry import Polygon, box, Point

# YOLO is heavy to import; delay until first use
_yolo_model = None
OCCUPANCY_OVERLAP_THRESHOLD = 0.10  # fraction of slot area overlapped by vehicle bbox
PREDICT_KW = {
    "imgsz": 1280,
    "conf": 0.05,   # more sensitive; raise if too many false positives
    "iou": 0.5,
    "classes": None,  # allow all classes; we filter by name later
    "verbose": False,
}


# YOLOv8 default class names include: car, truck, bus, motorcycle, bicycle
ALLOWED_CLASSES = {"car", "truck", "bus", "motorcycle", "bicycle"}


@dataclass
class Slot:
    slot_id: str
    polygon: Polygon


@dataclass
class AreaConfig:
    name: str
    camera_index: int
    frame_width: int
    frame_height: int
    slots: List[Slot]


def load_config(path: str = os.path.join(os.path.dirname(__file__), "areas.json")) -> Dict[str, AreaConfig]:
    with open(path, "r", encoding="utf-8") as f:
        raw = json.load(f)
    areas: Dict[str, AreaConfig] = {}
    for a in raw["areas"]:
        area = AreaConfig(
            name=a["name"],
            camera_index=int(a.get("camera_index", 0)),
            frame_width=int(a.get("frame_width", 1920)),
            frame_height=int(a.get("frame_height", 1080)),
            slots=[Slot(slot_id=s["id"], polygon=Polygon(s["polygon"])) for s in a["slots"]],
        )
        areas[area.name] = area
    return areas


CONFIG = load_config()


def ensure_db(db_path: str) -> sqlite3.Connection:
    conn = sqlite3.connect(db_path, check_same_thread=False)
    cur = conn.cursor()
    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS slots (
            area TEXT,
            slot_id TEXT,
            status TEXT,
            updated_at REAL,
            PRIMARY KEY(area, slot_id)
        )
        """
    )
    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS bookings (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id TEXT,
            area TEXT,
            slot_id TEXT,
            status TEXT,
            created_at REAL
        )
        """
    )
    conn.commit()
    return conn


DB_PATH = os.path.join(os.path.dirname(__file__), "data.db")
DB = ensure_db(DB_PATH)


def get_model():
    global _yolo_model
    if _yolo_model is None:
        # Lazy import to speed initial start
        from ultralytics import YOLO

        _yolo_model = YOLO("yolov8s.pt")
    return _yolo_model


def capture_frame(camera_index: int) -> np.ndarray:
    cap = cv2.VideoCapture(camera_index, cv2.CAP_DSHOW)
    if not cap.isOpened():
        # fallback to default open
        cap = cv2.VideoCapture(camera_index)
    if not cap.isOpened():
        raise RuntimeError(f"Cannot open camera index {camera_index}. Ensure iVCam is running.")
    # warm-up
    for _ in range(3):
        cap.read()
    ok, frame = cap.read()
    cap.release()
    if not ok or frame is None:
        raise RuntimeError("Failed to capture frame from camera")
    return frame


def _scaled_slot_polygons(area: AreaConfig, frame_w: int, frame_h: int) -> Dict[str, Polygon]:
    """Scale configured slot polygons from configured frame size to actual frame size."""
    sx = frame_w / float(area.frame_width)
    sy = frame_h / float(area.frame_height)
    scaled: Dict[str, Polygon] = {}
    for s in area.slots:
        pts = [(float(x) * sx, float(y) * sy) for x, y in np.asarray(s.polygon.exterior.coords)[:-1]]
        scaled[s.slot_id] = Polygon(pts)
    return scaled


def compute_occupancy(frame: np.ndarray, area: AreaConfig) -> Dict[str, str]:
    model = get_model()
    results = model.predict(source=frame, **PREDICT_KW)
    detections: List[Tuple[float, float, float, float, str, float]] = []
    # Collect detections
    for r in results:
        for b in r.boxes:
            cls_id = int(b.cls)
            cls_name = r.names.get(cls_id, str(cls_id))
            if cls_name not in ALLOWED_CLASSES:
                continue
            x1, y1, x2, y2 = map(float, b.xyxy[0].tolist())
            conf = float(b.conf[0]) if hasattr(b, "conf") else 0.0
            detections.append((x1, y1, x2, y2, cls_name, conf))

    status: Dict[str, str] = {s.slot_id: "available" for s in area.slots}

    # Prepare polygons scaled to the actual frame size
    h, w = frame.shape[:2]
    slot_polys: Dict[str, Polygon] = _scaled_slot_polygons(area, w, h)

    # Mark occupied if any vehicle bbox overlaps the slot polygon sufficiently
    for x1, y1, x2, y2, _, _ in detections:
        vehicle_poly = box(x1, y1, x2, y2)
        cx = (x1 + x2) / 2.0
        cy = (y1 + y2) / 2.0
        center_point = Point(cx, cy)
        for slot_id, poly in slot_polys.items():
            # Rule 1: center of vehicle is inside the slot
            if poly.contains(center_point):
                status[slot_id] = "occupied"
                continue
            # Rule 2: overlap area ratio
            inter = poly.intersection(vehicle_poly).area
            if poly.area > 0 and inter / poly.area > OCCUPANCY_OVERLAP_THRESHOLD:
                status[slot_id] = "occupied"

    return status


def save_slot_states(area_name: str, states: Dict[str, str]) -> None:
    now = time.time()
    cur = DB.cursor()
    for slot_id, s in states.items():
        cur.execute(
            "INSERT INTO slots(area, slot_id, status, updated_at) VALUES(?,?,?,?)\n"
            "ON CONFLICT(area, slot_id) DO UPDATE SET status=excluded.status, updated_at=excluded.updated_at",
            (area_name, slot_id, s, now),
        )
    DB.commit()


def first_available(area_name: str) -> str | None:
    cur = DB.cursor()
    cur.execute(
        "SELECT slot_id, status FROM slots WHERE area=? ORDER BY CAST(slot_id AS INTEGER) ASC",
        (area_name,),
    )
    for slot_id, status in cur.fetchall():
        if status == "available":
            return slot_id
    return None


def book_slot(user_id: str, area_name: str, slot_id: str) -> None:
    cur = DB.cursor()
    # Mark slot as booked (distinct from occupied). We store "booked" in the same status column.
    cur.execute(
        "UPDATE slots SET status='booked', updated_at=? WHERE area=? AND slot_id=?",
        (time.time(), area_name, slot_id),
    )
    cur.execute(
        "INSERT INTO bookings(user_id, area, slot_id, status, created_at) VALUES(?,?,?,?,?)",
        (user_id, area_name, slot_id, "booked", time.time()),
    )
    DB.commit()


def release_slot(area_name: str, slot_id: str) -> None:
    cur = DB.cursor()
    cur.execute(
        "UPDATE slots SET status='available', updated_at=? WHERE area=? AND slot_id=?",
        (time.time(), area_name, slot_id),
    )
    cur.execute(
        "UPDATE bookings SET status='released' WHERE area=? AND slot_id=? AND status='booked'",
        (area_name, slot_id),
    )
    DB.commit()


class ScanRequest(BaseModel):
    area: str


class AssignRequest(BaseModel):
    area: str
    userId: str


class ReleaseRequest(BaseModel):
    area: str
    slotId: str


app = FastAPI(title="Parking Backend", version="0.1.0")


@app.get("/health")
def health():
    return {"ok": True}


@app.get("/areas")
def list_areas():
    return {
        "areas": [
            {
                "name": a.name,
                "cameraIndex": a.camera_index,
                "slotCount": len(a.slots),
            }
            for a in CONFIG.values()
        ]
    }


@app.post("/scan")
def scan(req: ScanRequest):
    if req.area not in CONFIG:
        raise HTTPException(status_code=404, detail="Unknown area")
    area = CONFIG[req.area]
    frame = capture_frame(area.camera_index)

    states = compute_occupancy(frame, area)
    # Do not overwrite booked slots as available
    cur = DB.cursor()
    cur.execute("SELECT slot_id, status FROM slots WHERE area=?", (area.name,))
    booked = {sid for sid, s in cur.fetchall() if s == "booked"}
    for sid in booked:
        if sid in states:
            states[sid] = "booked"

    save_slot_states(area.name, states)

    return {
        "area": area.name,
        "slots": [{"id": sid, "status": st} for sid, st in sorted(states.items(), key=lambda x: int(x[0]))],
    }


@app.post("/assign")
def assign(req: AssignRequest):
    if req.area not in CONFIG:
        raise HTTPException(status_code=404, detail="Unknown area")
    # Ensure we have fresh states before assignment
    scan(ScanRequest(area=req.area))
    sid = first_available(req.area)
    if sid is None:
        raise HTTPException(status_code=409, detail="No available slots")
    book_slot(req.userId, req.area, sid)
    return {"area": req.area, "slotId": sid, "status": "booked"}


@app.post("/release")
def release(req: ReleaseRequest):
    if req.area not in CONFIG:
        raise HTTPException(status_code=404, detail="Unknown area")
    release_slot(req.area, req.slotId)
    return {"ok": True}


@app.get("/debug.json")
def debug(area: str = "Demo"):
    if area not in CONFIG:
        raise HTTPException(status_code=404, detail="Unknown area")
    ar = CONFIG[area]
    frame = capture_frame(ar.camera_index)
    h, w = frame.shape[:2]
    slot_polys = _scaled_slot_polygons(ar, w, h)
    model = get_model()
    results = model.predict(source=frame, **PREDICT_KW)
    rows = []
    for r in results:
        for b in r.boxes:
            cls_id = int(b.cls)
            cls_name = r.names.get(cls_id, str(cls_id))
            if cls_name not in ALLOWED_CLASSES:
                continue
            x1, y1, x2, y2 = map(float, b.xyxy[0].tolist())
            cx = (x1 + x2) / 2.0
            cy = (y1 + y2) / 2.0
            for sid, poly in slot_polys.items():
                inter = poly.intersection(box(x1, y1, x2, y2)).area
                ratio = inter / poly.area if poly.area > 0 else 0.0
                center_in = poly.contains(Point(cx, cy))
                rows.append({"slot": sid, "cls": cls_name, "ratio": round(ratio, 3), "center": center_in})
    return {"w": w, "h": h, "rows": rows[:100]}


@app.get("/yolo.json")
def yolo_info(area: str = "Demo"):
    if area not in CONFIG:
        raise HTTPException(status_code=404, detail="Unknown area")
    ar = CONFIG[area]
    frame = capture_frame(ar.camera_index)
    model = get_model()
    results = model.predict(source=frame, **PREDICT_KW)
    dets = []
    for r in results:
        for b in r.boxes:
            cls_id = int(b.cls)
            cls_name = r.names.get(cls_id, str(cls_id))
            conf = float(b.conf[0]) if hasattr(b, "conf") else 0.0
            dets.append({"cls": cls_name, "conf": round(conf, 3)})
    return {"count": len(dets), "detections": dets[:50], "params": PREDICT_KW}


@app.get("/snapshot.jpg")
def snapshot(area: str = "Demo"):
    if area not in CONFIG:
        raise HTTPException(status_code=404, detail="Unknown area")
    ar = CONFIG[area]
    frame = capture_frame(ar.camera_index)
    ok, buf = cv2.imencode(".jpg", frame)
    if not ok:
        raise HTTPException(status_code=500, detail="Failed to encode frame")
    return Response(content=buf.tobytes(), media_type="image/jpeg")


@app.get("/overlay.jpg")
def overlay(area: str = "Demo"):
    if area not in CONFIG:
        raise HTTPException(status_code=404, detail="Unknown area")
    ar = CONFIG[area]
    frame = capture_frame(ar.camera_index)
    h, w = frame.shape[:2]
    slot_polys = _scaled_slot_polygons(ar, w, h)

    # Compute occupancy on this same frame
    states = compute_occupancy(frame, ar)

    # Draw slot polygons with occupancy color
    vis = frame.copy()
    overlay_img = vis.copy()
    for sid, poly in slot_polys.items():
        pts = np.array(list(poly.exterior.coords)[:-1], dtype=np.int32)
        color = (0, 255, 0) if states.get(sid) == "available" else (0, 0, 255)
        cv2.fillPoly(overlay_img, [pts], color)
        cv2.polylines(overlay_img, [pts], isClosed=True, color=(255, 255, 0), thickness=2)
        # Label
        tx, ty = int(pts[0][0]) + 5, int(pts[0][1]) + 25
        label = f"no.{sid} {'OK' if states.get(sid) == 'available' else 'OCC'}"
        cv2.putText(overlay_img, label, (tx, ty), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 0), 2, cv2.LINE_AA)

    # Blend
    alpha = 0.25
    vis = cv2.addWeighted(overlay_img, alpha, vis, 1 - alpha, 0)

    # Run detection and draw boxes
    model = get_model()
    results = model.predict(source=frame, **PREDICT_KW)
    for r in results:
        for b in r.boxes:
            cls_id = int(b.cls)
            cls_name = r.names.get(cls_id, str(cls_id))
            if cls_name not in ALLOWED_CLASSES:
                continue
            x1, y1, x2, y2 = map(int, b.xyxy[0].tolist())
            cv2.rectangle(vis, (x1, y1), (x2, y2), (0, 255, 0), 2)
            cv2.putText(vis, cls_name, (x1, max(20, y1 - 6)), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)

    ok, buf = cv2.imencode(".jpg", vis)
    if not ok:
        raise HTTPException(status_code=500, detail="Failed to encode frame")
    return Response(content=buf.tobytes(), media_type="image/jpeg")


@app.get("/console", response_class=HTMLResponse)
def console(area: str = "Demo"):
    # Simple HTML console to manually trigger scan and view results
    area_opts = "".join(
        [f"<option value=\"{a}\" {'selected' if a==area else ''}>{a}</option>" for a in CONFIG.keys()]
    )
    html = """
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Parking Console</title>
  <style>
    body {{ font-family: Arial, sans-serif; background:#f5f7fb; margin:0; }}
    header {{ background:#486b94; color:#fff; padding:16px 24px; font-size:18px; }}
    main {{ max-width:960px; margin:24px auto; padding:0 16px; }}
    .card {{ background:#fff; border-radius:12px; padding:24px; box-shadow:0 6px 18px rgba(0,0,0,.06); }}
    button {{ background:#486b94; color:#fff; border:none; padding:12px 20px; border-radius:8px; cursor:pointer; }}
    button:disabled {{ opacity:.6; cursor:not-allowed; }}
    select {{ padding:10px; border-radius:8px; }}
    .slots {{ display:grid; grid-template-columns: repeat(auto-fill, minmax(120px, 1fr)); gap:12px; margin-top:16px; }}
    .slot {{ padding:10px; border-radius:8px; text-align:center; font-weight:600; }}
    .occupied {{ background:#ffd6d6; color:#8a1b1b; }}
    .available {{ background:#d7f5d7; color:#205c20; }}
    .booked {{ background:#fff2cc; color:#665200; }}
    img {{ width:100%; border-radius:10px; margin-top:16px; }}
  </style>
  <script>
    async function doScan() {{
      const area = document.getElementById('area').value;
      const btn = document.getElementById('scanBtn');
      btn.disabled = true; btn.innerText = 'Scanning...';
      try {{
        const res = await fetch('/scan', {{
          method: 'POST', headers: {{ 'Content-Type': 'application/json' }},
          body: JSON.stringify({{ area }})
        }});
        const data = await res.json();
        const container = document.getElementById('slots');
        container.innerHTML = '';
        for (const s of data.slots) {{
          const d = document.createElement('div');
          d.className = 'slot ' + s.status;
          d.textContent = `Slot ${{s.id}} - ${{s.status}}`;
          container.appendChild(d);
        }}
        // Refresh overlay image
        document.getElementById('overlay').src = '/overlay.jpg?area=' + encodeURIComponent(area) + '&t=' + Date.now();
      }} catch (e) {{ alert('Scan failed: ' + e); }}
      btn.disabled = false; btn.innerText = 'Open Camera & Scan';
    }}
  </script>
  </head>
  <body>
    <header>Parking Scan Console</header>
    <main>
      <div class='card'>
        <div style='display:flex; gap:12px; align-items:center;'>
          <label for='area'>Area:</label>
          <select id='area'>
            {area_opts}
          </select>
          <button id='scanBtn' onclick='doScan()'>Open Camera & Scan</button>
        </div>
        <img id='overlay' alt='overlay' src='/overlay.jpg?area={area}' />
        <div id='slots' class='slots'></div>
      </div>
    </main>
  </body>
</html>
""".format(area_opts=area_opts, area=area)
    return HTMLResponse(html)


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)


@app.get("/")
def root():
    # Redirect to the console by default so / shows something useful
    return RedirectResponse(url="/console")


