#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <shlobj.h>
#include <stdlib.h>
#include <wchar.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

namespace {
constexpr const wchar_t kMutexName[] = L"Local\\ru.komet.app.single";
constexpr const wchar_t kWindowClassName[] = L"FLUTTER_RUNNER_WIN32_WINDOW";
constexpr const wchar_t kWindowTitle[] = L"Komet";

HWND g_existing = nullptr;

BOOL CALLBACK RestoreExistingWindow(HWND hwnd, LPARAM) {
  wchar_t cls[64] = {};
  if (GetClassNameW(hwnd, cls, 64) == 0) {
    return TRUE;
  }
  if (wcscmp(cls, kWindowClassName) != 0) {
    return TRUE;
  }
  wchar_t title[64] = {};
  GetWindowTextW(hwnd, title, 64);
  if (wcscmp(title, kWindowTitle) != 0) {
    return TRUE;
  }
  g_existing = hwnd;
  if (IsIconic(hwnd) || !IsWindowVisible(hwnd)) {
    ShowWindow(hwnd, SW_RESTORE);
  }
  ShowWindow(hwnd, SW_SHOW);
  SetWindowPos(hwnd, HWND_TOP, 0, 0, 0, 0,
               SWP_NOMOVE | SWP_NOSIZE | SWP_SHOWWINDOW);
  SetForegroundWindow(hwnd);
  return FALSE;
}

int ParseChatArg(const wchar_t* command_line) {
  if (!command_line) return 0;
  const wchar_t* found = wcsstr(command_line, L"--chat=");
  if (!found) return 0;
  return _wtoi(found + 7);
}

bool FocusExistingInstance(int chat_id) {
  g_existing = nullptr;
  EnumWindows(RestoreExistingWindow, 0);
  if (g_existing && chat_id != 0) {
    COPYDATASTRUCT data = {};
    data.dwData = 1;
    data.cbData = sizeof(chat_id);
    data.lpData = &chat_id;
    DWORD_PTR ignored = 0;
    SendMessageTimeoutW(g_existing, WM_COPYDATA, 0,
                        reinterpret_cast<LPARAM>(&data),
                        SMTO_ABORTIFHUNG | SMTO_BLOCK, 2000, &ignored);
  }
  return true;
}
}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  const int launch_chat = ParseChatArg(command_line);
  HANDLE mutex = CreateMutexW(nullptr, TRUE, kMutexName);
  if (mutex == nullptr) {
    return EXIT_FAILURE;
  }
  if (GetLastError() == ERROR_ALREADY_EXISTS) {
    FocusExistingInstance(launch_chat);
    CloseHandle(mutex);
    return EXIT_SUCCESS;
  }
  if (launch_chat != 0) {
    SetPendingLaunchChat(launch_chat);
  }

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
  SetCurrentProcessExplicitAppUserModelID(L"ru.komet.app");

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(kWindowTitle, origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(false);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
