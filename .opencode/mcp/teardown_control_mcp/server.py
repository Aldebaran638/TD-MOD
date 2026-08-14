"""Local stdio MCP for validating a live Teardown desktop session.

The implementation is Windows-only by design: it finds the real Teardown
window, restores/focuses it, captures its DPI-aware client rectangle, injects
input through an available virtual HID (with SendInput fallback), and reads
the game's log file.
"""

from __future__ import annotations

import atexit
import base64
import ctypes
from ctypes import wintypes
from dataclasses import dataclass, field
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import threading
import time
import uuid
from typing import Any, Optional

from telemetry_protocol import (
    PROTOCOL as TELEMETRY_PROTOCOL,
    build_request as build_telemetry_request,
    clipboard_restore_allowed,
    parse_response as parse_telemetry_response,
)

import mss
import hid
from PIL import Image, ImageStat
import psutil
from mcp.server.fastmcp import FastMCP


if os.name != "nt":  # pragma: no cover - the tool is explicitly Win32-only
    raise RuntimeError("teardown_control_mcp requires Windows")


user32 = ctypes.WinDLL("user32", use_last_error=True)
kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)

CF_UNICODETEXT = 13

user32.OpenClipboard.argtypes = [wintypes.HWND]
user32.OpenClipboard.restype = wintypes.BOOL
user32.CloseClipboard.argtypes = []
user32.CloseClipboard.restype = wintypes.BOOL
user32.IsClipboardFormatAvailable.argtypes = [wintypes.UINT]
user32.IsClipboardFormatAvailable.restype = wintypes.BOOL
user32.GetClipboardData.argtypes = [wintypes.UINT]
user32.GetClipboardData.restype = wintypes.HANDLE
user32.EmptyClipboard.argtypes = []
user32.EmptyClipboard.restype = wintypes.BOOL
user32.SetClipboardData.argtypes = [wintypes.UINT, wintypes.HANDLE]
user32.SetClipboardData.restype = wintypes.HANDLE
kernel32.GlobalLock.argtypes = [wintypes.HGLOBAL]
kernel32.GlobalLock.restype = ctypes.c_void_p
kernel32.GlobalUnlock.argtypes = [wintypes.HGLOBAL]
kernel32.GlobalUnlock.restype = wintypes.BOOL
kernel32.GlobalAlloc.argtypes = [wintypes.UINT, ctypes.c_size_t]
kernel32.GlobalAlloc.restype = wintypes.HGLOBAL
kernel32.GlobalFree.argtypes = [wintypes.HGLOBAL]
kernel32.GlobalFree.restype = wintypes.HGLOBAL
GMEM_MOVEABLE = 0x0002

SW_RESTORE = 9
SW_SHOW = 5
MOUSEEVENTF_MOVE = 0x0001
MOUSEEVENTF_LEFTDOWN = 0x0002
MOUSEEVENTF_LEFTUP = 0x0004
MOUSEEVENTF_RIGHTDOWN = 0x0008
MOUSEEVENTF_RIGHTUP = 0x0010
MOUSEEVENTF_MIDDLEDOWN = 0x0020
MOUSEEVENTF_MIDDLEUP = 0x0040
MOUSEEVENTF_VIRTUALDESK = 0x4000
MOUSEEVENTF_ABSOLUTE = 0x8000
KEYEVENTF_EXTENDEDKEY = 0x0001
KEYEVENTF_KEYUP = 0x0002
KEYEVENTF_SCANCODE = 0x0008
MAPVK_VK_TO_VSC = 0

ULONG_PTR = ctypes.c_void_p


class POINT(ctypes.Structure):
    _fields_ = [("x", wintypes.LONG), ("y", wintypes.LONG)]


class RECT(ctypes.Structure):
    _fields_ = [
        ("left", wintypes.LONG),
        ("top", wintypes.LONG),
        ("right", wintypes.LONG),
        ("bottom", wintypes.LONG),
    ]


class MOUSEINPUT(ctypes.Structure):
    _fields_ = [
        ("dx", wintypes.LONG),
        ("dy", wintypes.LONG),
        ("mouseData", wintypes.DWORD),
        ("dwFlags", wintypes.DWORD),
        ("time", wintypes.DWORD),
        ("dwExtraInfo", ULONG_PTR),
    ]


class KEYBDINPUT(ctypes.Structure):
    _fields_ = [
        ("wVk", wintypes.WORD),
        ("wScan", wintypes.WORD),
        ("dwFlags", wintypes.DWORD),
        ("time", wintypes.DWORD),
        ("dwExtraInfo", ULONG_PTR),
    ]


class INPUT_UNION(ctypes.Union):
    _fields_ = [("mi", MOUSEINPUT), ("ki", KEYBDINPUT)]


class INPUT(ctypes.Structure):
    _anonymous_ = ("u",)
    _fields_ = [("type", wintypes.DWORD), ("u", INPUT_UNION)]


user32.GetForegroundWindow.restype = wintypes.HWND
user32.GetCursorPos.argtypes = [ctypes.POINTER(POINT)]
user32.GetCursorPos.restype = wintypes.BOOL
user32.SetCursorPos.argtypes = [ctypes.c_int, ctypes.c_int]
user32.SetCursorPos.restype = wintypes.BOOL
user32.IsWindow.argtypes = [wintypes.HWND]
user32.IsWindow.restype = wintypes.BOOL
user32.IsWindowVisible.argtypes = [wintypes.HWND]
user32.IsWindowVisible.restype = wintypes.BOOL
user32.IsIconic.argtypes = [wintypes.HWND]
user32.IsIconic.restype = wintypes.BOOL
user32.GetClientRect.argtypes = [wintypes.HWND, ctypes.POINTER(RECT)]
user32.GetClientRect.restype = wintypes.BOOL
user32.ClientToScreen.argtypes = [wintypes.HWND, ctypes.POINTER(POINT)]
user32.ClientToScreen.restype = wintypes.BOOL
user32.GetWindowThreadProcessId.argtypes = [wintypes.HWND, ctypes.POINTER(wintypes.DWORD)]
user32.GetWindowThreadProcessId.restype = wintypes.DWORD
user32.SetForegroundWindow.argtypes = [wintypes.HWND]
user32.SetForegroundWindow.restype = wintypes.BOOL
user32.BringWindowToTop.argtypes = [wintypes.HWND]
user32.BringWindowToTop.restype = wintypes.BOOL
user32.ShowWindow.argtypes = [wintypes.HWND, ctypes.c_int]
user32.ShowWindow.restype = wintypes.BOOL
user32.PostMessageW.argtypes = [wintypes.HWND, wintypes.UINT, wintypes.WPARAM, wintypes.LPARAM]
user32.PostMessageW.restype = wintypes.BOOL
user32.SetActiveWindow.argtypes = [wintypes.HWND]
user32.SetActiveWindow.restype = wintypes.HWND
user32.SetFocus.argtypes = [wintypes.HWND]
user32.SetFocus.restype = wintypes.HWND
user32.AttachThreadInput.argtypes = [wintypes.DWORD, wintypes.DWORD, wintypes.BOOL]
user32.AttachThreadInput.restype = wintypes.BOOL
user32.GetWindowTextLengthW.argtypes = [wintypes.HWND]
user32.GetWindowTextLengthW.restype = ctypes.c_int
user32.GetWindowTextW.argtypes = [wintypes.HWND, wintypes.LPWSTR, ctypes.c_int]
user32.EnumWindows.argtypes = [ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM), wintypes.LPARAM]
user32.EnumWindows.restype = wintypes.BOOL
user32.SendInput.argtypes = [wintypes.UINT, ctypes.POINTER(INPUT), ctypes.c_int]
user32.SendInput.restype = wintypes.UINT
user32.MapVirtualKeyW.argtypes = [wintypes.UINT, wintypes.UINT]
user32.MapVirtualKeyW.restype = wintypes.UINT


