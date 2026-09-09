#include "flutter_window.h"

#include <dwmapi.h>
#include <flutter/encodable_value.h>
#include <optional>
#include <propkey.h>
#include <propvarutil.h>
#include <shellapi.h>
#include <shlobj.h>
#include <chrono>
#include <fstream>
#include <mutex>
#include <sstream>
#include <iomanip>
#include <ctime>

#include "flutter/generated_plugin_registrant.h"
#include "resource.h"

#ifndef NIN_SELECT
#define NIN_SELECT (WM_USER + 0)
#endif

// Message definitions (must be before any function usage)
static constexpr UINT WM_KICK_COMPOSITOR_ASYNC = WM_USER + 0x4B00;

// Performance Logging
static std::mutex g_perf_mutex;
static char g_perf_log_path[MAX_PATH];
static bool g_perf_path_initialized = false;

void InitPerfLogPath() {
    if (g_perf_path_initialized) return;
    
    // Get %LOCALAPPDATA%
    char app_data[MAX_PATH];
    size_t len = 0;
    if (_dupenv_s(&app_data, &len, "LOCALAPPDATA") != 0 || !app_data) {
        strcpy_s(app_data, MAX_PATH, ".");
    }
    
    snprintf(g_perf_log_path, MAX_PATH, "%s\\Komet\\logs\\perf_log.txt", app_data);
    
    // Free allocated memory from _dupenv_s
    if (len > 0 && app_data) {
        free(app_data);
    }
    
    // Ensure directory exists
    char dir_path[MAX_PATH];
    strncpy_s(dir_path, g_perf_log_path, _TRUNCATE);
    char* last_slash = strrchr(dir_path, '\\');
    if (last_slash) {
        *last_slash = '\0';
        SHCreateDirectoryExA(nullptr, dir_path, nullptr);
    }
    
    g_perf_path_initialized = true;
}

void LogPerfEvent(const std::string& event, long long duration_us = 0) {
    if (!g_perf_path_initialized) {
        InitPerfLogPath();
    }
    
    std::lock_guard<std::mutex> lock(g_perf_mutex);
    std::ofstream log(g_perf_log_path, std::ios::app);
    if (log.is_open()) {
        auto now = std::chrono::system_clock::now();
        auto time_t_now = std::chrono::system_clock::to_time_t(now);
        auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(
            now.time_since_epoch()) % 1000;
        
        struct tm timeinfo;
        localtime_s(&timeinfo, &time_t_now);
        log << "[" << std::put_time(&timeinfo, "%H:%M:%S") 
            << "." << std::setfill('0') << std::setw(3) << ms.count() << "] "
            << event;
        if (duration_us > 0) {
            log << " (Duration: " << (duration_us / 1000.0) << "ms)";
        }
        log << "\n";
        log.flush();
    }
}

#define LOG_PERF(msg) LogPerfEvent(msg)
#define LOG_PERF_DUR(msg, dur) LogPerfEvent(msg, dur)

namespace {
constexpr UINT WM_TRAYICON = WM_APP + 32;
constexpr UINT kKickTimerEarly = 0x4B01;
constexpr UINT kKickTimerLate = 0x4B02;
constexpr UINT_PTR ID_TRAY = 1;
constexpr UINT IDM_TRAY_SHOW = 1;
constexpr UINT IDM_TRAY_HIDE = 2;
constexpr UINT IDM_TRAY_QUIT = 3;

int g_launch_chat_id = 0;

void SetLaunchChatId(int id) { g_launch_chat_id = id; }

int TakeLaunchChatId() {
  const int id = g_launch_chat_id;
  g_launch_chat_id = 0;
  return id;
}

void SetJumpList(const flutter::EncodableList& chats) {
  ICustomDestinationList* list = nullptr;
  if (FAILED(CoCreateInstance(CLSID_DestinationList, nullptr, CLSCTX_INPROC_SERVER,
                              IID_PPV_ARGS(&list)))) {
    return;
  }
  list->SetAppID(L"ru.komet.app");
  UINT max_slots = 0;
  IObjectArray* removed = nullptr;
  if (FAILED(list->BeginList(&max_slots, IID_PPV_ARGS(&removed)))) {
    list->Release();
    return;
  }
  if (removed) {
    removed->Release();
  }

  IObjectCollection* collection = nullptr;
  if (FAILED(CoCreateInstance(CLSID_EnumerableObjectCollection, nullptr,
                              CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&collection)))) {
    list->AbortList();
    list->Release();
    return;
  }

