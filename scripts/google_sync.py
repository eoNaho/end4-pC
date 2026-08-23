#!/usr/bin/env python3
import sys
import os
import json
import urllib.request
import urllib.parse
import webbrowser
from http.server import HTTPServer, BaseHTTPRequestHandler

CONFIG_DIR = os.path.expanduser("~/.config/illogical-impulse")
GAUTH_FILE = os.path.join(CONFIG_DIR, "gauth.json")
TODO_FILE = os.path.expanduser("~/.local/state/quickshell/user/todo.json")
CALENDAR_FILE = os.path.expanduser("~/.local/state/quickshell/user/calendar_events.json")

DEFAULT_CLIENT_ID = ""
DEFAULT_CLIENT_SECRET = ""
REDIRECT_URI = "http://localhost:8080"
SCOPES = [
    "https://www.googleapis.com/auth/tasks",
    "https://www.googleapis.com/auth/calendar.events",
    "https://www.googleapis.com/auth/calendar"
]

def load_auth():
    os.makedirs(CONFIG_DIR, exist_ok=True)
    if os.path.exists(GAUTH_FILE):
        try:
            with open(GAUTH_FILE, "r") as f:
                return json.load(f)
        except Exception:
            pass
    return {
        "client_id": DEFAULT_CLIENT_ID,
        "client_secret": DEFAULT_CLIENT_SECRET,
        "access_token": "",
        "refresh_token": ""
    }

def save_auth(data):
    os.makedirs(CONFIG_DIR, exist_ok=True)
    with open(GAUTH_FILE, "w") as f:
        json.dump(data, f, indent=2)

class OAuthCallbackHandler(BaseHTTPRequestHandler):
    code = None
    def do_GET(self):
        query = urllib.parse.urlparse(self.path).query
        params = urllib.parse.parse_qs(query)
        if "code" in params:
            OAuthCallbackHandler.code = params["code"][0]
            self.send_response(200)
            self.send_header("Content-type", "text/html; charset=utf-8")
            self.end_headers()
            html = """
            <html>
            <head><title>Google Sync Connected</title></head>
            <body style="font-family: sans-serif; background: #121212; color: #e0e0e0; text-align: center; padding-top: 50px;">
                <h1 style="color: #8ab4f8;">¡Conexión Exitosa con Google!</h1>
                <p>Quickshell se ha conectado a tu cuenta de Google Tasks y Calendar.</p>
                <p>Puedes cerrar esta ventana y regresar a tu escritorio.</p>
            </body>
            </html>
            """
            self.wfile.write(html.encode("utf-8"))
        else:
            self.send_response(400)
            self.end_headers()

    def log_message(self, format, *args):
        pass

def login():
    auth = load_auth()
    client_id = auth.get("client_id", DEFAULT_CLIENT_ID)
    auth_url = "https://accounts.google.com/o/oauth2/v2/auth?" + urllib.parse.urlencode({
        "client_id": client_id,
        "redirect_uri": REDIRECT_URI,
        "response_type": "code",
        "scope": " ".join(SCOPES),
        "access_type": "offline",
        "prompt": "consent"
    })

    print(f"[GoogleSync] Opening browser for authentication...")
    webbrowser.open(auth_url)

    server = HTTPServer(("localhost", 8080), OAuthCallbackHandler)
    server.handle_request()

    code = OAuthCallbackHandler.code
    if not code:
        print("[GoogleSync] Error: No code received.")
        sys.exit(1)

    # Exchange code for tokens
    client_secret = auth.get("client_secret", DEFAULT_CLIENT_SECRET)
    token_url = "https://oauth2.googleapis.com/token"
    payload = urllib.parse.urlencode({
        "code": code,
        "client_id": client_id,
        "client_secret": client_secret,
        "redirect_uri": REDIRECT_URI,
        "grant_type": "authorization_code"
    }).encode("utf-8")

    req = urllib.request.Request(token_url, data=payload, headers={"Content-Type": "application/x-www-form-urlencoded"})
    try:
        with urllib.request.urlopen(req) as resp:
            tokens = json.loads(resp.read().decode("utf-8"))
            auth["access_token"] = tokens.get("access_token", "")
            auth["refresh_token"] = tokens.get("refresh_token", auth.get("refresh_token", ""))
            save_auth(auth)
            print("[GoogleSync] Successfully logged in and saved refresh token!")
            sync_all()
    except urllib.error.HTTPError as e:
        error_body = e.read().decode("utf-8") if hasattr(e, "read") else str(e)
        print(f"[GoogleSync] Error exchanging code for tokens (HTTP {e.code}): {error_body}")
        sys.exit(1)
    except Exception as e:
        print(f"[GoogleSync] Error exchanging code for tokens: {e}")
        sys.exit(1)