def _set_dpi_awareness() -> None:
    """Make client coordinates and mss's physical capture rectangle agree."""

    try:
        set_context = user32.SetProcessDpiAwarenessContext
        set_context.argtypes = [ctypes.c_void_p]
        set_context.restype = wintypes.BOOL
        set_context(ctypes.c_void_p(-4))  # PER_MONITOR_AWARE_V2
        return
    except (AttributeError, OSError):
        pass
    try:
        shcore = ctypes.WinDLL("shcore", use_last_error=True)
        shcore.SetProcessDpiAwareness(2)  # PROCESS_PER_MONITOR_DPI_AWARE
    except (AttributeError, OSError):
        pass


_set_dpi_awareness()


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def _safe_int(value: Any, default: int = 0) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def _safe_float(value: Any, default: float = 0.0) -> float:
    try:
        result = float(value)
        return result if result == result and abs(result) != float("inf") else default
    except (TypeError, ValueError):
        return default


def _window_title(hwnd: int) -> str:
    length = user32.GetWindowTextLengthW(hwnd)
    if length <= 0:
        return ""
    buffer = ctypes.create_unicode_buffer(length + 1)
    user32.GetWindowTextW(hwnd, buffer, length + 1)
    return buffer.value


def _window_client(hwnd: int) -> dict[str, int]:
    rect = RECT()
    if not user32.GetClientRect(hwnd, ctypes.byref(rect)):
        return {"left": 0, "top": 0, "width": 0, "height": 0}
    point = POINT(rect.left, rect.top)
    if not user32.ClientToScreen(hwnd, ctypes.byref(point)):
        return {"left": 0, "top": 0, "width": 0, "height": 0}
    return {
        "left": int(point.x),
        "top": int(point.y),
        "width": max(0, int(rect.right - rect.left)),
        "height": max(0, int(rect.bottom - rect.top)),
    }


def _window_pid(hwnd: int) -> int:
    pid = wintypes.DWORD(0)
    user32.GetWindowThreadProcessId(hwnd, ctypes.byref(pid))
    return int(pid.value)


def _find_windows_for_pid(pid: int) -> list[int]:
    found: list[int] = []

    @ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)
    def callback(hwnd: int, _lparam: int) -> bool:
        if _window_pid(hwnd) == pid and user32.IsWindowVisible(hwnd):
            found.append(int(hwnd))
        return True

    user32.EnumWindows(callback, 0)
    return found


def _target_id(pid: int, hwnd: int) -> str:
    return f"teardown:{pid}:{hwnd}"


def _target_role(title: str, process_name: str = "") -> str:
    normalized = title.strip().lower()
    executable = process_name.strip().lower()
    if "host" in normalized or "server" in normalized:
        return "host"
    if "client" in normalized:
        return "client"
    if "editor" in normalized:
        return "editor"
    if executable in {"teardown_modtest.exe", "teardown_modtest"}:
        return "local-multiplayer-instance"
    return "unknown"


def _enumerate_teardown_targets() -> list[tuple[psutil.Process, int]]:
    candidates: list[tuple[psutil.Process, int]] = []
    for process in psutil.process_iter(["pid", "name"]):
        try:
            name = (process.info.get("name") or "").lower()
            if name not in {"teardown.exe", "teardown", "teardown_modtest.exe", "teardown_modtest"}:
                continue
            windows = _find_windows_for_pid(process.pid)
            for hwnd in windows:
                title = _window_title(hwnd).strip().lower()
                if title == "teardown" or "teardown" in title:
                    candidates.append((process, hwnd))
            if windows and not any(candidate[0].pid == process.pid for candidate in candidates):
                candidates.append((process, windows[0]))
        except (psutil.Error, OSError):
            continue
    def _created_at(item: tuple[psutil.Process, int]) -> float:
        try:
            return item[0].create_time() if item[0].is_running() else 0.0
        except psutil.Error:
            return 0.0

    foreground = int(user32.GetForegroundWindow() or 0)
    candidates.sort(key=lambda item: (int(item[1]) == foreground, _created_at(item), item[0].pid, item[1]), reverse=True)
    return candidates


def _find_teardown(target_id: Optional[str] = None) -> tuple[Optional[psutil.Process], Optional[int]]:
    candidates = _enumerate_teardown_targets()
    if not candidates:
        return None, None
    if target_id is None or not str(target_id).strip():
        return candidates[0]

    selector = str(target_id).strip().lower()
    for process, hwnd in candidates:
        identifiers = {
            _target_id(process.pid, hwnd).lower(),
            str(process.pid),
            str(hwnd),
            f"{process.pid}:{hwnd}",
        }
        if selector in identifiers:
            return process, hwnd
    return None, None


def _is_foreground(hwnd: int) -> bool:
    return bool(hwnd and int(user32.GetForegroundWindow() or 0) == int(hwnd))


def _focus_window(hwnd: int) -> bool:
    if not hwnd or not user32.IsWindow(hwnd):
        return False
    if user32.IsIconic(hwnd):
        user32.ShowWindow(hwnd, SW_RESTORE)
        # Teardown/SDL can leave the top-level window in a minimized placement
        # where ShowWindow is ignored.  The standard window-menu restore
        # command is the reliable fallback and does not fabricate game input.
        if user32.IsIconic(hwnd):
            user32.PostMessageW(hwnd, 0x0112, 0xF120, 0)  # WM_SYSCOMMAND/SC_RESTORE
    else:
        user32.ShowWindow(hwnd, SW_SHOW)
    foreground = int(user32.GetForegroundWindow() or 0)
    current_thread = int(kernel32.GetCurrentThreadId())
    target_thread = int(user32.GetWindowThreadProcessId(hwnd, None))
    foreground_thread = int(user32.GetWindowThreadProcessId(foreground, None)) if foreground else 0
    attached: list[tuple[int, int]] = []
    try:
        for source_thread, destination_thread in (
            (current_thread, foreground_thread),
            (current_thread, target_thread),
        ):
            if source_thread and destination_thread and source_thread != destination_thread:
                if user32.AttachThreadInput(source_thread, destination_thread, True):
                    attached.append((source_thread, destination_thread))
        user32.BringWindowToTop(hwnd)
        user32.SetForegroundWindow(hwnd)
        user32.SetActiveWindow(hwnd)
        user32.SetFocus(hwnd)
    finally:
        for source_thread, destination_thread in reversed(attached):
            user32.AttachThreadInput(source_thread, destination_thread, False)
    deadline = time.monotonic() + 1.5
    while time.monotonic() < deadline:
        if _is_foreground(hwnd):
            return True
        time.sleep(0.03)
    return _is_foreground(hwnd)


