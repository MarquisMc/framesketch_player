#define AppName "FrameSketch Player"
#define AppVersion GetEnv("FRAMESKETCH_VERSION")
#if AppVersion == ""
  #define AppVersion "1.0.2"
#endif
#define AppPublisher "Marquis McCann"
#define AppExeName "framesketch_player.exe"
#define AppUserModelID "FrameSketchPlayer"
#define AppSourceDir "..\..\build\windows\x64\runner\Release"
#define AppOutputDir "..\..\release"
#define SignCertSha1 GetEnv("FRAMESKETCH_SIGN_CERT_SHA1")
#define SignTimestampUrl GetEnv("FRAMESKETCH_SIGN_TIMESTAMP_URL")
#if SignTimestampUrl == ""
  #define SignTimestampUrl "http://timestamp.digicert.com"
#endif

[Setup]
AppId={{75C0BC84-BC6F-4D42-8B65-CC8445277F4D}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
DefaultDirName={localappdata}\Programs\FrameSketch Player
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
LicenseFile=..\..\LICENSE
OutputDir={#AppOutputDir}
OutputBaseFilename=FrameSketch-Setup-v{#AppVersion}-windows-x64
SetupIconFile=..\..\windows\runner\resources\app_icon.ico
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=lowest
UninstallDisplayIcon={app}\{#AppExeName}
CloseApplications=yes
RestartApplications=no
#if SignCertSha1 != ""
SignedUninstaller=yes
SignTool=signtool sign /d $q{#AppName}$q /fd sha256 /td sha256 /tr $q{#SignTimestampUrl}$q /sha1 $q{#SignCertSha1}$q $f
#endif

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#AppSourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"; IconFilename: "{app}\{#AppExeName}"; AppUserModelID: "{#AppUserModelID}"
Name: "{group}\Uninstall {#AppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; IconFilename: "{app}\{#AppExeName}"; AppUserModelID: "{#AppUserModelID}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(AppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
Filename: "{app}\{#AppExeName}"; Flags: nowait; Check: ShouldRelaunchSilentUpdate

[Code]
function HasCommandLineParameter(Value: String): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 1 to ParamCount do
  begin
    if CompareText(ParamStr(I), Value) = 0 then
    begin
      Result := True;
      Exit;
    end;
  end;
end;

function ShouldRelaunchSilentUpdate(): Boolean;
begin
  Result := WizardSilent and
    (not HasCommandLineParameter('/FRAMESELFUPDATELAUNCHER'));
end;
