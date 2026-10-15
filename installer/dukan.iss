#ifndef MyAppVersion
  #define MyAppVersion GetEnv("DUKAN_VERSION")
#endif
#if MyAppVersion == ""
  #define MyAppVersion "0.1.0"
#endif
[Setup]
AppId={{C58B2756-3B3C-4DC9-9913-C58C952D6304}
AppName=دبت للحسابات
AppVersion={#MyAppVersion}
AppPublisher=دبت للحسابات
DefaultDirName={localappdata}\Programs\Dukan
DefaultGroupName=دبت للحسابات
UninstallDisplayIcon={app}\dukan_app.exe
OutputDir=..\build\distribution
OutputBaseFilename=دبت للحسابات-{#MyAppVersion}-windows-setup
Compression=lzma2
SolidCompression=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
CloseApplications=yes
RestartApplications=no
WizardStyle=modern
[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
[Icons]
Name: "{group}\دبت للحسابات"; Filename: "{app}\dukan_app.exe"
Name: "{autodesktop}\دبت للحسابات"; Filename: "{app}\dukan_app.exe"; Tasks: desktopicon
[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; Flags: unchecked
[Run]
Filename: "{app}\dukan_app.exe"; Description: "فتح دبت للحسابات"; Flags: nowait postinstall skipifsilent
; Application support data and backups are intentionally outside {app}.
; Do not add an UninstallDelete rule for shop data.