def get_valid_access_token(auth):
    client_id = auth.get("client_id", DEFAULT_CLIENT_ID)
    client_secret = auth.get("client_secret", DEFAULT_CLIENT_SECRET)
    refresh_token = auth.get("refresh_token", "")

    if not refresh_token:
        print("[GoogleSync] Not logged in (no refresh token).")
        return None

    token_url = "https://oauth2.googleapis.com/token"
    payload = urllib.parse.urlencode({
        "client_id": client_id,
        "client_secret": client_secret,
        "refresh_token": refresh_token,
        "grant_type": "refresh_token"
    }).encode("utf-8")

    req = urllib.request.Request(token_url, data=payload, headers={"Content-Type": "application/x-www-form-urlencoded"})
    try:
        with urllib.request.urlopen(req) as resp:
            res = json.loads(resp.read().decode("utf-8"))
            access_token = res.get("access_token", "")
            auth["access_token"] = access_token
            save_auth(auth)
            return access_token
    except Exception as e:
        print(f"[GoogleSync] Token refresh error: {e}")
        return None

def api_request(url, access_token, method="GET", body=None):
    headers = {
        "Authorization": f"Bearer {access_token}",
        "Content-Type": "application/json"
    }
    data = json.dumps(body).encode("utf-8") if body else None
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req) as resp:
            raw = resp.read()
            if not raw:
                return {}
            content = raw.decode("utf-8").strip()
            if not content:
                return {}
            return json.loads(content)
    except Exception as e:
        print(f"[GoogleSync] API request error ({url}): {e}")
        return None

def sync_tasks():
    auth = load_auth()
    token = get_valid_access_token(auth)
    if not token:
        return

    # Load existing local tasks to preserve local-only metadata (starred, recurrence, time)
    local_map = {}
    if os.path.exists(TODO_FILE):
        try:
            with open(TODO_FILE, "r") as f:
                local_list = json.load(f)
                for item in local_list:
                    gid = item.get("gtask_id")
                    if gid:
                        local_map[gid] = item
        except Exception:
            pass

    # Fetch default task list
    res = api_request("https://tasks.googleapis.com/tasks/v1/lists/@default/tasks?showCompleted=true&showHidden=true", token)
    if not res or "items" not in res:
        print("[GoogleSync] No tasks returned or error.")
        return

    g_tasks = res.get("items", [])
    todo_items = []
    for t in g_tasks:
        title = t.get("title", "").strip()
        if not title:
            continue
        gtask_id = t.get("id", "")
        status = (t.get("status", "") == "completed")
        raw_notes = t.get("notes", "") or ""
        due_raw = t.get("due", "") or ""

        # Check if starred on Google Tasks (encoded in notes or title)
        starred_from_google = ("[starred]" in raw_notes) or ("⭐" in raw_notes) or ("⭐" in title)
        clean_notes = raw_notes.replace("[starred]", "").replace("⭐", "").strip()

        # Preserve local-only metadata if existing
        local_item = local_map.get(gtask_id, {})
        starred = starred_from_google or local_item.get("starred", False)
        recurrence = local_item.get("recurrence", None)
        due_date = local_item.get("due_date", "")
        due_time = local_item.get("due_time", "")
        has_time = local_item.get("has_time", False)

        if due_raw and not due_date:
            due_date = due_raw.split("T")[0]

        todo_items.append({
            "content": title,
            "notes": clean_notes,
            "done": status,
            "starred": starred,
            "due": due_raw,
            "due_date": due_date,
            "due_time": due_time,
            "has_time": has_time,
            "recurrence": recurrence,
            "gtask_id": gtask_id
        })

    os.makedirs(os.path.dirname(TODO_FILE), exist_ok=True)
    with open(TODO_FILE, "w") as f:
        json.dump(todo_items, f, indent=2)

    print(f"[GoogleSync] Synced {len(todo_items)} tasks from Google Tasks!")