  wchar_t exe[MAX_PATH] = {};
  GetModuleFileNameW(nullptr, exe, MAX_PATH);

  for (const auto& item : chats) {
    const auto* map = std::get_if<flutter::EncodableMap>(&item);
    if (!map) continue;
    int id = 0;
    std::string title;
    for (const auto& [key, value] : *map) {
      const auto* key_str = std::get_if<std::string>(&key);
      if (!key_str) continue;
      if (*key_str == "id") {
        if (const auto* n = std::get_if<int>(&value)) id = *n;
        if (const auto* n = std::get_if<int32_t>(&value)) id = *n;
      } else if (*key_str == "title") {
        if (const auto* s = std::get_if<std::string>(&value)) title = *s;
      }
    }
    if (id == 0) continue;

    IShellLinkW* link = nullptr;
    if (FAILED(CoCreateInstance(CLSID_ShellLink, nullptr, CLSCTX_INPROC_SERVER,
                                IID_PPV_ARGS(&link)))) {
      continue;
    }
    link->SetPath(exe);
    wchar_t args[64] = {};
    swprintf_s(args, L"--chat=%d", id);
    link->SetArguments(args);

    std::wstring wide(title.begin(), title.end());
    if (wide.empty()) wide = L"Chat";
    IPropertyStore* props = nullptr;
    if (SUCCEEDED(link->QueryInterface(IID_PPV_ARGS(&props)))) {
      PROPVARIANT pv;
      if (SUCCEEDED(InitPropVariantFromString(wide.c_str(), &pv))) {
        props->SetValue(PKEY_Title, pv);
        PropVariantClear(&pv);
      }
      props->Commit();
      props->Release();
    }
    collection->AddObject(link);
    link->Release();
  }

  IObjectArray* array = nullptr;
  if (SUCCEEDED(collection->QueryInterface(IID_PPV_ARGS(&array)))) {
    list->AppendCategory(L"Recent", array);
    array->Release();
  }
  collection->Release();
  list->CommitList();
  list->Release();
}
}  // namespace

void SetPendingLaunchChat(int id) { SetLaunchChatId(id); }

bool GetAutoStart() {
  HKEY key = nullptr;
  if (RegOpenKeyExW(HKEY_CURRENT_USER,
                    L"Software\\Microsoft\\Windows\\CurrentVersion\\Run", 0,
                    KEY_READ, &key) != ERROR_SUCCESS) {
    return false;
  }
  wchar_t value[MAX_PATH] = {};
  DWORD size = sizeof(value);
  const auto status =
      RegQueryValueExW(key, L"Komet", nullptr, nullptr,
                       reinterpret_cast<LPBYTE>(value), &size);
  RegCloseKey(key);
  return status == ERROR_SUCCESS && value[0] != 0;
}

void SetAutoStart(bool enabled) {
  HKEY key = nullptr;
  if (RegOpenKeyExW(HKEY_CURRENT_USER,
                    L"Software\\Microsoft\\Windows\\CurrentVersion\\Run", 0,
                    KEY_SET_VALUE, &key) != ERROR_SUCCESS) {
    return;
  }
  if (!enabled) {
    RegDeleteValueW(key, L"Komet");
    RegCloseKey(key);
    return;
  }
  wchar_t exe[MAX_PATH] = {};
  GetModuleFileNameW(nullptr, exe, MAX_PATH);
  wchar_t command[MAX_PATH + 4] = {};
  swprintf_s(command, L"\"%s\"", exe);
  RegSetValueExW(key, L"Komet", 0, REG_SZ,
                 reinterpret_cast<const BYTE*>(command),
                 static_cast<DWORD>((wcslen(command) + 1) * sizeof(wchar_t)));
  RegCloseKey(key);
}