VK_CODES: dict[str, int] = {
    "backspace": 0x08,
    "tab": 0x09,
    "enter": 0x0D,
    "shift": 0x10,
    "ctrl": 0x11,
    "alt": 0x12,
    "pause": 0x13,
    "capslock": 0x14,
    "esc": 0x1B,
    "escape": 0x1B,
    "space": 0x20,
    "pageup": 0x21,
    "pagedown": 0x22,
    "end": 0x23,
    "home": 0x24,
    "left": 0x25,
    "up": 0x26,
    "right": 0x27,
    "down": 0x28,
    "insert": 0x2D,
    "delete": 0x2E,
    "lwin": 0x5B,
    "rwin": 0x5C,
    "f1": 0x70,
    "f2": 0x71,
    "f3": 0x72,
    "f4": 0x73,
    "f5": 0x74,
    "f6": 0x75,
    "f7": 0x76,
    "f8": 0x77,
    "f9": 0x78,
    "f10": 0x79,
    "f11": 0x7A,
    "f12": 0x7B,
}
for _letter in "abcdefghijklmnopqrstuvwxyz":
    VK_CODES[_letter] = ord(_letter.upper())
for _digit in "0123456789":
    VK_CODES[_digit] = ord(_digit)

EXTENDED_KEYS = {"left", "up", "right", "down", "insert", "delete", "home", "end", "pageup", "pagedown", "rwin"}

HID_KEY_CODES: dict[str, int] = {
    "enter": 0x28, "esc": 0x29, "escape": 0x29, "backspace": 0x2A,
    "tab": 0x2B, "space": 0x2C, "capslock": 0x39,
    "f1": 0x3A, "f2": 0x3B, "f3": 0x3C, "f4": 0x3D,
    "f5": 0x3E, "f6": 0x3F, "f7": 0x40, "f8": 0x41,
    "f9": 0x42, "f10": 0x43, "f11": 0x44, "f12": 0x45,
    "insert": 0x49, "home": 0x4A, "pageup": 0x4B, "delete": 0x4C,
    "end": 0x4D, "pagedown": 0x4E, "right": 0x4F, "left": 0x50,
    "down": 0x51, "up": 0x52,
}
for _index, _letter in enumerate("abcdefghijklmnopqrstuvwxyz", start=0x04):
    HID_KEY_CODES[_letter] = _index
for _digit, _code in zip("1234567890", range(0x1E, 0x28)):
    HID_KEY_CODES[_digit] = _code

HID_MODIFIERS = {"ctrl": 0x01, "shift": 0x02, "alt": 0x04, "lwin": 0x08, "rwin": 0x80}
GVINPUT_VID = 0x00FF
GVINPUT_PID = 0xBACC
GVINPUT_CONTROL_USAGE_PAGE = 0xFFEE


def _normalise_key(key: Any) -> str:
    value = str(key or "").strip().lower()
    if value == "control":
        return "ctrl"
    if value == "lcontrol":
        return "ctrl"
    if value == "lshift":
        return "shift"
    if value == "lalt":
        return "alt"
    return value


def _make_key_input(key: str, down: bool, method: str = "scan") -> INPUT:
    key = _normalise_key(key)
    if key not in VK_CODES:
        raise ValueError(f"unsupported key: {key!r}")
    vk = VK_CODES[key]
    flags = 0
    if not down:
        flags |= KEYEVENTF_KEYUP
    if method == "scan":
        scan = int(user32.MapVirtualKeyW(vk, MAPVK_VK_TO_VSC))
        if scan == 0:
            raise ValueError(f"no scan code for key: {key!r}")
        flags |= KEYEVENTF_SCANCODE
        if key in EXTENDED_KEYS:
            flags |= KEYEVENTF_EXTENDEDKEY
        return INPUT(type=1, ki=KEYBDINPUT(0, scan, flags, 0, None))
    if method == "virtual":
        return INPUT(type=1, ki=KEYBDINPUT(vk, 0, flags, 0, None))
    raise ValueError(f"unsupported key injection method: {method!r}")


def _make_mouse_input(flags: int, dx: int = 0, dy: int = 0) -> INPUT:
    return INPUT(type=0, mi=MOUSEINPUT(dx, dy, 0, flags, 0, None))


def _send_input(inputs: list[INPUT]) -> None:
    if not inputs:
        return
    array_type = INPUT * len(inputs)
    array = array_type(*inputs)
    sent = int(user32.SendInput(len(inputs), array, ctypes.sizeof(INPUT)))
    if sent != len(inputs):
        error = ctypes.get_last_error()
        raise OSError(error, f"SendInput accepted {sent}/{len(inputs)} events")


@dataclass
class TeardownState:
    lock: threading.RLock = field(default_factory=threading.RLock)
    run_id: Optional[str] = None
    run_dir: Optional[Path] = None
    run_cursor: int = 0
    last_frame_id: Optional[str] = None
    last_frame_target_id: Optional[str] = None
    frame_counter: int = 0
    held_keys: dict[str, str] = field(default_factory=dict)
    held_buttons: set[str] = field(default_factory=set)
    hid_keys: set[str] = field(default_factory=set)
    hid_buttons: set[str] = field(default_factory=set)
    telemetry_channel: Optional[str] = None
    telemetry_last_nonce: Optional[str] = None
    telemetry_session: Optional[str] = None
    telemetry_client_cursor: int = 0

    def ensure_run(self, log_path: Path) -> None:
        if self.run_id is not None:
            return
        self.run_id = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ") + "-" + uuid.uuid4().hex[:8]
        root = Path(os.environ.get("LOCALAPPDATA", str(Path.home()))) / "TeardownAI" / "runs"
        self.run_dir = root / self.run_id
        self.run_dir.mkdir(parents=True, exist_ok=True)
        self.run_cursor = log_path.stat().st_size if log_path.exists() else 0
        self.write_json("run_metadata.json", {"run_id": self.run_id, "started_at": _now_iso(), "log_cursor": self.run_cursor})

    def write_json(self, name: str, value: Any) -> None:
        if self.run_dir is None:
            return
        path = self.run_dir / name
        path.write_text(json.dumps(value, ensure_ascii=False, indent=2), encoding="utf-8")

    def append_jsonl(self, name: str, value: Any) -> None:
        if self.run_dir is None:
            return
        with (self.run_dir / name).open("a", encoding="utf-8") as stream:
            stream.write(json.dumps(value, ensure_ascii=False) + "\n")


STATE = TeardownState()
LOG_PATH = Path(os.environ.get("LOCALAPPDATA", str(Path.home()))) / "Teardown" / "log.txt"


def _gvinput_path() -> Optional[bytes]:
    for device in hid.enumerate(GVINPUT_VID, GVINPUT_PID):
        if int(device.get("usage_page", 0)) == GVINPUT_CONTROL_USAGE_PAGE:
            return device["path"]
    return None


def _gvinput_write(body: bytes) -> None:
    path = _gvinput_path()
    if path is None:
        raise RuntimeError("gvinput virtual HID control collection is unavailable")
    report = bytearray(65)
    report[0] = 0x40
    report[1] = len(body)
    report[2:2 + len(body)] = body
    device = hid.device()
    try:
        device.open_path(path)
        written = device.write(bytes(report))
        if written != len(report):
            raise OSError(f"gvinput accepted {written}/{len(report)} bytes")
    finally:
        device.close()


def _gvinput_keyboard() -> None:
    modifiers = 0
    codes: list[int] = []
    for key in sorted(STATE.hid_keys):
        if key in HID_MODIFIERS:
            modifiers |= HID_MODIFIERS[key]
        elif key in HID_KEY_CODES:
            codes.append(HID_KEY_CODES[key])
        else:
            raise ValueError(f"unsupported virtual HID key: {key!r}")
    if len(codes) > 6:
        raise ValueError("virtual HID supports at most six simultaneous non-modifier keys")
    _gvinput_write(bytes([0x07, modifiers, 0, *codes, *([0] * (6 - len(codes)))]))


