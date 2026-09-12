# Screenshot Feature Analysis: WeChat vs. Shottr

A detailed feature breakdown of the two screenshot experiences that inspire **ProShottr**:

1. **WeChat's built-in screenshot tool** — the lightweight, chat-oriented capture tool baked into WeChat Desktop (Windows & Mac).
2. **Shottr** — a dedicated, pro-grade macOS screenshot utility for designers, front-end engineers, and "pixel professionals."

The goal of this document is to catalog *everything* each tool does so ProShottr can decide what to adopt, merge, or improve.

---

## Table of Contents

- [1. WeChat Screenshot Tool](#1-wechat-screenshot-tool)
  - [1.1 Activation & Capture](#11-activation--capture)
  - [1.2 Region Selection](#12-region-selection)
  - [1.3 Annotation Tools](#13-annotation-tools)
  - [1.4 Output & Sharing](#14-output--sharing)
  - [1.5 Pin to Screen](#15-pin-to-screen)
  - [1.6 OCR & Text Extraction](#16-ocr--text-extraction)
  - [1.7 Settings & Behavior](#17-settings--behavior)
  - [1.8 Confirmed Open Follow-ups](#18-confirmed-open-follow-ups-from-the-hands-on-pass)
- [2. Shottr (macOS)](#2-shottr-macos)
  - [2.1 Capture Modes](#21-capture-modes)
  - [2.2 Annotation & Markup](#22-annotation--markup)
  - [2.3 Image Manipulation](#23-image-manipulation)
  - [2.4 OCR & Text Recognition](#24-ocr--text-recognition)
  - [2.5 Measurement & Analysis](#25-measurement--analysis)
  - [2.6 Color Tools](#26-color-tools)
  - [2.7 Zoom & Magnification](#27-zoom--magnification)
  - [2.8 Pinning & Storage](#28-pinning--storage)
  - [2.9 Upload & Sharing](#29-upload--sharing)
  - [2.10 Keyboard Shortcuts & Customization](#210-keyboard-shortcuts--customization)
  - [2.11 Integrations & Automation](#211-integrations--automation)
  - [2.12 Preferences & Performance](#212-preferences--performance)
- [3. Side-by-Side Comparison](#3-side-by-side-comparison)
- [4. Implications for ProShottr](#4-implications-for-proshottr)
- [Sources](#sources)

---

## 1. WeChat Screenshot Tool

WeChat's screenshot tool is a **capture-annotate-send** utility optimized for speed and chat workflows. It is intentionally minimal — the priority is getting an annotated image into a conversation in seconds. It ships inside the WeChat Desktop client on both Windows and macOS.

> **Verification note:** the original version of this section was written from documentation/secondary sources (see [Sources](#sources)). It has since been corrected and expanded against a **hands-on, click-by-click exploration of the real WeChat Desktop client for Windows** (`Alt+A`), performed 2026-07-22 — every tool was clicked, every sub-panel opened, every tooltip read. Rows below marked **Verified** were confirmed directly; unmarked rows are carried over from the original research pass and haven't been independently re-tested (mostly macOS-only items, since the hands-on pass was Windows-only). Where the two sources disagreed, the hands-on findings win. A full narrative writeup of the exploration lives alongside this doc.

### 1.1 Activation & Capture

| Feature | Detail |
|---|---|
| **Global hotkey** | `Alt + A` on Windows (**Verified**); `⌘ + Shift + A` on macOS (unverified, not re-tested). Works even when WeChat is in the background (as long as WeChat is running). |
| **Customizable hotkey** | The screenshot shortcut can be reassigned in Settings (useful because `Alt+A` conflicts with other apps). Unverified in this pass. |
| **In-chat button** | A scissors/screenshot icon in the chat input toolbar triggers capture without a keyboard shortcut. Unverified in this pass. |
| **Instant freeze** | On activation the screen freezes so moving/animated content can be captured cleanly. |
| **Live coordinate + color readout (crosshair)** | **Verified — not previously documented.** Before you even start dragging, the crosshair cursor displays `LOC x,y` (pixel coordinates) and `HEX #rrggbb` (color under the cursor) in a small floating readout. This makes the capture trigger double as an instant color picker, with zero extra steps or mode switches. |

### 1.2 Region Selection

| Feature | Detail |
|---|---|
| **Rectangular region select** | Click-drag to define the capture area. **Verified.** |
| **Automatic window/UI detection** | Hovering highlights the window or UI element under the cursor; a single click captures that element's bounds automatically. Unverified in this pass. |
| **Resize handles** | The selected region can be adjusted via green edge/corner handles after the initial drag. **Verified.** |
| **Dimension readout** | Live pixel dimensions (`width x height`) are displayed above the selection during/after the drag. **Verified.** |
| **Reposition** | The whole selection can be moved before confirming. Unverified in this pass. |

### 1.3 Annotation Tools

WeChat presents a toolbar attached to the selection once a region is chosen. **Verified, exact tool set and behavior (left-to-right):**

| # | Tool | Verified Detail |
|---|---|---|
| 1 | **Rectangle / Box** | Draws a **filled, solid-color** rectangle — not an outline. This corrects the earlier assumption that it was outline-only. |
| 2 | **Ellipse / Circle** | Draws an **outline-only** ellipse/circle — confirmed to behave differently from Rectangle in the exact same toolbar/session, using the same color swatch. This fill/outline asymmetry is a genuine, deliberate-looking inconsistency in WeChat's own design. |
| 3 | **Sticker / Emoji** | Not "some versions allow dropping emoji" — it's a full first-class tool with its own picker panel: a **Recent** row, an **All Stickers** grid, and category tabs along the bottom (faces, hearts, hands, etc.). Placing a sticker centers it in the selection; it looks repositionable afterward. |
| 4 | **Arrow** | Directional arrow with a solid arrowhead. Color/stroke-width selectable via the shared sub-toolbar. |
| 5 | **Pen / Brush** | Freehand drawing, **no arrowhead** (distinct from Arrow) — plain line, same color/stroke picker. |
| 6 | **Mosaic** | Pixelates/obscures the dragged area. Has its own sub-toolbar with a brush-size picker **and a separate "AI masking" toggle button** — implying automatic detection/masking of sensitive regions (faces, text, etc.) rather than only manual dragging. Not visually confirmed against real faces/text (test region had neither) — flagged as a follow-up. |
| 7 | **Text** | Click-to-place, type immediately. Sub-toolbar offers exactly **3 font sizes** (small/medium/large "A" icons), not an arbitrary size control, plus the shared color palette. |

**Shared sub-toolbar** (tools 1, 2, 4, 5, 6): **3 stroke-width presets** (thin/medium/thick — fixed presets, not a slider) and a **6-swatch color palette** (blue, green, yellow, grey, white, red); the active swatch/size gets a highlight ring.

Two more toolbar icons sit next to Text, both **greyed out unless the selection contains real photo/text content**:
- **Translate** and **Extract Text** — see [§1.6](#16-ocr--text-extraction), which they now belong to functionally even though they live in the same toolbar row.
- A third, unidentified icon (exclamation-in-a-box) sits beside them, also greyed out on blank content — likely a secondary detection feature, not conclusively identified.

**Undo** (`Ctrl+Z`) is present and confirmed; a corresponding **Redo** control was not located during this pass (open follow-up — the original "Undo/Redo" claim is only half-verified).

### 1.4 Output & Sharing

| Action | Detail |
|---|---|
| **Send to chat** | Tooltip-confirmed as "Send to Chat" — the signature feature, presumably drops the annotated screenshot straight into the currently open conversation. **Deliberately not clicked-through during the hands-on pass**, since doing so on a live account risks actually sending an image to a real contact/group without a separate confirmation step. Exact semantics (instant-send vs. attach-to-compose-box) remain unverified — retest only in a disposable/test chat. |
| **Copy to clipboard** | The green **Done** (✓) button confirms the capture and copies the annotated image to the clipboard. **Verified.** |
| **Save to file** | Opens a native OS "Save As" dialog — **Verified**, and more specific than previously documented: it pre-fills a **timestamp-based filename** (e.g. `22_132136_668.png`) and defaults to a `Desktop\Temp`-style folder. It always prompts; it does not silently auto-save. |
| **Cancel** | The red **Quit** (✖) button aborts/discards the capture session. **Verified** (button click); `Esc` shortcut specifically not confirmed to close the tool in this pass — it left annotation mode active rather than exiting, so treat "Esc cancels" as unverified. |

### 1.5 Pin to Screen

| Feature | Detail |
|---|---|
| **Pin/float capture** | **Verified**, and more concrete than previously documented: clicking Pin spawns a small, freely movable, **always-on-top window with its own minimize and close controls** — a real lightweight window, not just a borderless sticky overlay. |
| **Move & dismiss** | The pinned window can be dragged around and closed via its own titlebar controls when no longer needed. **Verified.** |

### 1.6 OCR & Text Extraction

| Feature | Detail |
|---|---|
| **Extract text from images** | **Corrected and substantially expanded.** This is *not* limited to right-clicking a received image — it's a first-class button in the capture-selection toolbar itself (see [§1.3](#13-annotation-tools)), greyed out until the selection contains recognizable content. Clicking it doesn't just copy silently: it opens a whole dedicated floating **"Screen Capture" window** with: an image preview pane (its own Sticky/pin, Back/Forward history, Zoom/Shrink, Original-size, Rotate, and an Edit button that reopens the annotation toolbar) on the left, and a side panel on the right listing every recognized line of text, selectable/copyable. Verified against a real chat screenshot — it correctly OCR'd the usernames "Miao", "Xiaoyao Luotuo", and "Miao:" out of the image. That window also has its own **"…" overflow menu**: Copy, Print, Forward…, Add to Favorites, Open with the default (app) — plus independent Translate and Save actions. |
| **Translate** | Present as a toolbar button, greyed out over content with no text. When tested against already-Latin text (usernames, no actual sentence to translate), clicking it simply closed the OCR panel with no visible translated output — behavior against genuine non-English source text is unverified (follow-up). |
| **Language coverage** | Strong Chinese + English recognition reported (WeChat's core markets) — not independently re-verified in this pass. |

### 1.7 Settings & Behavior

| Setting | Detail |
|---|---|
| **Hide WeChat during capture** | Option to auto-hide the WeChat window while taking a screenshot so it isn't in the shot. Unverified in this pass. |
| **Hotkey remap** | Reassign the capture shortcut to avoid OS/app conflicts. Unverified in this pass. |
| **Screen recording** | Newer desktop builds add basic screen recording alongside stills. Unverified in this pass. |

> **Summary of WeChat's philosophy:** minimal, fast, chat-first. Capture → mark up in a few taps → send. It deliberately omits pro tooling (measurement, precise color, scrolling capture) in favor of zero-friction sharing — though the hands-on pass shows a few "pro-ish" surprises baked in anyway: a live color-picker crosshair, AI-assisted mosaic masking, and a full secondary OCR window with its own history/zoom/rotate controls.

### 1.8 Confirmed Open Follow-ups (from the hands-on pass)

1. **AI masking** (Mosaic) — retest against a region with real faces/visible text to confirm the auto-detect behavior.
2. **Send to Chat** — confirm instant-send vs. attach-to-compose-box, only in a context where sending is safe.
3. The unidentified exclamation/box icon next to Translate/Extract Text.
4. **Translate** — retest against genuine non-English source text.
5. **Redo** — locate the redo shortcut/button (only undo was confirmed).
6. macOS-specific items (`⌘+Shift+A` hotkey, hotkey remap, in-chat scissors button, hide-during-capture, screen recording) — the hands-on pass covered Windows only; re-verify on macOS before treating them as confirmed.

---

## 2. Shottr (macOS)

Shottr is a **native, Apple-Silicon-optimized** screenshot powerhouse. It is tiny (~2.3 MB) yet dense with professional tools. Capture takes ~17 ms; the editor appears in ~165 ms. It targets designers, developers, and anyone who needs pixel-level precision.

### 2.1 Capture Modes

| Mode | Detail |
|---|---|
| **Area capture** | Select and grab any rectangular region, with fine keyboard nudging of the selection. |
| **Window capture** | Grab a single window with options for shadow preservation, trimming, solid backgrounds, or wallpaper integration. |
| **Fullscreen capture** | Grab the entire screen; multi-monitor & Retina aware. |
| **Scrolling screenshot** | Automatically stitch long web pages, chats, or documents into a single tall image. |
| **Repeat-area screenshot** | Re-capture a previously selected region instantly. |
| **Delayed screenshot** | 3-second delay for capturing menus/hover states. |
| **Auto-adjust selection** | Press `A` to snap the selection to detected content edges; hold `⌥` for a live preview. |
| **Square selection** | Hold `Shift` while selecting to constrain to a square. |
| **Monotone object select** | Hold `⌘` and click a single-color object to select it quickly. |

### 2.2 Annotation & Markup

| Tool | Detail |
|---|---|
| **Text labels** | Custom size and color. |
| **Freehand drawing** | Stroke variability + smoothness controls (`⌥ + ↑/↓`); `⌘+Enter` toggles pressure-style width variance. |
| **Arrows** | Straight, curved, bendable, and multi-directional variants; `⌘+click` reverses direction. |
| **Rectangles & ovals** | With fill and opacity controls. |
| **Highlighter** | Marker-style text highlight. |
| **Spotlight** | Dim the background and spotlight a region (adjustable background opacity). |
| **Step counter** | Numbered badges (1, 2, 3…) for tutorials/walkthroughs. |
| **Hand-drawn style** | Sketchy/hand-drawn rendering for text, arrows, ovals, and rectangles. |
| **Object editing** | Copy/paste individual objects (`⌘C` / `⌘V`); selected objects jump to the front layer; configurable snapping; move-while-drawing via `Space+drag`. |
| **Guides** | `⌥+S` (vertical) / `⌥+D` (horizontal) alignment guides. |
| **Undo / Redo** | Full history via keyboard shortcuts. |

### 2.3 Image Manipulation

| Feature | Detail |
|---|---|
| **Crop** | Select area, press Enter to crop. |
| **Resize** | Scale the image up/down inside the app. |
| **Backdrop tool** | Add gradient backgrounds, drop shadows, and rounded corners (great for polished social/marketing shots). |
| **Image overlay** | Paste one image atop another; semi-transparent overlays for before/after comparisons. |
| **Before/After GIF** | Generate two-frame GIF animations for side-by-side comparisons. |
| **Blur / Pixelate / Erase** | Hide sensitive data; a text-only mode obscures text without corrupting the rest of the image. |
| **Format selection** | PNG or JPEG, plus an auto-format mode that picks the best format for the content. |

### 2.4 OCR & Text Recognition

| Feature | Detail |
|---|---|
| **Area OCR** | Hotkey + select → text is parsed and copied to the clipboard. |
| **QR code reading** | OCR also decodes QR codes. |
| **Chinese support** | Recognizes Chinese characters when enabled. |
| **Line-break removal** | Optional toggle to strip line breaks from recognized text. |

### 2.5 Measurement & Analysis

| Feature | Detail |
|---|---|
| **Screen ruler** | `↑/↓` measures vertical size, `←/→` measures horizontal size as you move the mouse. |
| **Distance measurement** | Measure the gap between two objects by positioning the cursor and pressing directional keys. |
| **Logical vs. physical pixels** | Click the size indicator to toggle between logical and physical (Retina) pixel readouts. |

### 2.6 Color Tools

| Feature | Detail |
|---|---|
| **Color picker** | Zoom into pixels, press `TAB` to copy the color under the cursor. |
| **Copy text color** | `Shift+TAB` over a line of text extracts its color. |
| **Copy average color** | Select an area, press `C` to copy its average color. |
| **Contrast checker** | WCAG 2.0 and APCA contrast-ratio analysis. |
| **Formats** | HEX, HEX without `#`, and OKLCH. |

### 2.7 Zoom & Magnification

| Feature | Detail |
|---|---|
| **Screen magnifier** | Acts as a digital magnifying glass for pixel inspection. |
| **Multiple zoom methods** | `Z+click`, keyboard (`⌘1`, `⌘0`, `⌘±`), trackpad/Magic Mouse gestures. |
| **Zoom on selection** | `⌘2` zooms to the selected region. |
| **Corner zoom** | `Q` / `W` zoom to the top-left / bottom-right selection corners. |
| **Pan** | Right-mouse drag or `Space + left-click` to move the image around. |

### 2.8 Pinning & Storage

| Feature | Detail |
|---|---|
| **Pin screenshots** | Floating, always-on-top, borderless reference windows. |
| **Scroll-to-resize pins** | Resize a pinned image via scroll gesture. |
| **Dedicated save folder** | Configure a folder for auto-saved captures. |
| **Auto-save / auto-copy** | Automatically save or copy after each capture. |

### 2.9 Upload & Sharing

| Feature | Detail |
|---|---|
| **S3 upload** | Upload to any S3-compatible storage (AWS, Tencent, Yandex, Minio, etc.). |
| **Upload management** | View/manage previously uploaded screenshots. |
| **Drag-and-drop export** | Drag the capture directly into other apps. |
| **One-click share** | Clipboard, email, or cloud. |

### 2.10 Keyboard Shortcuts & Customization

| Group | Shortcuts |
|---|---|
| **Nudge selection** | Arrows = 1 px; `Shift+`arrows = 10 px. |
| **Resize selection** | `⌘+`arrows = 1 px; `⌘+Shift+`arrows = 10 px. |
| **Grow selection** | `[` / `]` = ±1 px per side; `Shift+[` / `Shift+]` = ±10 px. |
| **Custom hotkeys** | Assign shortcuts to capture modes and actions ("Capture Any Window", "Reopen Shottr", etc.). |

### 2.11 Integrations & Automation

| Feature | Detail |
|---|---|
| **URL scheme API** | Automate Shottr via URL schemes. |
| **Raycast extension** | First-class Raycast support. |
| **Alfred workflow** | Alfred integration. |
| **Clipboard managers** | Compatible with third-party clipboard tools. |

### 2.12 Preferences & Performance

| Feature | Detail |
|---|---|
| **Native & tiny** | ~2.3 MB, Apple-Silicon optimized; 17 ms capture, 165 ms to editor. |
| **macOS support** | Catalina (10.15) and newer; Retina & multi-monitor aware. |
| **Notification control** | Custom confirmations for OCR, color copy, save, upload — or disable entirely. |
| **Window behavior** | Default zoom level, always-on-top, preview vs. editor on capture. |
| **Telemetry toggle** | Opt out of telemetry. |
| **Auto-update** | Built-in update checking. |
| **Splash toggle** | Hide the splash screen on launch. |

---

## 3. Side-by-Side Comparison

| Capability | WeChat | Shottr |
|---|:---:|:---:|
| Global capture hotkey | ✅ | ✅ |
| Live coordinate/color crosshair pre-drag | ✅ (verified) | ❌ |
| Auto window/UI detection | ✅ | ✅ |
| Basic annotation (box, circle, arrow, pen, text) | ✅ (box **filled**, ellipse **outline-only** — verified asymmetry) | ✅ |
| Sticker/emoji picker (recents + categories) | ✅ (verified — full picker, not a quick-row) | ❌ |
| Mosaic / blur | ✅ (manual + **AI-masking toggle**, verified) | ✅ (blur, pixelate, erase, text-only) |
| Undo/redo | ⚠️ (undo verified; redo not located) | ✅ |
| Step counter | ❌ | ✅ |
| Spotlight / highlighter | ❌ | ✅ |
| Hand-drawn styles | ❌ | ✅ |
| **Scrolling capture** | ❌ | ✅ |
| Window capture w/ shadow/backdrop | ❌ | ✅ |
| Delayed / repeat capture | ❌ | ✅ |
| **OCR (area select)** | ✅ (verified — a toolbar button on the capture itself, opens a dedicated result window w/ history/zoom/rotate, not just "on received images") | ✅ (live area OCR) |
| QR code reading | ❌ | ✅ |
| **Measurement / ruler** | ❌ | ✅ |
| **Color picker / contrast** | ⚠️ (pre-drag crosshair gives HEX color; no contrast checker) | ✅ |
| Pixel magnifier / zoom | ❌ | ✅ |
| Pin to screen | ✅ (verified — real minimize/close window) | ✅ (+ scroll resize) |
| Send directly to chat | ⚠️ (button confirmed via tooltip; exact send-vs-attach behavior unverified — not risked on a live account) | ❌ |
| Copy / save | ✅ (verified — Save opens an OS dialog w/ timestamp default name, doesn't silently auto-save) | ✅ |
| Cloud/S3 upload | ❌ | ✅ |
| Backdrop / before-after GIF | ❌ | ✅ |
| Automation (URL scheme, Raycast, Alfred) | ❌ | ✅ |
| Screen recording | ✅ (newer builds, unverified) | ❌ (focus is stills) |
| Cross-platform | ✅ (Win + Mac) | ❌ (Mac only) |

Legend: ✅ full · ⚠️ partial/indirect · ❌ absent

---

## 4. Implications for ProShottr

**What to borrow from WeChat**
- Zero-friction *capture → annotate → send/share* flow; the "send straight to destination" step is its standout (though its exact send-vs-attach behavior still needs verification before copying it 1:1).
- Extremely lightweight, uncluttered annotation toolbar — with real nuance worth copying deliberately rather than assuming: Rectangle fills solid while Ellipse stays outline-only, Mosaic offers a manual/AI-masking split, Text is capped at 3 discrete sizes, and stroke width is 3 fixed presets rather than a slider.
- The pre-drag crosshair that shows live pixel coordinates + HEX color — a free, zero-extra-step color picker folded into the capture trigger itself.
- Auto window/element detection on hover.
- The OCR "Extract Text" surface is bigger than expected: a full secondary window with history/zoom/rotate/overflow-menu, not a clipboard-only action — worth matching that depth, not just the headline "OCR" checkbox.
- Cross-platform reach (WeChat runs on both Windows and Mac).

**What to borrow from Shottr**
- Scrolling capture, window capture with backdrops, delayed/repeat capture.
- Pro tooling: pixel ruler/measurement, color picker + contrast checker, magnifier.
- Live area OCR (+ QR decoding) with clipboard output.
- Rich annotation: spotlight, step counter, hand-drawn styles, object-level editing.
- Pin-to-screen with scroll resize; auto-save folders; S3/cloud upload.
- Automation surface (URL schemes / launcher integrations) and native performance.

**The ProShottr opportunity:** combine WeChat's *speed-to-share* simplicity with Shottr's *pro-precision toolset* — a fast default path for casual users, with pro tools (scrolling capture, OCR, measurement, color) one keypress away, delivered cross-platform.

**Where the two flow-critical surfaces are specified.** The borrowed capture trigger and the borrowed annotation toolbar are no longer described only as feature rows — each has a literal build spec in the plan, including the places ProShottr deliberately goes past WeChat:
- [`plan.md` §8.8](plan.md#88-capture-trigger-overlay--the-pre-selection-stage-spec) — the capture overlay: dim wash over the frozen desktop, drawn `+` crosshair, a probe box carrying coordinates, hex **and RGB** with a swatch (WeChat shows coordinates and hex only), hover window detection that re-runs across app boundaries, one-click window capture, drag-for-region.
- [`plan.md` §8.9](plan.md#89-post-capture-editing-toolbar--the-quick-hud-layout-spec) — the post-capture editing toolbar: four button groups (draw tools, content tools, output, session end), the style sub-toolbars, enable/disable rules, anchoring, the narrow-selection overflow behavior, and the `W × H` resolution badge that appears over the capture with the bar.
- [`plan.md` §8.10](plan.md#810-windowing-model--the-capture-session-is-an-overlay-never-an-app-window) — the rule underneath both: a capture session is an overlay, not an application window. No taskbar button, no Alt-Tab entry, no visible main window until the user deliberately opens an editing surface. Both source apps behave this way; the plan section makes it an explicit, testable requirement rather than an assumption.

---

## Sources

- **Hands-on exploration of WeChat Desktop for Windows (`Alt+A`), 2026-07-22** — primary/authoritative source for all rows marked **Verified** in [§1](#1-wechat-screenshot-tool); performed by directly operating the live app rather than reading documentation. See also `plan.md` §6.8 for the same findings framed as a build-parity spec.
- [Shottr — official site](https://shottr.cc/)
- [Shottr on Tao of Mac](https://taoofmac.com/space/apps/shottr)
- [Shottr for Mac Review 2026 — ScreenSnap](https://www.screensnap.pro/blog/shottr-mac-review)
- [Shottr — TryMacApps](https://www.trymacapps.com/app/shottr)
- [What does Alt + A do in WeChat (Desktop)? — DefKey](https://defkey.com/wechat-desktop-shortcuts/alt-a-55541)
- [WeChat (Desktop) keyboard shortcuts — DefKey](https://defkey.com/wechat-desktop-shortcuts)
- [WeChat for Windows tutorial — DumbChat](https://www.dumbchat.ai/en/wechat-for-windows-en/)
- [Introducing WeChat for Windows — WeChat Blog](https://blog.wechat.com/2015/06/05/introducing-wechat-for-windows/)
- [Screenshot feature like WeChat Desktop — microsoft/PowerToys #12531](https://github.com/microsoft/PowerToys/issues/12531)