bool IsWindows11() {
  using RtlGetVersionFn = LONG(WINAPI*)(OSVERSIONINFOW*);
  HMODULE ntdll = GetModuleHandleW(L"ntdll.dll");
  if (!ntdll) {
    return false;
  }
  auto rtl = reinterpret_cast<RtlGetVersionFn>(
      GetProcAddress(ntdll, "RtlGetVersion"));
  if (!rtl) {
    return false;
  }
  OSVERSIONINFOW info = {};
  info.dwOSVersionInfoSize = sizeof(info);
  if (rtl(&info) != 0) {
    return false;
  }
  return info.dwBuildNumber >= 22000;
}

std::wstring Utf16FromUtf8(const std::string& utf8) {
  if (utf8.empty()) {
    return std::wstring();
  }
  const int needed = MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), -1, nullptr, 0);
  if (needed <= 1) {
    return std::wstring();
  }
  std::wstring wide(static_cast<size_t>(needed - 1), L'\0');
  MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), -1, wide.data(), needed);
  return wide;
}

const std::string* StringArg(const flutter::EncodableMap& map, const char* key) {
  const auto it = map.find(flutter::EncodableValue(key));
  if (it == map.end()) {
    return nullptr;
  }
  return std::get_if<std::string>(&it->second);
}

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  RegisterDesktopChannel();
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
    this->KickCompositor();
    HWND hwnd = GetHandle();
    if (hwnd) {
      SetTimer(hwnd, kKickTimerEarly, 32, nullptr);
      SetTimer(hwnd, kKickTimerLate, 250, nullptr);
    }
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::RegisterDesktopChannel() {
  desktop_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "ru.komet/desktop_window",
          &flutter::StandardMethodCodec::GetInstance());
  desktop_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        if (call.method_name() == "flashTaskbar") {
          FlashTaskbar(true);
          result->Success();
          return;
        }
        if (call.method_name() == "stopFlash") {
          FlashTaskbar(false);
          result->Success();
          return;
        }
        if (call.method_name() == "setJumpList") {
          const auto* args =
              std::get_if<flutter::EncodableMap>(call.arguments());
          if (args) {
            const auto it = args->find(flutter::EncodableValue("chats"));
            if (it != args->end()) {
              if (const auto* list =
                      std::get_if<flutter::EncodableList>(&it->second)) {
                SetJumpList(*list);
              }
            }
          }
          result->Success();
          return;
        }
        if (call.method_name() == "takeLaunchChat") {
          result->Success(flutter::EncodableValue(TakeLaunchChatId()));
          return;
        }
        if (call.method_name() == "setMica") {
          const auto* enabled = std::get_if<bool>(call.arguments());
          HWND hwnd = GetHandle();
          if (hwnd && enabled && IsWindows11()) {
#ifndef DWMWA_SYSTEMBACKDROP_TYPE
#define DWMWA_SYSTEMBACKDROP_TYPE 38
#endif
            const int type = *enabled ? 2 : 1;
            DwmSetWindowAttribute(hwnd, DWMWA_SYSTEMBACKDROP_TYPE, &type,
                                  sizeof(type));
          }
          result->Success();
          return;
        }
        if (call.method_name() == "kickCompositor") {
          KickCompositor();
          result->Success();
          return;
        }
        if (call.method_name() == "forceForeground") {
          ForceForeground();
          result->Success();
          return;
        }
        if (call.method_name() == "nativeTray") {
          const auto* args =
              std::get_if<flutter::EncodableMap>(call.arguments());
          if (args) {
            if (const auto* tip = StringArg(*args, "tip")) {
              tray_tip_ = Utf16FromUtf8(*tip);
            }
            if (const auto* show = StringArg(*args, "show")) {
              tray_show_ = Utf16FromUtf8(*show);
            }
            if (const auto* hide = StringArg(*args, "hide")) {
              tray_hide_ = Utf16FromUtf8(*hide);
            }
            if (const auto* quit = StringArg(*args, "quit")) {
              tray_quit_ = Utf16FromUtf8(*quit);
            }
          }
          AddNativeTray();
          result->Success();
          return;
        }
        if (call.method_name() == "setTrayTip") {
          const auto* tip = std::get_if<std::string>(call.arguments());
          if (tip) {
            UpdateTrayTip(Utf16FromUtf8(*tip));
          }
          result->Success();
          return;
        }
        if (call.method_name() == "removeNativeTray") {
          RemoveNativeTray();
          result->Success();
          return;
        }
        if (call.method_name() == "setAutoStart") {
          const auto* enabled = std::get_if<bool>(call.arguments());
          if (enabled) {
            SetAutoStart(*enabled);
          }
          result->Success();
          return;
        }
        if (call.method_name() == "getAutoStart") {
          result->Success(flutter::EncodableValue(GetAutoStart()));
          return;
        }
        result->NotImplemented();
      });
}