def _gvinput_mouse(dx: int = 0, dy: int = 0) -> None:
    buttons = (1 if "lmb" in STATE.hid_buttons else 0) | (2 if "rmb" in STATE.hid_buttons else 0) | (4 if "mmb" in STATE.hid_buttons else 0)
    _gvinput_write(bytes([0x04, buttons, dx & 0xFF, dy & 0xFF, 0]))


def _target_snapshot(process: psutil.Process, hwnd: int, foreground: int) -> dict[str, Any]:
    try:
        created_at = datetime.fromtimestamp(process.create_time(), timezone.utc).isoformat().replace("+00:00", "Z")
    except (psutil.Error, OSError, ValueError):
        created_at = None
    title = _window_title(hwnd)
    try:
        process_name = process.name()
    except psutil.Error:
        process_name = "unknown"
    return {
        "target_id": _target_id(process.pid, hwnd),
        "pid": process.pid,
        "handle": int(hwnd),
        "process_name": process_name,
        "title": title,
        "role_hint": _target_role(title, process_name),
        "visible": bool(user32.IsWindowVisible(hwnd)),
        "minimized": bool(user32.IsIconic(hwnd)),
        "focused": foreground == int(hwnd),
        "created_at": created_at,
        "client": _window_client(hwnd),
    }


def _process_window_snapshot(target_id: Optional[str] = None) -> dict[str, Any]:
    candidates = _enumerate_teardown_targets()
    process, hwnd = _find_teardown(target_id)
    foreground = int(user32.GetForegroundWindow() or 0)
    instances = [_target_snapshot(candidate_process, candidate_hwnd, foreground) for candidate_process, candidate_hwnd in candidates]
    if process is None or hwnd is None:
        return {
            "process": {"present": False, "name": "teardown.exe"},
            "window": {"present": False, "foreground_handle": foreground, "requested_target_id": target_id},
            "instances": instances,
        }
    try:
        process_info = {
            "present": process.is_running(),
            "pid": process.pid,
            "name": process.name(),
            "status": process.status(),
            "responding": True,
        }
    except psutil.Error:
        process_info = {"present": True, "pid": process.pid, "name": "teardown.exe"}
    client = _window_client(hwnd)
    return {
        "process": process_info,
        "window": {
            "present": True,
            "target_id": _target_id(process.pid, hwnd),
            "handle": int(hwnd),
            "title": _window_title(hwnd),
            "role_hint": _target_role(_window_title(hwnd), process_info.get("name", "")),
            "visible": bool(user32.IsWindowVisible(hwnd)),
            "minimized": bool(user32.IsIconic(hwnd)),
            "focused": foreground == int(hwnd),
            "foreground_handle": foreground,
            "client": client,
        },
        "instances": instances,
    }


def _log_size() -> int:
    try:
        return LOG_PATH.stat().st_size
    except OSError:
        return 0


def _parse_ai_event(line: str) -> Optional[dict[str, Any]]:
    marker = "AI_TEST|"
    index = line.find(marker)
    if index < 0:
        return None
    fields: dict[str, Any] = {"raw": line}
    payload = line[index + len(marker):].strip()
    for part in payload.split("|"):
        if "=" not in part:
            continue
        key, value = part.split("=", 1)
        fields[key] = value
    return fields


def _parse_protocol_event(line: str) -> Optional[dict[str, Any]]:
    marker = "CM2_TEST_V1|"
    index = line.find(marker)
    if index < 0:
        return None
    payload = line[index + len(marker):].strip()
    fields: dict[str, Any] = {"raw": line, "protocol": "CM2_TEST_V1"}
    parts = payload.split("|")
    if parts:
        fields["type"] = parts[0]
    for part in parts[1:]:
        if "=" not in part:
            continue
        key, value = part.split("=", 1)
        fields[key] = value
    return fields


def _clipboard_read_text() -> str:
    """Read CF_UNICODETEXT without changing ownership of the clipboard data."""

    if not user32.OpenClipboard(0):
        raise OSError(ctypes.get_last_error(), "OpenClipboard failed")
    try:
        if not user32.IsClipboardFormatAvailable(CF_UNICODETEXT):
            return ""
        handle = user32.GetClipboardData(CF_UNICODETEXT)
        if not handle:
            return ""
        pointer = kernel32.GlobalLock(handle)
        if not pointer:
            raise OSError(ctypes.get_last_error(), "GlobalLock failed")
        try:
            return ctypes.wstring_at(pointer)
        finally:
            kernel32.GlobalUnlock(handle)
    finally:
        user32.CloseClipboard()


def _clipboard_write_text(value: str) -> None:
    encoded = (value or "").encode("utf-16-le") + b"\x00\x00"
    allocation = kernel32.GlobalAlloc(GMEM_MOVEABLE, len(encoded))
    if not allocation:
        raise OSError(ctypes.get_last_error(), "GlobalAlloc failed")
    pointer = kernel32.GlobalLock(allocation)
    if not pointer:
        kernel32.GlobalFree(allocation)
        raise OSError(ctypes.get_last_error(), "GlobalLock failed")
    try:
        ctypes.memmove(pointer, encoded, len(encoded))
    finally:
        kernel32.GlobalUnlock(allocation)
    if not user32.OpenClipboard(0):
        kernel32.GlobalFree(allocation)
        raise OSError(ctypes.get_last_error(), "OpenClipboard failed")
    try:
        if not user32.EmptyClipboard():
            raise OSError(ctypes.get_last_error(), "EmptyClipboard failed")
        if not user32.SetClipboardData(CF_UNICODETEXT, allocation):
            raise OSError(ctypes.get_last_error(), "SetClipboardData failed")
        # Ownership transfers to the clipboard after SetClipboardData.
        allocation = None
    finally:
        user32.CloseClipboard()
        if allocation:
            kernel32.GlobalFree(allocation)


def _telemetry_request_text(nonce: str, command: str, after_seq: int = 0,
                            target_body_id: int = 0, amount: float = 0.0,
                            client_after_seq: int = 0) -> str:
    return build_telemetry_request(
        nonce, command, after_seq, target_body_id, amount, client_after_seq
    )


def _parse_telemetry_response(text: str) -> Optional[dict[str, Any]]:
    value = parse_telemetry_response(text)
    return value if isinstance(value, dict) else None


def _write_run_result(value: dict[str, Any]) -> None:
    """Keep a compact latest-result envelope alongside append-only evidence."""

    existing: dict[str, Any] = {}
    if STATE.run_dir is not None:
        path = STATE.run_dir / "result.json"
        try:
            loaded = json.loads(path.read_text(encoding="utf-8"))
            if isinstance(loaded, dict):
                existing = loaded
        except (OSError, json.JSONDecodeError):
            existing = {}
    existing.update({"run_id": STATE.run_id, "updated_at": _now_iso(), **value})
    STATE.write_json("result.json", existing)


