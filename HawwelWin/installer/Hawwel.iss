; Hawwel installer (Inno Setup 6). بيتبني من GitHub Actions، أو محلياً: ISCC installer\Hawwel.iss
#ifndef MyAppVersion
  #define MyAppVersion "1.0.0"
#endif

[Setup]
AppId={{BEEE79D9-A406-4FAE-BED5-87F4FBA24786}
AppName=Hawwel
AppVersion={#MyAppVersion}
AppPublisher=Ashraf
DefaultDirName={autopf}\Hawwel
DisableProgramGroupPage=yes
; تثبيت للمستخدم الحالي من غير صلاحيات Admin (ويظهر في Settings > Apps)، والمستخدم يقدر يختار "لكل المستخدمين"
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
SetupIconFile=..\Assets\hawwel.ico
UninstallDisplayIcon={app}\Hawwel.exe
OutputDir=..\dist
OutputBaseFilename=Hawwel-Setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
VersionInfoVersion={#MyAppVersion}.0
VersionInfoProductVersion={#MyAppVersion}
VersionInfoProductName=Hawwel
VersionInfoCompany=Ashraf
VersionInfoDescription=Hawwel Setup

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "startup"; Description: "Start Hawwel when Windows starts"
Name: "desktopicon"; Description: "Create a desktop shortcut"; Flags: unchecked

[Files]
Source: "..\out\Hawwel.exe"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\Hawwel"; Filename: "{app}\Hawwel.exe"
Name: "{autodesktop}\Hawwel"; Filename: "{app}\Hawwel.exe"; Tasks: desktopicon

[Registry]
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "Hawwel"; ValueData: """{app}\Hawwel.exe"""; Tasks: startup

[Run]
Filename: "{app}\Hawwel.exe"; Description: "Launch Hawwel"; Flags: nowait postinstall

[Code]
// Hawwel بيفضل شغّال في الـ tray، فنقفله قبل التثبيت/الحذف علشان الملف ما يبقاش مقفول
procedure KillApp();
var R: Integer;
begin
  Exec(ExpandConstant('{sys}\taskkill.exe'), '/F /IM Hawwel.exe', '', SW_HIDE, ewWaitUntilTerminated, R);
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
begin
  KillApp();
  Result := '';
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usUninstall then
  begin
    KillApp();
    // يشيل التشغيل مع الجهاز حتى لو اتفعّل من داخل التطبيق نفسه
    RegDeleteValue(HKEY_CURRENT_USER, 'Software\Microsoft\Windows\CurrentVersion\Run', 'Hawwel');
  end;
end;