void FlutterWindow::FlashTaskbar(bool enable) {
  HWND hwnd = GetHandle();
  if (!hwnd) {
    return;
  }
  FLASHWINFO info = {};
  info.cbSize = sizeof(info);
  info.hwnd = hwnd;
  if (enable) {
    info.dwFlags = FLASHW_TRAY | FLASHW_TIMERNOFG;
    info.uCount = 4;
  } else {
    info.dwFlags = FLASHW_STOP;
  }
  FlashWindowEx(&info);
}

void FlutterWindow::KickCompositor() {
  HWND hwnd = GetHandle();
  if (!hwnd) {
    return;
  }
  
  // Post the compositor kick asynchronously to avoid blocking message loop
  // This prevents UI freeze when called during focus operations
  LOG_PERF("KickCompositor: Posted async");
  PostMessage(hwnd, WM_KICK_COMPOSITOR_ASYNC, 0, 0);
}

static void DoKickCompositor(HWND hwnd, flutter::FlutterViewController* controller) {
  auto start_time = std::chrono::high_resolution_clock::now();
  LOG_PERF("DoKickCompositor: Start");
  
  if (!hwnd) return;
  RECT wr = {};
  GetWindowRect(hwnd, &wr);
  const int w = wr.right - wr.left;
  const int h = wr.bottom - wr.top;
  if (w > 80 && h > 80) {
    SetWindowPos(hwnd, nullptr, wr.left, wr.top, w, h + 1,
                 SWP_NOZORDER | SWP_NOACTIVATE);
    SetWindowPos(hwnd, nullptr, wr.left, wr.top, w, h,
                 SWP_NOZORDER | SWP_NOACTIVATE);
  }
  RECT cr = {};
  GetClientRect(hwnd, &cr);
  HWND child = GetWindow(hwnd, GW_CHILD);
  if (child) {
    MoveWindow(child, cr.left, cr.top, cr.right - cr.left,
               cr.bottom - cr.top, TRUE);
  }
  // Avoid RDW_ALLCHILDREN which can block on complex hierarchies
  RedrawWindow(hwnd, nullptr, nullptr,
               RDW_INVALIDATE | RDW_ERASE | RDW_FRAME | RDW_UPDATENOW);
  if (controller) {
    controller->ForceRedraw();
  }
  
  auto end_time = std::chrono::high_resolution_clock::now();
  auto duration = std::chrono::duration_cast<std::chrono::microseconds>(end_time - start_time).count();
  LOG_PERF_DUR("DoKickCompositor: Complete", duration);
}