def _telemetry_exchange(command: str, after_seq: int = 0,
                        target_body_id: int = 0, amount: float = 0.0,
                        timeout: float = 2.5) -> dict[str, Any]:
    nonce = uuid.uuid4().hex
    request = _telemetry_request_text(
        nonce, command, after_seq, target_body_id, amount,
        STATE.telemetry_client_cursor,
    )
    original = _clipboard_read_text()
    selected_target_id = STATE.last_frame_target_id
    bridge_opened = False
    try:
        _snapshot, hwnd = _ensure_target(focus=True, target_id=selected_target_id)
        if not _is_foreground(hwnd):
            raise RuntimeError("Teardown telemetry target is not foreground")
        _clipboard_write_text(request)
        _execute_action({"type": "key_tap", "key": "f8", "duration_ms": 80})
        bridge_opened = True
        time.sleep(0.12)
        _execute_action({"type": "key_down", "key": "ctrl"})
        _execute_action({"type": "key_tap", "key": "v", "duration_ms": 50})
        _execute_action({"type": "key_up", "key": "ctrl"})
    except (OSError, RuntimeError, ValueError) as exc:
        _release_all_inputs()
        current = _clipboard_read_text()
        restored = False
        restore_conflict = current != request
        if not restore_conflict:
            _clipboard_write_text(original)
            restored = _clipboard_read_text() == original
        result = {
            "ok": False,
            "nonce": nonce,
            "request": request,
            "response": None,
            "response_text": "",
            "clipboard_restored": restored,
            "clipboard_restore_conflict": restore_conflict,
            "timeout": False,
            "error": str(exc),
            "transport": "ui-text-input",
        }
        STATE.append_jsonl("telemetry.jsonl", {"at": _now_iso(), **result})
        return result

    deadline = time.monotonic() + max(0.1, min(timeout, 10.0))
    response: Optional[dict[str, Any]] = None
    response_text = ""
    while time.monotonic() < deadline:
        if not _is_foreground(hwnd):
            break
        current = _clipboard_read_text()
        if current not in {request, response_text}:
            break
        _execute_action({"type": "key_down", "key": "ctrl"})
        _execute_action({"type": "key_tap", "key": "a", "duration_ms": 35})
        _execute_action({"type": "key_tap", "key": "c", "duration_ms": 35})
        _execute_action({"type": "key_up", "key": "ctrl"})
        time.sleep(0.05)
        current = _clipboard_read_text()
        parsed = _parse_telemetry_response(current)
        if (
            parsed is not None
            and str(parsed.get("protocol", "")) == TELEMETRY_PROTOCOL
            and str(parsed.get("type", "")) == "response"
            and str(parsed.get("command", "")) == command
            and str(parsed.get("session", "")) != ""
            and str(parsed.get("nonce", "")) == nonce
        ):
            response = parsed
            response_text = current
            break
        if current != request:
            break
        time.sleep(0.08)

    current = _clipboard_read_text()
    restore_conflict = not clipboard_restore_allowed(
        original, request, current, response_text
    )
    restored = False
    if not restore_conflict:
        _clipboard_write_text(original)
        restored = _clipboard_read_text() == original
    # The focused UiTextInput consumes F8, so the bridge closes itself shortly
    # after exposing a response.  Wait out that bounded window before allowing
    # gameplay input; sending F8 here could be swallowed or reopen the bridge.
    if bridge_opened and response is not None and _is_foreground(hwnd):
        time.sleep(0.55)

    result: dict[str, Any] = {
        "ok": response is not None,
        "nonce": nonce,
        "request": request,
        "response": response,
        "response_text": response_text,
        "clipboard_restored": restored,
        "clipboard_restore_conflict": restore_conflict,
        "timeout": response is None,
        "transport": "ui-text-input",
    }
    STATE.telemetry_last_nonce = nonce
    STATE.append_jsonl("telemetry.jsonl", {"at": _now_iso(), **result})
    return result


def _read_log(cursor: Optional[int]) -> dict[str, Any]:
    start = _safe_int(cursor, STATE.run_cursor) if cursor is not None else STATE.run_cursor
    try:
        size = LOG_PATH.stat().st_size
        if start < 0 or start > size:
            start = 0
        with LOG_PATH.open("rb") as stream:
            stream.seek(start)
            data = stream.read()
    except OSError as exc:
        return {"ok": False, "error": f"cannot read log: {exc}", "cursor": start, "next_cursor": start, "events": [], "errors": [], "warnings": []}

    complete_length = data.rfind(b"\n") + 1
    complete = data[:complete_length]
    next_cursor = start + complete_length
    text = complete.decode("utf-8", errors="replace")
    lines = [line.rstrip("\r") for line in text.splitlines()]
    events: list[dict[str, Any]] = []
    errors: list[str] = []
    warnings: list[str] = []
    for line in lines:
        event = _parse_ai_event(line) or _parse_protocol_event(line)
        if event is not None:
            events.append(event)
        if " ERROR " in line or line.lstrip().startswith("ERROR"):
            errors.append(line)
        if " WARNING " in line or line.lstrip().startswith("WARNING"):
            warnings.append(line)
    max_lines = 2000
    result = {
        "ok": True,
        "cursor": start,
        "next_cursor": next_cursor,
        "bytes_read": complete_length,
        "events": events[-max_lines:],
        "errors": errors[-max_lines:],
        "warnings": warnings[-max_lines:],
        "event_count": len(events),
        "error_count": len(errors),
        "warning_count": len(warnings),
    }
    STATE.run_cursor = next_cursor if cursor is None else STATE.run_cursor
    return result


class CaptureError(RuntimeError):
    pass


def _frame_metrics(image: Image.Image) -> tuple[float, float]:
    grayscale = image.convert("L")
    stats = ImageStat.Stat(grayscale)
    return float(stats.mean[0]), float(stats.var[0])


def _capture_client(hwnd: int) -> tuple[Image.Image, dict[str, int], float, float]:
    first_rect = _window_client(hwnd)
    if first_rect["width"] <= 0 or first_rect["height"] <= 0:
        raise CaptureError(f"invalid client rectangle: {first_rect}")
    time.sleep(0.12)
    second_rect = _window_client(hwnd)
    if second_rect != first_rect and second_rect["width"] > 0 and second_rect["height"] > 0:
        first_rect = second_rect
    region = {key: first_rect[key] for key in ("left", "top", "width", "height")}
    with mss.mss() as screen:
        shot = screen.grab(region)
    image = Image.frombytes("RGB", shot.size, shot.bgra, "raw", "BGRX")
    mean, variance = _frame_metrics(image)
    if image.width != region["width"] or image.height != region["height"]:
        raise CaptureError(f"capture dimensions do not match client rectangle: {image.size} != {(region['width'], region['height'])}")
    if mean <= 2.0 or variance <= 1.0:
        raise CaptureError(f"capture is black or near-constant: mean={mean:.3f}, variance={variance:.3f}")
    return image, region, mean, variance


def _ensure_target(focus: bool = False, target_id: Optional[str] = None) -> tuple[dict[str, Any], int]:
    snapshot = _process_window_snapshot(target_id)
    window = snapshot.get("window", {})
    hwnd = _safe_int(window.get("handle"), 0)
    if not hwnd:
        if target_id:
            raise RuntimeError(f"Teardown target was not found: {target_id}")
        raise RuntimeError("Teardown window was not found")
    if focus and not _is_foreground(hwnd):
        if not _focus_window(hwnd):
            raise RuntimeError("could not restore and focus Teardown")
        snapshot = _process_window_snapshot(target_id)
    return snapshot, hwnd