def add_task(task_input):
    import time
    auth = load_auth()
    token = get_valid_access_token(auth)

    if isinstance(task_input, str):
        try:
            task_data = json.loads(task_input)
            if not isinstance(task_data, dict):
                task_data = {"content": str(task_input)}
        except Exception:
            task_data = {"content": task_input}
    else:
        task_data = task_input or {}

    title = (task_data.get("content") or task_data.get("title") or "").strip()
    if not title:
        print(f"[RESULT]{json.dumps({'success': False, 'message': 'Título vacío'})}")
        return

    notes = (task_data.get("notes") or "").strip()
    due_date = task_data.get("due_date") or ""
    due_time = task_data.get("due_time") or ""
    has_time = bool(task_data.get("has_time", False))
    starred = bool(task_data.get("starred", False))
    recurrence = task_data.get("recurrence", None)

    due_rfc = task_data.get("due") or ""
    if not due_rfc and due_date:
        if has_time and due_time:
            due_rfc = f"{due_date}T{due_time}:00.000Z"
        else:
            due_rfc = f"{due_date}T00:00:00.000Z"

    # 1. Save locally first into todo.json
    local_task = {
        "content": title,
        "notes": notes,
        "done": False,
        "starred": starred,
        "due": due_rfc,
        "due_date": due_date,
        "due_time": due_time,
        "has_time": has_time,
        "recurrence": recurrence,
        "gtask_id": f"local_{int(time.time())}"
    }

    existing_tasks = []
    if os.path.exists(TODO_FILE):
        try:
            with open(TODO_FILE, "r") as f:
                existing_tasks = json.load(f)
        except Exception:
            existing_tasks = []

    existing_tasks.insert(0, local_task)
    try:
        os.makedirs(os.path.dirname(TODO_FILE), exist_ok=True)
        with open(TODO_FILE, "w") as f:
            json.dump(existing_tasks, f, indent=2)
    except Exception as e:
        print(f"[GoogleSync] Error saving local task: {e}")

    result = {"success": True, "synced": False, "message": "Guardado localmente"}

    if token:
        body = {"title": title}
        notes_for_google = notes
        if starred and "[starred]" not in notes_for_google:
            notes_for_google = f"{notes_for_google}\n[starred]".strip()
        if notes_for_google:
            body["notes"] = notes_for_google
        if due_rfc:
            body["due"] = due_rfc

        resp = api_request("https://tasks.googleapis.com/tasks/v1/lists/@default/tasks", token, method="POST", body=body)
        if resp and "id" in resp:
            local_task["gtask_id"] = resp["id"]
            # Save updated task id
            try:
                with open(TODO_FILE, "w") as f:
                    json.dump(existing_tasks, f, indent=2)
            except Exception:
                pass
            sync_tasks()
            result = {"success": True, "synced": True, "message": "Sincronizado con Google Tasks"}

    print(f"[RESULT]{json.dumps(result)}")
    return result