void FlutterWindow::ForceForeground() {
  HWND hwnd = GetHandle();
  if (!hwnd) {
    return;
  }
  
  auto start_time = std::chrono::high_resolution_clock::now();
  LOG_PERF("ForceForeground: Start");
  
  // Check if we're already foreground - avoid unnecessary work
  if (GetForegroundWindow() == hwnd) {
    LOG_PERF("ForceForeground: Already foreground, skip");
    return;
  }
  
  HWND fg = GetForegroundWindow();
  DWORD fg_tid = 0;
  DWORD our_tid = GetCurrentThreadId();
  
  // Try to allow setting foreground window
  if (fg && fg != hwnd) {
    DWORD fg_pid = 0;
    GetWindowThreadProcessId(fg, &fg_tid);
    GetWindowThreadProcessId(hwnd, &fg_pid);
    
    // Windows 10/11: request permission to set foreground
    if (fg_tid != 0 && fg_tid != our_tid) {
      // Attach to foreground thread input for focus handoff
      BOOL attach_result = AttachThreadInput(fg_tid, our_tid, TRUE);
      LOG_PERF(attach_result ? "ForceForeground: Attached to foreground thread" 
                             : "ForceForeground: AttachThreadInput failed");
    }
  }
  
  // Restore if minimized
  if (IsIconic(hwnd)) {
    ShowWindow(hwnd, SW_RESTORE);
    // Small delay to let restore complete
    Sleep(10);
    LOG_PERF("ForceForeground: Restored from minimized");
  } else if (!IsWindowVisible(hwnd)) {
    ShowWindow(hwnd, SW_SHOW);
    Sleep(10);
    LOG_PERF("ForceForeground: Shown from hidden");
  }
  
  // Bring to top and set foreground
  SetWindowPos(hwnd, HWND_TOP, 0, 0, 0, 0,
               SWP_NOMOVE | SWP_NOSIZE | SWP_SHOWWINDOW);
  
  // Critical: ensure we have permission before calling SetForegroundWindow
  BOOL result = SetForegroundWindow(hwnd);
  if (!result) {
    // Fallback: try using Alt+Tab simulation via key event
    keybd_event(VK_MENU, 0, KEYEVENTF_EXTENDEDKEY, 0);
    keybd_event(VK_MENU, 0, KEYEVENTF_EXTENDEDKEY | KEYEVENTF_KEYUP, 0);
    LOG_PERF("ForceForeground: SetForegroundWindow failed, used keybd_event fallback");
  } else {
    LOG_PERF("ForceForeground: SetForegroundWindow succeeded");
  }
  
  BringWindowToTop(hwnd);
  
  // Detach from foreground thread
  if (fg && fg_tid != 0 && fg_tid != our_tid) {
    AttachThreadInput(fg_tid, our_tid, FALSE);
  }
  
  auto end_time = std::chrono::high_resolution_clock::now();
  auto duration = std::chrono::duration_cast<std::chrono::microseconds>(end_time - start_time).count();
  LOG_PERF_DUR("ForceForeground: Complete", duration);
}

void FlutterWindow::AddNativeTray() {
  HWND hwnd = GetHandle();
  if (!hwnd) {
    return;
  }
  NOTIFYICONDATAW nid = {};
  nid.cbSize = sizeof(nid);
  nid.hWnd = hwnd;
  nid.uID = ID_TRAY;
  nid.uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP;
  nid.uCallbackMessage = WM_TRAYICON;
  nid.hIcon = LoadIcon(GetModuleHandle(nullptr), MAKEINTRESOURCE(IDI_APP_ICON));
  wcsncpy_s(nid.szTip, tray_tip_.c_str(), _TRUNCATE);
  if (tray_added_) {
    Shell_NotifyIconW(NIM_MODIFY, &nid);
    return;
  }
  if (Shell_NotifyIconW(NIM_ADD, &nid)) {
    tray_added_ = true;
  }
}