def _release_all_inputs() -> dict[str, Any]:
    released_keys: list[str] = []
    released_buttons: list[str] = []
    with STATE.lock:
        if STATE.hid_keys:
            STATE.hid_keys.clear()
            try:
                _gvinput_keyboard()
            except (OSError, RuntimeError, ValueError):
                pass
        if STATE.hid_buttons:
            STATE.hid_buttons.clear()
            try:
                _gvinput_mouse()
            except (OSError, RuntimeError, ValueError):
                pass
        for key, method in list(STATE.held_keys.items()):
            try:
                _send_input([_make_key_input(key, False, method)])
            except (OSError, ValueError):
                pass
            released_keys.append(key)
        for button in list(STATE.held_buttons):
            flags = {"lmb": MOUSEEVENTF_LEFTUP, "rmb": MOUSEEVENTF_RIGHTUP, "mmb": MOUSEEVENTF_MIDDLEUP}.get(button)
            if flags is not None:
                try:
                    _send_input([_make_mouse_input(flags)])
                except OSError:
                    pass
            released_buttons.append(button)
        STATE.held_keys.clear()
        STATE.held_buttons.clear()
    return {"released_keys": released_keys, "released_buttons": released_buttons}


def _inject_key(key: str, down: bool, method: Optional[str] = None) -> str:
    normalised = _normalise_key(key)
    selected = method or STATE.held_keys.get(normalised) or ("hid" if _gvinput_path() else "scan")
    if selected == "hid":
        if normalised not in HID_KEY_CODES and normalised not in HID_MODIFIERS:
            raise ValueError(f"unsupported virtual HID key: {normalised!r}")
        if down:
            STATE.hid_keys.add(normalised)
        else:
            STATE.hid_keys.discard(normalised)
        try:
            _gvinput_keyboard()
        except Exception:
            if down:
                STATE.hid_keys.discard(normalised)
            else:
                STATE.hid_keys.add(normalised)
            raise
        if down:
            STATE.held_keys[normalised] = selected
        else:
            STATE.held_keys.pop(normalised, None)
        return selected
    try:
        _send_input([_make_key_input(normalised, down, selected)])
    except OSError:
        if method is not None:
            raise
        selected = "virtual" if selected == "scan" else "scan"
        _send_input([_make_key_input(normalised, down, selected)])
    if down:
        STATE.held_keys[normalised] = selected
    else:
        STATE.held_keys.pop(normalised, None)
    return selected


def _inject_button(button: str, down: bool, method: Optional[str] = None) -> str:
    normalised = str(button or "").lower()
    flags = {
        "lmb": (MOUSEEVENTF_LEFTDOWN, MOUSEEVENTF_LEFTUP),
        "left": (MOUSEEVENTF_LEFTDOWN, MOUSEEVENTF_LEFTUP),
        "rmb": (MOUSEEVENTF_RIGHTDOWN, MOUSEEVENTF_RIGHTUP),
        "right": (MOUSEEVENTF_RIGHTDOWN, MOUSEEVENTF_RIGHTUP),
        "mmb": (MOUSEEVENTF_MIDDLEDOWN, MOUSEEVENTF_MIDDLEUP),
        "middle": (MOUSEEVENTF_MIDDLEDOWN, MOUSEEVENTF_MIDDLEUP),
    }.get(normalised)
    if flags is None:
        raise ValueError(f"unsupported mouse button: {button!r}")
    canonical = {"left": "lmb", "right": "rmb", "middle": "mmb"}.get(normalised, normalised)
    selected = method or ("hid" if _gvinput_path() else "sendinput")
    if selected == "hid":
        if down:
            STATE.hid_buttons.add(canonical)
        else:
            STATE.hid_buttons.discard(canonical)
        try:
            _gvinput_mouse()
        except Exception:
            if down:
                STATE.hid_buttons.discard(canonical)
            else:
                STATE.hid_buttons.add(canonical)
            raise
    elif selected == "sendinput":
        _send_input([_make_mouse_input(flags[0 if down else 1])])
    else:
        raise ValueError(f"unsupported mouse input method: {selected!r}")
    if down:
        STATE.held_buttons.add(canonical)
    else:
        STATE.held_buttons.discard(canonical)
    return selected


def _action_kind(action: dict[str, Any]) -> str:
    return str(action.get("type", action.get("action", ""))).strip().lower()


def _action_duration(action: dict[str, Any], kind: str) -> float:
    if kind in {"wait", "sleep"}:
        if "seconds" in action and "duration_ms" not in action and "ms" not in action:
            return max(0.0, _safe_float(action.get("seconds"), 0.0))
        return max(0.0, _safe_float(action.get("duration_ms", action.get("ms", 0)), 0.0) / 1000.0)
    if kind in {"tap", "key_tap", "mouse_click", "click"}:
        return max(0.0, _safe_float(action.get("duration_ms", 60), 60.0) / 1000.0)
    return 0.0


def _execute_action(action: dict[str, Any]) -> dict[str, Any]:
    kind = _action_kind(action)
    if kind in {"wait", "sleep"}:
        duration = _action_duration(action, kind)
        time.sleep(duration)
        return {"type": kind, "duration_ms": round(duration * 1000, 3)}
    if kind in {"key_down", "keydown"}:
        key = _normalise_key(action.get("key"))
        method = _inject_key(key, True, action.get("method"))
        return {"type": "key_down", "key": key, "method": method}
    if kind in {"key_up", "keyup"}:
        key = _normalise_key(action.get("key"))
        method = _inject_key(key, False, action.get("method"))
        return {"type": "key_up", "key": key, "method": method}
    if kind in {"tap", "key_tap"}:
        key = _normalise_key(action.get("key"))
        method = _inject_key(key, True, action.get("method"))
        duration = _action_duration(action, kind)
        time.sleep(duration)
        _inject_key(key, False, method)
        return {"type": "tap", "key": key, "method": method, "duration_ms": round(duration * 1000, 3)}
    if kind in {"mouse_move", "move"}:
        dx = _safe_int(action.get("dx", action.get("x", 0)))
        dy = _safe_int(action.get("dy", action.get("y", 0)))
        method = str(action.get("method") or ("hid" if _gvinput_path() else "sendinput"))
        if method == "hid":
            if not -127 <= dx <= 127 or not -127 <= dy <= 127:
                raise ValueError("virtual HID relative movement must be between -127 and 127 per axis")
            _gvinput_mouse(dx, dy)
        elif method == "sendinput":
            _send_input([_make_mouse_input(MOUSEEVENTF_MOVE, dx, dy)])
        else:
            raise ValueError(f"unsupported mouse input method: {method!r}")
        return {"type": "mouse_move", "dx": dx, "dy": dy, "method": method}
    if kind in {"mouse_down", "button_down"}:
        button = str(action.get("button", "lmb"))
        method = _inject_button(button, True, action.get("method"))
        return {"type": "mouse_down", "button": button, "method": method}
    if kind in {"mouse_up", "button_up"}:
        button = str(action.get("button", "lmb"))
        method = _inject_button(button, False, action.get("method"))
        return {"type": "mouse_up", "button": button, "method": method}
    if kind in {"mouse_click", "click", "button_tap"}:
        button = str(action.get("button", "lmb"))
        method = _inject_button(button, True, action.get("method"))
        duration = _action_duration(action, kind)
        time.sleep(duration)
        _inject_button(button, False, method)
        return {"type": "mouse_click", "button": button, "method": method, "duration_ms": round(duration * 1000, 3)}
    raise ValueError(f"unsupported action type: {kind!r}")


