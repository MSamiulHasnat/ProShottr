# Windows installer

Build the release bundle and installer from the repository root:

```powershell
$env:PUB_CACHE = 'C:\tmp\proshottr-pub-cache'
$env:FLUTTER_ROOT = 'C:\tmp\flutter-sdk'
$env:Path = 'C:\tmp\flutter-sdk\bin;C:\Users\Samiul\.cargo\bin;' + $env:Path
flutter build windows --release --project-directory ui

& 'C:\Program Files (x86)\Inno Setup 6\ISCC.exe' installer\ProShottr.iss
```

The installer is written to `dist\ProShottr-Setup-0.1.0.exe`. It installs per-user under `%LOCALAPPDATA%\Programs\ProShottr`, creates a Start Menu shortcut, and offers an optional desktop shortcut. Uninstall is available from Windows Installed apps.