void FlutterWindow::RemoveNativeTray() {
  if (!tray_added_) {
    return;
  }
  HWND hwnd = GetHandle();
  NOTIFYICONDATAW nid = {};
  nid.cbSize = sizeof(nid);
  nid.hWnd = hwnd;
  nid.uID = ID_TRAY;
  Shell_NotifyIconW(NIM_DELETE, &nid);
  tray_added_ = false;
}

void FlutterWindow::UpdateTrayTip(const std::wstring& tip) {
  tray_tip_ = tip.empty() ? L"Komet" : tip;
  if (!tray_added_) {
    return;
  }
  HWND hwnd = GetHandle();
  if (!hwnd) {
    return;
  }
  NOTIFYICONDATAW nid = {};
  nid.cbSize = sizeof(nid);
  nid.hWnd = hwnd;
  nid.uID = ID_TRAY;
  nid.uFlags = NIF_TIP | NIF_ICON | NIF_MESSAGE;
  nid.uCallbackMessage = WM_TRAYICON;
  nid.hIcon = LoadIcon(GetModuleHandle(nullptr), MAKEINTRESOURCE(IDI_APP_ICON));
  wcsncpy_s(nid.szTip, tray_tip_.c_str(), _TRUNCATE);
  Shell_NotifyIconW(NIM_MODIFY, &nid);
}

void FlutterWindow::ShowNativeTrayMenu() {
  HWND hwnd = GetHandle();
  if (!hwnd) {
    return;
  }
  POINT pt = {};
  GetCursorPos(&pt);
  
  // Critical: set foreground before TrackPopupMenu to avoid focus issues on Win10
  // Use AttachThreadInput for better compatibility with Windows 10
  HWND fg_window = GetForegroundWindow();
  if (fg_window != hwnd) {
    DWORD fg_thread = GetWindowThreadProcessId(fg_window, nullptr);
    DWORD this_thread = GetCurrentThreadId();
    if (fg_thread != this_thread) {
      AttachThreadInput(this_thread, fg_thread, TRUE);
      SetForegroundWindow(hwnd);
      AttachThreadInput(this_thread, fg_thread, FALSE);
    } else {
      SetForegroundWindow(hwnd);
    }
  } else {
    SetForegroundWindow(hwnd);
  }
  
  HMENU menu = CreatePopupMenu();
  if (!menu) {
    return;
  }
  AppendMenuW(menu, MF_STRING, IDM_TRAY_SHOW, tray_show_.c_str());
  AppendMenuW(menu, MF_STRING, IDM_TRAY_HIDE, tray_hide_.c_str());
  AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
  AppendMenuW(menu, MF_STRING, IDM_TRAY_QUIT, tray_quit_.c_str());
  
  LOG_PERF("ShowNativeTrayMenu: Showing popup menu");
  
  // Use TPM_RIGHTBUTTON and ensure menu doesn't block message loop
  const int cmd = TrackPopupMenu(menu,
                                 TPM_RETURNCMD | TPM_RIGHTBUTTON | TPM_BOTTOMALIGN,
                                 pt.x, pt.y, 0, hwnd, nullptr);
  
  LOG_PERF("ShowNativeTrayMenu: Menu closed");
  
  // Post WM_NULL to keep menu open until user selects
  PostMessage(hwnd, WM_NULL, 0, 0);
  DestroyMenu(menu);
  
  // Handle action asynchronously to avoid blocking
  if (cmd == IDM_TRAY_SHOW) {
    HandleTrayAction("show");
  } else if (cmd == IDM_TRAY_HIDE) {
    HandleTrayAction("hide");
  } else if (cmd == IDM_TRAY_QUIT) {
    HandleTrayAction("quit");
  }
}