def _move_cursor_to_screen(screen_x: int, screen_y: int) -> str:
    method = "win32-client"
    if not user32.SetCursorPos(screen_x, screen_y):
        if _gvinput_path() is None:
            raise OSError(ctypes.get_last_error(), "SetCursorPos failed and virtual HID is unavailable")
        method = "hid-closed-loop-client"
        # Windows pointer acceleration makes one large relative move unreliable.
        # Re-read the physical cursor and converge with small proportional steps.
        for _attempt in range(50):
            cursor = POINT()
            if not user32.GetCursorPos(ctypes.byref(cursor)):
                raise OSError(ctypes.get_last_error(), "GetCursorPos failed during HID movement")
            remaining_x = screen_x - int(cursor.x)
            remaining_y = screen_y - int(cursor.y)
            if abs(remaining_x) <= 3 and abs(remaining_y) <= 3:
                break
            step_x = max(-50, min(50, round(remaining_x * 0.35)))
            step_y = max(-50, min(50, round(remaining_y * 0.35)))
            _gvinput_mouse(step_x, step_y)
            time.sleep(0.025)
        cursor = POINT()
        if not user32.GetCursorPos(ctypes.byref(cursor)):
            raise OSError(ctypes.get_last_error(), "GetCursorPos failed after HID movement")
        if abs(screen_x - int(cursor.x)) > 3 or abs(screen_y - int(cursor.y)) > 3:
            raise RuntimeError(
                f"closed-loop HID could not reach screen coordinate: "
                f"wanted ({screen_x}, {screen_y}), got ({int(cursor.x)}, {int(cursor.y)})"
            )
    return method


def _move_cursor_to_client(hwnd: int, action: dict[str, Any]) -> dict[str, Any]:
    client = _window_client(hwnd)
    x = _safe_int(action.get("x"), -1)
    y = _safe_int(action.get("y"), -1)
    if x < 0 or y < 0 or x >= client["width"] or y >= client["height"]:
        raise ValueError(
            f"mouse_move_to coordinates must stay inside the Teardown client: "
            f"({x}, {y}) not in {client['width']}x{client['height']}"
        )
    screen_x = client["left"] + x
    screen_y = client["top"] + y
    method = _move_cursor_to_screen(screen_x, screen_y)
    return {
        "type": "mouse_move_to",
        "x": x,
        "y": y,
        "screen_x": screen_x,
        "screen_y": screen_y,
        "method": method,
    }


mcp = FastMCP("teardown-control")


@mcp.tool()
def teardown_instances() -> dict[str, Any]:
    """Enumerate every visible Teardown process/window as a selectable target."""

    with STATE.lock:
        STATE.ensure_run(LOG_PATH)
        snapshot = _process_window_snapshot()
        result = {
            "ok": True,
            "run_id": STATE.run_id,
            "foreground_handle": snapshot.get("window", {}).get("foreground_handle"),
            "instances": snapshot.get("instances", []),
        }
        STATE.write_json("instances.json", result)
        return result


@mcp.tool()
def teardown_status(target_id: Optional[str] = None) -> dict[str, Any]:
    """Return process/window/focus/client-area state for one selectable Teardown target."""

    with STATE.lock:
        STATE.ensure_run(LOG_PATH)
        snapshot = _process_window_snapshot(target_id)
        result = {
            "ok": True,
            "run_id": STATE.run_id,
            "log": {"path": str(LOG_PATH), "cursor": STATE.run_cursor, "size": _log_size(), "exists": LOG_PATH.exists()},
            **snapshot,
            "held_inputs": {"keys": sorted(STATE.held_keys), "buttons": sorted(STATE.held_buttons)},
            "input_backends": {"virtual_hid": bool(_gvinput_path()), "sendinput": True},
        }
        STATE.write_json("status_initial.json", result)
        return result


@mcp.tool()
def teardown_observe(restore: bool = True, target_id: Optional[str] = None) -> dict[str, Any]:
    """Restore/focus one target and return a validated full client-area PNG."""

    with STATE.lock:
        STATE.ensure_run(LOG_PATH)
        try:
            snapshot, hwnd = _ensure_target(focus=bool(restore), target_id=target_id)
            if not snapshot["window"].get("focused"):
                raise RuntimeError("refusing occluded capture: Teardown is not the foreground window")
            image, client, mean, variance = _capture_client(hwnd)
        except (CaptureError, RuntimeError, OSError) as exc:
            result = {"ok": False, "run_id": STATE.run_id, "error": str(exc), "status": _process_window_snapshot(target_id)}
            STATE.append_jsonl("observations.jsonl", result)
            return result

        STATE.frame_counter += 1
        frame_id = f"f{STATE.frame_counter:06d}-{uuid.uuid4().hex[:8]}"
        STATE.last_frame_id = frame_id
        STATE.last_frame_target_id = snapshot["window"].get("target_id")
        filename = f"frame_{frame_id}_pid-{snapshot['process'].get('pid', 0)}.png"
        path = STATE.run_dir / filename
        image.save(path, format="PNG", optimize=False)
        png_base64 = base64.b64encode(path.read_bytes()).decode("ascii")
        feedback = _read_log(None)
        result = {
            "ok": True,
            "run_id": STATE.run_id,
            "frame_id": frame_id,
            "target_id": STATE.last_frame_target_id,
            "png_filename": filename,
            "png_path": str(path),
            "png_base64": png_base64,
            "width": image.width,
            "height": image.height,
            "client": client,
            "mean_luma": round(mean, 4),
            "variance": round(variance, 4),
            "status": snapshot,
            "feedback": feedback,
        }
        STATE.write_json(f"observation_{frame_id}.json", {key: value for key, value in result.items() if key != "png_base64"})
        STATE.append_jsonl("observations.jsonl", {key: value for key, value in result.items() if key != "png_base64"})
        return result


@mcp.tool()
def teardown_control(frame_id: str, actions: list[dict[str, Any]], target_id: Optional[str] = None) -> dict[str, Any]:
    """Execute at most 20 safe key/mouse/wait actions against the observed frame."""

    with STATE.lock:
        STATE.ensure_run(LOG_PATH)
        if not isinstance(actions, list) or len(actions) > 20:
            return {"ok": False, "error": "actions must be a list of at most 20 steps", "run_id": STATE.run_id}
        if not STATE.last_frame_id or frame_id != STATE.last_frame_id:
            return {"ok": False, "error": "frame_id is stale or was not produced by teardown_observe", "run_id": STATE.run_id}
        selected_target_id = target_id or STATE.last_frame_target_id
        if not selected_target_id or selected_target_id != STATE.last_frame_target_id:
            return {"ok": False, "error": "target_id does not match the observed frame", "run_id": STATE.run_id}
        total_duration = sum(_action_duration(item, _action_kind(item)) for item in actions if isinstance(item, dict))
        if total_duration > 5.0:
            return {"ok": False, "error": f"action duration exceeds 5 seconds: {total_duration:.3f}", "run_id": STATE.run_id}
        executed: list[dict[str, Any]] = []
        started = time.monotonic()
        try:
            for index, action in enumerate(actions):
                if not isinstance(action, dict):
                    raise ValueError(f"action {index} is not an object")
                snapshot, hwnd = _ensure_target(focus=False, target_id=selected_target_id)
                if not _is_foreground(hwnd):
                    raise RuntimeError(f"refusing action {index}: Teardown is not foreground")
                if _action_kind(action) == "mouse_move_to":
                    executed.append({"index": index, **_move_cursor_to_client(hwnd, action)})
                else:
                    executed.append({"index": index, **_execute_action(action)})
        except (OSError, RuntimeError, ValueError) as exc:
            _release_all_inputs()
            result = {"ok": False, "run_id": STATE.run_id, "error": str(exc), "executed": executed, "released": True}
            STATE.append_jsonl("actions.jsonl", {"at": _now_iso(), **result})
            return result
        feedback = _read_log(None)
        result = {
            "ok": True,
            "run_id": STATE.run_id,
            "frame_id": frame_id,
            "executed": executed,
            "elapsed_ms": round((time.monotonic() - started) * 1000, 3),
            "held_inputs": {"keys": sorted(STATE.held_keys), "buttons": sorted(STATE.held_buttons)},
            "feedback": feedback,
        }
        STATE.append_jsonl("actions.jsonl", {"at": _now_iso(), **result})
        return result