def update_task_status(task_id, updates_input):
    auth = load_auth()
    token = get_valid_access_token(auth)
    if not task_id:
        print(f"[RESULT]{json.dumps({'success': False, 'message': 'ID no válido'})}")
        return

    # Parse updates_input (can be bool/string for 'done' or JSON object for multi-field updates)
    updates = {}
    if isinstance(updates_input, bool):
        updates = {"done": updates_input}
    elif isinstance(updates_input, str):
        if updates_input.lower() in ("true", "false"):
            updates = {"done": updates_input.lower() == "true"}
        else:
            try:
                updates = json.loads(updates_input)
            except Exception:
                updates = {}

    # Update local todo.json
    local_tasks = []
    found_item = None
    if os.path.exists(TODO_FILE):
        try:
            with open(TODO_FILE, "r") as f:
                local_tasks = json.load(f)
                for item in local_tasks:
                    if item.get("gtask_id") == task_id:
                        found_item = item
                        for k, v in updates.items():
                            item[k] = v
                        break
        except Exception:
            pass

    if found_item:
        try:
            with open(TODO_FILE, "w") as f:
                json.dump(local_tasks, f, indent=2)
        except Exception:
            pass

    result = {"success": True, "synced": False, "message": "Actualizado localmente"}

    if token:
        body = {}
        if "done" in updates:
            body["status"] = "completed" if updates["done"] else "needsAction"
        if "content" in updates:
            body["title"] = updates["content"]
        if "notes" in updates:
            current_starred = found_item.get("starred", False) if found_item else False
            base_notes = updates["notes"]
            if current_starred and "[starred]" not in base_notes:
                body["notes"] = f"{base_notes}\n[starred]".strip()
            else:
                body["notes"] = base_notes
        if "starred" in updates:
            current_notes = found_item.get("notes", "") if found_item else ""
            clean_notes = current_notes.replace("[starred]", "").replace("⭐", "").strip()
            if updates["starred"]:
                body["notes"] = f"{clean_notes}\n[starred]".strip()
            else:
                body["notes"] = clean_notes
        if "due" in updates:
            body["due"] = updates["due"]

        if body:
            resp = api_request(f"https://tasks.googleapis.com/tasks/v1/lists/@default/tasks/{task_id}", token, method="PATCH", body=body)
            if resp is not None:
                sync_tasks()
                result = {"success": True, "synced": True, "message": "Sincronizado con Google Tasks"}
        else:
            result = {"success": True, "synced": True, "message": "Actualizado localmente"}

    print(f"[RESULT]{json.dumps(result)}")
    return result

def delete_task(task_id):
    auth = load_auth()
    token = get_valid_access_token(auth)
    if not task_id:
        print(f"[RESULT]{json.dumps({'success': False, 'message': 'ID no válido'})}")
        return
    result = {"success": True, "synced": False, "message": "Eliminado localmente"}
    if token:
        resp = api_request(f"https://tasks.googleapis.com/tasks/v1/lists/@default/tasks/{task_id}", token, method="DELETE")
        if resp is not None:
            sync_tasks()
            result = {"success": True, "synced": True, "message": "Eliminado de Google Tasks"}
    print(f"[RESULT]{json.dumps(result)}")
    return result

def sync_calendar():
    auth = load_auth()
    token = get_valid_access_token(auth)
    if not token:
        return

    from datetime import datetime, timezone
    start_of_year = datetime(datetime.now().year, 1, 1, tzinfo=timezone.utc).isoformat()
    url = f"https://www.googleapis.com/calendar/v3/calendars/primary/events?timeMin={urllib.parse.quote(start_of_year)}&maxResults=250&singleEvents=true&orderBy=startTime"
    res = api_request(url, token)
    if not res or "items" not in res:
        return

    events = []
    for item in res.get("items", []):
        start = item.get("start", {}).get("dateTime") or item.get("start", {}).get("date")
        end = item.get("end", {}).get("dateTime") or item.get("end", {}).get("date")
        summary = item.get("summary", "Sin título")
        events.append({
            "id": item.get("id", ""),
            "summary": summary,
            "description": item.get("description", ""),
            "start": start,
            "end": end,
            "location": item.get("location", ""),
            "colorId": item.get("colorId", ""),
            "htmlLink": item.get("htmlLink", "")
        })

    os.makedirs(os.path.dirname(CALENDAR_FILE), exist_ok=True)
    with open(CALENDAR_FILE, "w") as f:
        json.dump(events, f, indent=2)

    print(f"[GoogleSync] Synced {len(events)} calendar events!")

