#ifndef MyAppVersion
  #define MyAppVersion GetEnv("DEPT_ACCOUNTING_VERSION")
#endif
#if MyAppVersion == ""
  #define MyAppVersion "0.1.0"
#endif
; Refuse to publish an installer that depends on a preinstalled Visual C++ runtime.
#if !FileExists(AddBackslash(SourcePath) + "..\build\windows\x64\runner\Release\msvcp140.dll")
  #error Missing msvcp140.dll. Rebuild Windows with the bundled Visual C++ runtimes.
#endif
#if !FileExists(AddBackslash(SourcePath) + "..\build\windows\x64\runner\Release\vcruntime140.dll")
  #error Missing vcruntime140.dll. Rebuild Windows with the bundled Visual C++ runtimes.
#endif
#if !FileExists(AddBackslash(SourcePath) + "..\build\windows\x64\runner\Release\vcruntime140_1.dll")
  #error Missing vcruntime140_1.dll. Rebuild Windows with the bundled Visual C++ runtimes.
#endif
[Setup]
AppId={{C58B2756-3B3C-4DC9-9913-C58C952D6304}
AppName=دبت للحسابات
AppVersion={#MyAppVersion}
AppPublisher=دبت للحسابات
DefaultDirName={localappdata}\Programs\DeptAccounting
DefaultGroupName=دبت للحسابات
UninstallDisplayIcon={app}\dept_accounting.exe
OutputDir=..\build\distribution
OutputBaseFilename=دبت للحسابات-{#MyAppVersion}-windows-setup
Compression=lzma2
SolidCompression=yes
DiskSpanning=no
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
CloseApplications=yes
RestartApplications=no
WizardStyle=modern
[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
[Icons]
Name: "{group}\دبت للحسابات"; Filename: "{app}\dept_accounting.exe"
Name: "{autodesktop}\دبت للحسابات"; Filename: "{app}\dept_accounting.exe"; Tasks: desktopicon
[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; Flags: unchecked
[Run]
Filename: "{app}\dept_accounting.exe"; Description: "فتح دبت للحسابات"; Flags: nowait postinstall skipifsilent
; Application support data and backups are intentionally outside {app}.
; Do not add an UninstallDelete rule for shop data.
