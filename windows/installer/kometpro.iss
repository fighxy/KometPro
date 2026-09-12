#ifndef AppVersion
  #error AppVersion is required
#endif
#ifndef BundleDir
  #error BundleDir is required
#endif
#ifndef OutputPath
  #error OutputPath is required
#endif
#ifndef WebViewBootstrapper
  #error WebViewBootstrapper is required
#endif

[Setup]
AppId={{C52D8ED0-070F-4D92-BDB5-A60B226AAC97}
AppName=KometPro
AppVersion={#AppVersion}
AppPublisher=KometPro contributors
AppPublisherURL=https://github.com/fighxy/KometPro
AppSupportURL=https://github.com/fighxy/KometPro/issues
AppUpdatesURL=https://github.com/fighxy/KometPro/releases
DefaultDirName={localappdata}\Programs\KometPro
DefaultGroupName=KometPro
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0.17763
DisableProgramGroupPage=yes
UsePreviousAppDir=yes
UninstallDisplayIcon={app}\Komet.exe
AppMutex=Local\ru.komet.app.single
SetupMutex=KometProSetup
CloseApplications=yes
RestartApplications=no
OutputDir={#OutputPath}
OutputBaseFilename=KometPro-{#AppVersion}-windows-x64-setup
SetupIconFile=..\runner\resources\app_icon.ico
LicenseFile=..\..\LICENSE
Compression=lzma2
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#BundleDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs; Excludes: "*.pdb"
Source: "{#WebViewBootstrapper}"; DestDir: "{tmp}"; DestName: "MicrosoftEdgeWebview2Setup.exe"; Flags: deleteafterinstall

[Icons]
Name: "{userprograms}\KometPro"; Filename: "{app}\Komet.exe"; WorkingDir: "{app}"; AppUserModelID: "ru.komet.app"
Name: "{userdesktop}\KometPro"; Filename: "{app}\Komet.exe"; WorkingDir: "{app}"; AppUserModelID: "ru.komet.app"; Tasks: desktopicon

[Run]
Filename: "{app}\Komet.exe"; Description: "{cm:LaunchProgram,KometPro}"; Flags: nowait postinstall skipifsilent

[Code]
const
  WebViewKey = 'Software\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}';

function HasWebView2: Boolean;
var
  Version: String;
begin
  Result := (RegQueryStringValue(HKCU, WebViewKey, 'pv', Version) and
    (Version <> '') and (Version <> '0.0.0.0')) or
    (RegQueryStringValue(HKLM32, WebViewKey, 'pv', Version) and
    (Version <> '') and (Version <> '0.0.0.0'));
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  ResultCode: Integer;
begin
  Result := '';
  if HasWebView2 then Exit;
  ExtractTemporaryFile('MicrosoftEdgeWebview2Setup.exe');
  if not Exec(ExpandConstant('{tmp}\MicrosoftEdgeWebview2Setup.exe'),
    '/silent /install', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) or
    not HasWebView2 then
  begin
    if ActiveLanguage = 'russian' then
      Result := 'Не удалось установить Microsoft Edge WebView2. Подключитесь к интернету или установите WebView2 Runtime и повторите установку.'
    else
      Result := 'Microsoft Edge WebView2 installation failed. Connect to the internet or install WebView2 Runtime, then retry setup.';
  end;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  Command: String;
begin
  if CurUninstallStep = usUninstall then
    if RegQueryStringValue(HKCU, 'Software\Microsoft\Windows\CurrentVersion\Run',
      'Komet', Command) then
      if CompareText(Command, '"' + ExpandConstant('{app}\Komet.exe') + '"') = 0 then
        RegDeleteValue(HKCU, 'Software\Microsoft\Windows\CurrentVersion\Run', 'Komet');
end;