@mcp.tool()
def teardown_log_read(cursor: Optional[int] = None) -> dict[str, Any]:
    """Read incremental protocol/log markers and new ERROR/WARNING lines."""

    with STATE.lock:
        STATE.ensure_run(LOG_PATH)
        result = _read_log(cursor)
        result["run_id"] = STATE.run_id
        STATE.append_jsonl("log_reads.jsonl", {"at": _now_iso(), **result})
        return result


@mcp.tool()
def teardown_telemetry_probe(timeout: float = 2.5) -> dict[str, Any]:
    """Probe CM2_TEST_V1 and report whether the UI bridge and log channels work."""

    with STATE.lock:
        STATE.ensure_run(LOG_PATH)
        before_cursor = _log_size()
        try:
            exchange = _telemetry_exchange("probe", timeout=timeout)
        except (OSError, RuntimeError, ValueError) as exc:
            result = {
                "ok": False,
                "run_id": STATE.run_id,
                "error": str(exc),
                "channel": "unavailable",
            }
            STATE.append_jsonl("telemetry_probe.jsonl", {"at": _now_iso(), **result})
            return result
        log_result = _read_log(before_cursor)
        nonce = exchange.get("nonce", "")
        log_markers = [
            event for event in log_result.get("events", [])
            if str(event.get("raw", "")).find("CM2_TEST_V1|log_probe|nonce=" + nonce) >= 0
        ]
        bridge_ok = bool(exchange.get("ok")) and bool(exchange.get("clipboard_restored"))
        log_ok = bool(log_markers)
        channel = "ui-text-input"
        if bridge_ok and log_ok:
            channel = "ui-text-input+log"
        elif log_ok:
            channel = "log"
        STATE.telemetry_channel = channel if bridge_ok or log_ok else "unavailable"
        result = {
            "ok": bridge_ok or log_ok,
            "run_id": STATE.run_id,
            "channel": STATE.telemetry_channel,
            "ui_text_input": {
                "ok": bridge_ok,
                "transport": exchange.get("transport", "ui-text-input"),
                "restored": bool(exchange.get("clipboard_restored")),
                "restore_conflict": bool(exchange.get("clipboard_restore_conflict")),
                "timeout": bool(exchange.get("timeout")),
            },
            "log": {
                "ok": log_ok,
                "cursor": before_cursor,
                "next_cursor": log_result.get("next_cursor", before_cursor),
                "markers": log_markers,
                "errors": log_result.get("errors", []),
                "warnings": log_result.get("warnings", []),
            },
            "response": exchange.get("response"),
        }
        STATE.write_json("telemetry_probe.json", result)
        _write_run_result({"telemetry_probe": result, "telemetry_channel": STATE.telemetry_channel})
        STATE.append_jsonl("telemetry_probe.jsonl", {"at": _now_iso(), **result})
        return result


@mcp.tool()
def teardown_telemetry_read(after_seq: int = 0, timeout: float = 2.5) -> dict[str, Any]:
    """Read CM2_TEST_V1 state through the focused F8 UiTextInput bridge."""

    with STATE.lock:
        STATE.ensure_run(LOG_PATH)
        try:
            result = _telemetry_exchange("read", after_seq=after_seq, timeout=timeout)
        except (OSError, RuntimeError, ValueError) as exc:
            result = {"ok": False, "run_id": STATE.run_id, "error": str(exc)}
            STATE.append_jsonl("telemetry_reads.jsonl", {"at": _now_iso(), **result})
            return result
        result["run_id"] = STATE.run_id
        response = result.get("response")
        if isinstance(response, dict):
            response_session = str(response.get("session", "") or "")
            if response_session and response_session != STATE.telemetry_session:
                STATE.telemetry_session = response_session
                STATE.telemetry_client_cursor = 0
            result["latest_seq"] = response.get("latest_seq", 0)
            result["next_after_seq"] = response.get("next_after_seq", after_seq)
            result["snapshot"] = response.get("snapshot")
            result["events"] = response.get("events", [])
            result["truncated"] = bool(response.get("truncated"))
            client_latest = response.get("client_latest_seq")
            if client_latest is not None:
                STATE.telemetry_client_cursor = max(0, int(client_latest or 0))
        _write_run_result({"telemetry_read": result})
        STATE.append_jsonl("telemetry_reads.jsonl", {"at": _now_iso(), **result})
        return result


@mcp.tool()
def teardown_damage_probe(target_body_id: int, amount: float,
                          timeout: float = 2.5) -> dict[str, Any]:
    """Apply bounded test damage to a registered, living ship body."""

    with STATE.lock:
        STATE.ensure_run(LOG_PATH)
        if int(target_body_id) <= 0 or float(amount) <= 0.0:
            return {
                "ok": False,
                "run_id": STATE.run_id,
                "error": "target_body_id and amount must be positive",
            }
        try:
            result = _telemetry_exchange(
                "damage",
                target_body_id=int(target_body_id),
                amount=float(amount),
                timeout=timeout,
            )
        except (OSError, RuntimeError, ValueError) as exc:
            result = {"ok": False, "run_id": STATE.run_id, "error": str(exc)}
            STATE.append_jsonl("damage_probes.jsonl", {"at": _now_iso(), **result})
            return result
        result["run_id"] = STATE.run_id
        response = result.get("response")
        if isinstance(response, dict):
            result["ok"] = bool(response.get("ok", False))
            if response.get("error"):
                result["error"] = response.get("error")
            result["damage"] = response.get("damage")
            result["snapshot"] = response.get("snapshot")
            result["events"] = response.get("events", [])
        _write_run_result({"damage_probe": result})
        STATE.append_jsonl("damage_probes.jsonl", {"at": _now_iso(), **result})
        return result


@mcp.tool()
def teardown_emergency_release() -> dict[str, Any]:
    """Release every key/button tracked by this MCP process."""

    with STATE.lock:
        STATE.ensure_run(LOG_PATH)
        released = _release_all_inputs()
        result = {"ok": True, "run_id": STATE.run_id, **released, "held_inputs": {"keys": [], "buttons": []}}
        STATE.append_jsonl("emergency_release.jsonl", {"at": _now_iso(), **result})
        return result


def _cleanup() -> None:
    try:
        _release_all_inputs()
    except Exception:
        pass


atexit.register(_cleanup)


def main() -> None:
    # FastMCP defaults to stdio; keeping this as the only transport prevents a
    # local validation helper from accidentally becoming a network service.
    mcp.run(transport="stdio")


if __name__ == "__main__":
    main()