def add_event(summary, start_time, end_time, description="", color_id=None, all_day=False):
    import time
    auth = load_auth()
    token = get_valid_access_token(auth)
    if not summary:
        print(json.dumps({"success": False, "message": "Falta el título"}))
        return

    # 1. Save locally first into calendar_events.json so it is immediately persistent and visible
    local_event = {
        "id": f"local_{int(time.time())}",
        "summary": summary,
        "description": description,
        "start": start_time,
        "end": end_time if end_time else start_time,
        "location": "",
        "colorId": str(color_id) if color_id else "",
        "htmlLink": "",
        "synced": False
    }

    existing_events = []
    if os.path.exists(CALENDAR_FILE):
        try:
            with open(CALENDAR_FILE, "r") as f:
                existing_events = json.load(f)
        except Exception:
            existing_events = []

    existing_events.insert(0, local_event)
    try:
        os.makedirs(os.path.dirname(CALENDAR_FILE), exist_ok=True)
        with open(CALENDAR_FILE, "w") as f:
            json.dump(existing_events, f, indent=2)
    except Exception as e:
        print(f"[GoogleSync] Error saving local event: {e}")

    # 2. Format times with timezone for Google API
    from datetime import datetime
    local_tz = datetime.now().astimezone().strftime("%z")
    tz_offset = f"{local_tz[:3]}:{local_tz[3:]}" if len(local_tz) == 5 else "-05:00"

    body = {
        "summary": summary,
        "description": description
    }
    if color_id:
        body["colorId"] = str(color_id)

    if all_day:
        body["start"] = {"date": start_time}
        body["end"] = {"date": end_time if end_time else start_time}
    else:
        st = start_time if ("+" in start_time or "Z" in start_time) else f"{start_time}{tz_offset}"
        et = end_time if ("+" in end_time or "Z" in end_time) else f"{end_time}{tz_offset}"
        body["start"] = {"dateTime": st}
        body["end"] = {"dateTime": et}

    result = {"success": True, "synced": False, "message": "Guardado localmente (se sincronizará luego)"}

    if token:
        resp = api_request("https://www.googleapis.com/calendar/v3/calendars/primary/events", token, method="POST", body=body)
        if resp and "id" in resp:
            sync_calendar()
            result = {"success": True, "synced": True, "message": "Sincronizado con Google Calendar"}
        else:
            result = {"success": True, "synced": False, "message": "Guardado localmente"}

    print(f"[RESULT]{json.dumps(result)}")
    return result

def sync_all():
    sync_tasks()
    sync_calendar()

if __name__ == "__main__":
    if len(sys.argv) < 2:
        cmd = "sync"
    else:
        cmd = sys.argv[1]

    if cmd == "login":
        login()
    elif cmd == "sync":
        sync_all()
    elif cmd == "add-task":
        if len(sys.argv) > 2:
            add_task(" ".join(sys.argv[2:]))
    elif cmd == "update-task":
        if len(sys.argv) > 3:
            update_task_status(sys.argv[2], " ".join(sys.argv[3:]))
    elif cmd == "delete-task":
        if len(sys.argv) > 2:
            delete_task(sys.argv[2])
    elif cmd == "add-event":
        if len(sys.argv) > 2:
            try:
                ev = json.loads(sys.argv[2])
                add_event(
                    summary=ev.get("summary", ""),
                    start_time=ev.get("start", ""),
                    end_time=ev.get("end", ""),
                    description=ev.get("description", ""),
                    color_id=ev.get("colorId", None),
                    all_day=ev.get("allDay", False)
                )
            except Exception as e:
                print(f"[GoogleSync] Error parsing event json: {e}")
    else:
        sync_all()
