#include "flutter_window.h"

#include <dwmapi.h>
#include <flutter/encodable_value.h>
#include <optional>
#include <propkey.h>
#include <propvarutil.h>
#include <shlobj.h>

#include "flutter/generated_plugin_registrant.h"

namespace {
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
          if (hwnd && enabled) {
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

void FlutterWindow::OnDestroy() {
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
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
