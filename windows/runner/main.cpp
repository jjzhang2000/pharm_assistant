#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);

  // 16:9 portrait, centered on screen
  const unsigned int w = 450;
  const unsigned int h = 800;

  // GetSystemMetrics returns physical pixels in DPI-aware app.
  // Win32Window::Create applies Scale() by dpi/96, so convert to logical pixels.
  HDC hdc = GetDC(nullptr);
  double dpiScale = GetDeviceCaps(hdc, LOGPIXELSX) / 96.0;
  ReleaseDC(nullptr, hdc);
  int logicalScreenW = static_cast<int>(GetSystemMetrics(SM_CXSCREEN) / dpiScale);
  int logicalScreenH = static_cast<int>(GetSystemMetrics(SM_CYSCREEN) / dpiScale);

  Win32Window::Point origin((logicalScreenW - w) / 2, (logicalScreenH - h) / 2);
  Win32Window::Size size(w, h);
  if (!window.Create(L"pharm_assistant", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
