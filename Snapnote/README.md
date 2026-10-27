# SnapNote

A local-only study notes app: organize notes into **Subjects**, each holding
many **Entries**. Entries can be typed directly or captured as a photo and
transcribed via the Gemini API. Math is preserved as LaTeX (`$...$` inline,
`$$...$$` block) and rendered in-app.

## Hard constraints (by design)

- **No login, no cloud sync.** All data lives in a local SQLite database
  (`sqflite`) in the app's documents directory.
- **No PDF/Word export.** Entries are viewed and edited only inside the app.
- **Gemini API, free tier** (`google_generative_ai`, model
  `gemini-3.5-flash-lite`), used only for photo → text transcription, not
  OpenAI.
- **Math as LaTeX**, rendered with `flutter_math_fork`.

## App flow

```
HomeScreen  ──tap subject──▶  SubjectDetailScreen  ──FAB──▶  CaptureScreen  ──confirm photo──▶  EntryEditorScreen
(Subjects,                    (Entries for one                (camera/gallery,                  (auto-transcribes
 create/delete)                 subject, create/delete)         preview, retake)                  initialImagePath,
                                                                                                     or type/edit text)
```

- **HomeScreen** — lists Subjects with a live entry count per subject, create
  via FAB + dialog, delete via swipe-to-dismiss or long-press (both go
  through the same cascade-delete confirmation dialog).
- **SubjectDetailScreen** — lists Entries for one Subject; loads the Subject
  by id so a rename elsewhere is picked up. FAB opens **CaptureScreen** (not
  the editor directly) so every new entry with a photo goes through capture
  first; tapping an existing entry opens **EntryEditorScreen** directly for
  text-only edits.
- **CaptureScreen** — camera or gallery entry point, preview with
  retake/confirm, then `pushReplacement`s into **EntryEditorScreen** with
  the photo's path.
- **EntryEditorScreen** — if opened with `initialImagePath` (from
  CaptureScreen), auto-transcribes on open; otherwise it's a plain text
  editor with a preview toggle for the rendered LaTeX. Camera/Gallery
  buttons were intentionally removed from this screen — CaptureScreen is
  now the single entry point for adding a photo.

## Error handling

- Failed Subject/Entry create/delete/save calls are caught and reported via
  a `SnackBar` ("Couldn't save subject — try again", etc.) instead of
  failing silently or crashing.
- `EntryEditorScreen._save()` only pops the screen on success, so a failed
  save leaves the user's typed content in place rather than losing it.
- `GeminiTranscriptionService` distinguishes a free-tier rate-limit/quota
  error from other failures and surfaces a distinct message ("You've hit
  the free-tier rate limit — wait a moment and try again"). The
  `google_generative_ai` package doesn't expose a structured HTTP status
  code on its exceptions, so this is done by pattern-matching the
  exception's message text (`429`, `quota`, `resource_exhausted`, etc.) —
  worth re-checking against the real package behavior once this runs
  against a live API key, in case Google changes that wording.

## Project layout

```
lib/
  models/     Subject, Entry — plain data classes with toMap/fromMap
  data/       DatabaseHelper (sqflite schema + raw CRUD) and
              SubjectRepository / EntryRepository (the API screens use)
  services/   GeminiTranscriptionService, ImageStorageService
  screens/    HomeScreen, SubjectDetailScreen, CaptureScreen, EntryEditorScreen
  widgets/    LatexContentView
main.dart     Loads .env, launches HomeScreen
```

> `widgets/subject_tile.dart` is currently unused — `HomeScreen` builds its
> Subject rows inline (needed the `Dismissible` wrapper for swipe-to-delete)
> rather than using this widget. Left in place rather than deleted in case
> it's wanted back for the entry count/rename styling; safe to remove or
> revive as a cleanup pass.

Data model:

```
Subject(id, name, createdAt)
Entry(id, subjectId, content, sourceImagePath, createdAt, updatedAt)
```

`subjectId` is a foreign key with `ON DELETE CASCADE`, so deleting a Subject
deletes its Entries. Deleting an Entry via `EntryRepository.delete()` also
removes its copied photo from local storage (`ImageStorageService`) if it
had one — the DB row and the file are cleaned up together.

## Setup

1. Install Flutter (stable channel) and run:
   ```
   flutter pub get
   ```
2. Get a **free** Gemini API key: https://aistudio.google.com/app/apikey
3. Copy the example env file and add your key:
   ```
   cp .env.example .env
   # edit .env, set GEMINI_API_KEY=...
   ```
4. Run the app:
   ```
   flutter run
   ```

`.env` is git-ignored — only `.env.example` is committed.

**Known limitation:** `.env` is bundled as a Flutter asset so `flutter_dotenv`
can load it at runtime, which means the Gemini key ships inside the compiled
APK/IPA and is extractable from the build artifact. Fine for a free-tier key
used for personal/demo purposes; do not put a billed key in `.env` under this
setup. Proxying transcription through a small backend (so the key never
ships client-side) would remove this limitation but is out of scope for the
local-only design so far.

## Status

Data layer, services, and full CRUD screens are wired up and functional,
including the capture → transcribe → edit flow and SnackBar-based error
handling, but this hasn't been run against a real Flutter SDK/device in this
environment. Before shipping, run `flutter pub get`, `flutter analyze`, and
test transcription (including a deliberately-triggered rate-limit case)
against a real Gemini API key.

Known follow-ups worth doing next:
- Add a proper Markdown/LaTeX split renderer if entries grow richer formatting
  needs beyond plain text + math.
- Add unit tests for `DatabaseHelper` (e.g. with `sqflite_common_ffi`), for
  `LatexContentView`'s segment parser (including a block-equation case, to
  guard against the `Wrap`/`SizedBox(width: infinity)` crash that was fixed
  there), and for `GeminiTranscriptionService._isRateLimitError`.
- Handle Android/iOS camera & photo library permissions explicitly (image_picker
  needs `NSCameraUsageDescription`/`NSPhotoLibraryUsageDescription` on iOS and
  the relevant `<uses-permission>` entries on Android — see the doc comment
  in `capture_screen.dart`).
- Either remove `widgets/subject_tile.dart` or fold it back into
  `HomeScreen`'s list rendering.