void FlutterWindow::HandleTrayAction(const std::string& action) {
  if (!desktop_channel_) {
    return;
  }
  desktop_channel_->InvokeMethod(
      "trayAction", std::make_unique<flutter::EncodableValue>(action));
}

void FlutterWindow::OnDestroy() {
  RemoveNativeTray();
  desktop_channel_ = nullptr;
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  auto msg_start = std::chrono::high_resolution_clock::now();
  
  if (message == WM_TIMER &&
      (wparam == kKickTimerEarly || wparam == kKickTimerLate)) {
    KillTimer(hwnd, wparam);
    KickCompositor();
    return 0;
  }
  
  // Handle async compositor kick message
  if (message == WM_KICK_COMPOSITOR_ASYNC) {
    DoKickCompositor(hwnd, flutter_controller_.get());
    return 0;
  }
  
  if (message == WM_TRAYICON) {
    const UINT mouse = LOWORD(lparam);
    if (mouse == WM_LBUTTONUP || mouse == NIN_SELECT) {
      HandleTrayAction("show");
      return 0;
    }
    if (mouse == WM_RBUTTONUP || mouse == WM_CONTEXTMENU) {
      ShowNativeTrayMenu();
      return 0;
    }
    return 0;
  }

  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_COPYDATA: {
      const auto* data = reinterpret_cast<COPYDATASTRUCT*>(lparam);
      if (data && data->cbData >= sizeof(int)) {
        int chat_id = *reinterpret_cast<int*>(data->lpData);
        if (desktop_channel_ && chat_id != 0) {
          desktop_channel_->InvokeMethod(
              "openChat",
              std::make_unique<flutter::EncodableValue>(chat_id));
        }
      }
      return TRUE;
    }
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
      
    // Handle WM_ENTERIDLE to keep message loop responsive during menu/tracking
    case WM_ENTERIDLE: {
      const UINT source = LOWORD(wparam);
      // MSGF_MENU=2, MSGF_MOVE=3, MSGF_SIZE=4 - use numeric values for compatibility
      if (source == 2 || source == 3 || source == 4) {
        // Allow processing of pending messages during modal loops
        // Don't return 0 - let DefWindowProc process it to avoid blocking
        LOG_PERF("WM_ENTERIDLE: Modal loop detected, pumping messages");
        
        // Pump pending messages to prevent freeze
        MSG msg;
        while (PeekMessage(&msg, nullptr, 0, 0, PM_NOREMOVE)) {
          if (msg.message == WM_QUIT) {
            return -1;
          }
          // Skip input messages during modal tracking to avoid conflicts
          if (msg.message >= WM_MOUSEFIRST && msg.message <= WM_MOUSELAST) {
            PeekMessage(&msg, nullptr, msg.message, msg.message, PM_REMOVE);
          } else if (msg.message >= WM_KEYFIRST && msg.message <= WM_KEYLAST) {
            PeekMessage(&msg, nullptr, msg.message, msg.message, PM_REMOVE);
          } else {
            break;
          }
        }
      }
      // Always let DefWindowProc handle WM_ENTERIDLE
      break;
    }
    
    // Handle SC_KEYMENU to prevent Alt key from causing focus issues
    case WM_SYSCOMMAND: {
      if ((wparam & 0xFFF0) == SC_KEYMENU) {
        // Let Flutter handle keyboard navigation
        break;
      }
      return DefWindowProc(hwnd, message, wparam, lparam);
    }
    
    // Log focus changes for debugging
    case WM_SETFOCUS: {
      LOG_PERF("WM_SETFOCUS: Window gained focus");
      break;
    }
    case WM_KILLFOCUS: {
      LOG_PERF("WM_KILLFOCUS: Window lost focus");
      break;
    }
    case WM_ACTIVATE: {
      if (LOWORD(wparam) == WA_INACTIVE) {
        LOG_PERF("WM_ACTIVATE: Window deactivated");
      } else {
        LOG_PERF("WM_ACTIVATE: Window activated");
      }
      break;
    }
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
