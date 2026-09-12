# Windows capture acceptance checks

Status: **build verified, checks pending**. The runner, the Rust core, and the
installer compile with Visual Studio 2022 Build Tools (MSVC 14.44, Windows SDK
10.0.26100), but the checks below have not yet been exercised against the
Windows desktop. Flutter widget tests do not establish any of the native
windowing results below.

Build the Windows runner with the documented Flutter/Visual Studio toolchain.
Run each check on Windows 10 or 11, including a mixed-DPI two-monitor setup with
one display positioned left of the primary display. Record OS/build, monitor
scales, application build, and pass/fail evidence alongside the results.

| Check | Steps and expected result | Result |
|---|---|---|
| Tray-only capture | Launch ProShottr, close its editor to the tray, and focus a text field in another app. Press `Alt+Shift+S`. Check the taskbar and `Alt+Tab`: the capture overlay adds neither an app button nor a switcher entry. | Pending |
| Confirm and restore focus | Capture an area, annotate, then press `Enter`. The overlay disappears without an editor flash. Type into the previous app: it retains focus. Paste the clipboard into an image-capable app and confirm the annotations and pixel dimensions. | Pending |
| Cancel and restore focus | Repeat capture and cancel with `Esc`, right-click, and the HUD cancel button. The editor stays hidden and the previous app receives subsequent typing. Existing editor image/annotations survive cancellation. | Pending |
| Focus-loss cancellation | Switch to another app while selecting or annotating. The idle capture dismisses and the newly selected app retains focus. Moving focus into ProShottr's owned Save As dialog must not cancel capture. | Pending |
| Explicit editor promotion | From the Quick HUD open the Pro editor. The editor appears at its normal previous placement, with exactly one taskbar/switcher entry. Its text inputs and shortcuts receive keyboard input. | Pending |
| Native save ownership | Press `Ctrl+S` in Quick mode. Save As is a modal dialog owned by the capture overlay; the editor does not appear. Type a filename, navigate folders, cancel with `Esc`, and verify the same selection and annotations remain usable. Repeat and save: the PNG matches the capture and Quick mode stays open. | Pending |
| Save overwrite/failure | Save to an existing filename and decline overwrite: no replacement occurs. Accept overwrite separately and inspect the PNG. Attempt an unwritable location: the app reports failure and the session remains usable. | Pending |
| Native pin | Press `Ctrl+P` after annotation. The overlay dismisses, the previous app receives focus, and the image stays above other windows. Drag the image, scroll to resize with the aspect ratio preserved, use the minus/plus controls to collapse/expand, double-click to restore original scale, and close it using its cross or `Esc` while focused. | Pending |
| Pin lifetime | Create several pins, close and reopen the editor, and verify pins remain visible. Close pins and exit via the tray: all pin windows and the tray icon disappear. | Pending |
| Visible window bounds | Hover windows across different applications and overlapping windows of the same application. Click once to capture each visible frame, excluding invisible resize margins. Minimized windows and windows cloaked on another virtual desktop must not be selected. | Pending |
| Multi-monitor geometry | Select across monitors and hover windows on a negative-coordinate display. The overlay covers the virtual desktop, hit-test bounds align with visible edges, and saved pixel dimensions remain physical raster dimensions. | Pending |
| Mixed-DPI probe and badge | With one display at 100% and one at 150% or 200%, move the crosshair between them: the `LOC` line gains the `@1.5x`/`@2x` suffix only over the scaled display, and with logical units enabled the numbers divide by that display's scale. Drag a selection centred on each display and confirm the `w × h` label and the Quick HUD badge use that display's scale while the saved PNG keeps physical dimensions. | Pending |
| Crop export | In Quick mode press `C`, drag inside the capture, and confirm the badge, the un-dimmed region, and the toolbar follow the crop. Copy, save, and pin: every output has exactly the crop's pixel dimensions and the annotations stay in place. `Ctrl+Z` restores the full capture, `Ctrl+Y` re-applies the crop, and `Shift+C` resets it. | Pending |
| Capture transition races | Rapidly repeat the hotkey, cancel while a crop is pending, or use tray Show ProShottr during capture preparation. No stale capture should reopen the overlay or strand a hidden Quick session. | Pending |
| Output transition races | During copy/pin operations press `Esc` or `Alt+F4`; an operation that is still busy must finish without leaving an invisible Quick session. Open Save As and choose tray Exit: the dialog closes and the process exits without an orphan window or crash. | Pending |

The native channel is `proshottr/windows_capture_window`. `pinImage` and
`savePngAs` accept `{pngBytes: Uint8List}`. Pin returns no value; save returns a
UTF-8 path, or `null` on cancellation. Pin decoding currently supports PNG up to
64 megapixels and composites transparency on white. Foreground restoration uses
the Windows foreground API and must be checked against real foreground apps,
including elevated apps, because Windows may deny an activation request.
