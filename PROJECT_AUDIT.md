# PROJECT_AUDIT.md — EASE Architecture & Codebase Audit

**Date**: November 13, 2026  
**Auditor**: Senior Technical Lead & Product Architect  
**Project**: EASE (AI-Powered Project Memory Assistant)  
**Location**: `/Users/ashishkumarsharma/Desktop/EasePrototype0`

---

## 1. Executive Summary

EASE is structured as a full-stack mono-repository consisting of:
1. **Backend**: Python 3.11+ / FastAPI service with SQLAlchemy 2.0 (asyncio + aiosqlite), Alembic migrations, Pydantic v2 schemas, AES-256 Fernet biometric vault encryption, AssemblyAI / Deepgram STT adapters, Gemini Flash LLM adapter (`gemini-1.5-flash`), and Gemini vector embeddings.
2. **iOS Client**: Native SwiftUI (iOS 17+), XcodeGen specification (`ios/project.yml`), AVFoundation audio recorder and player, AVSpeechSynthesizer audio brief engine, EventKit reminders integration, WatchConnectivity session manager, and custom liquid glassmorphic design components (`GlassComponents.swift`).
3. **Apple Watch Target (`EaseWatch`)**: Standalone watchOS 10+ remote recording app with phone consent synchronization.
4. **Widget Target (`EaseWidget`)**: Home Screen WidgetKit extension with AppIntent briefing audio trigger and upcoming follow-ups timeline.

---

## 2. Architecture & Frameworks Audit

### 2.1 Backend Architecture
- **Web Framework**: FastAPI 0.115+ running on Uvicorn with async ASGI transport.
- **Database**: SQLite via `sqlite+aiosqlite` for prototype development; models mapped cleanly via SQLAlchemy Declarative Base (PostgreSQL-ready with UUID primary keys and ISO UTC timestamps).
- **Security & Cryptography**:
  - JWT Access (`HS256`, 60-min expiry) & Refresh tokens (7-day expiry). Passwords hashed using bcrypt.
  - Development bypass mode for instant simulator preview with persistent fallback demo identity.
  - Biometric Voice Vault: AES-256 Fernet symmetric encryption at rest for 192-dimensional acoustic speaker embeddings.
- **Provider Adapters**:
  - STT: `AssemblyAIAdapter` (default, diarization with speaker hints), `DeepgramAdapter` (alternative).
  - LLM: `GeminiLLMAdapter` configured to `gemini-1.5-flash` with strict JSON schema validation, regex markdown code fence stripping, and single-turn automated repair retry. `ClaudeLLMAdapter` (alternative).
  - Embeddings: `GeminiEmbeddingAdapter` (768-dim text embeddings for memory linking), `LocalSpeakerEmbeddingAdapter` (acoustic embedding).
- **Core Pipelines & Engines**:
  - `audio_normalizer.py`: Normalizes audio (m4a/mp3/wav) to 16kHz mono WAV using `ffmpeg`.
  - `diarization_postproc.py`: Merges same-speaker segments with gaps < 700ms, flags segments < 1.0s or confidence < 0.65 as `low_confidence_attribution`, marks overlapping segments.
  - `reconciliation.py`: Non-destructive LLM suggestion pass for short utterances without overwriting STT speaker labels.
  - `speaker_id.py`: Voice enrollment, affirmative biometric consent verification, cosine similarity matching (threshold 0.72).
  - `memory_engine.py`: Vector cosine similarity search, LLM relation judge (`CONFIRMS`, `CONTRADICTS`, `UPDATES`, `RESOLVES_PREREQUISITE`), brief script generator, Q&A citations.
  - `pipeline.py`: Async background orchestrator tracking statuses (`uploaded` ➔ `transcribing` ➔ `analyzing` ➔ `linking` ➔ `ready` / `failed`).

### 2.2 iOS Application Architecture
- **UI Framework**: SwiftUI on iOS 17+.
- **Design System**: Liquid Glassmorphism (`.ultraThinMaterial`, `Color.easeSurfaceGlass`, specular light reflection borders, neon glowing state shadows).
- **State Management**: `@MainActor final class AppEnvironment: ObservableObject`, injected via `.environmentObject(env)`.
- **Networking**: `APIClient.shared` with async/await URLSession, multipart/form-data upload, and Bearer token handling.
- **System Frameworks**:
  - `AVFoundation`: `AudioRecorder` (AAC/M4A 44.1kHz stereo recording), `AudioPlayer` (timestamp seeking and playback).
  - `AVSpeechSynthesizer`: `SpeechSynthesizerService` (spoken audio briefing with play/pause/stop and progress callback).
  - `EventKit`: `EventKitService` (exporting action items directly to Apple Reminders).
  - `Security`: `KeychainHelper` (secure token and user id storage).
  - `WatchConnectivity`: `WatchSessionManager` (bi-directional phone/watch state sharing).
  - `iCloud / FileManager`: `ICloudWorkspaceService` (writing discussion `.md` reports to `iCloud Drive ❯ EASE ❯ [Project Name] ❯ Reports`).

---

## 3. Detailed Component Inventory & Status

| Layer / Component | File Path | Status | Observations |
|---|---|---|---|
| **Backend Core Config** | `backend/app/config.py` | Functional | Has Gemini 1.5 Flash, provider toggles, rate limits, AES key. |
| **Backend Models** | `backend/app/models/` | Functional | `User`, `Project`, `ProjectMember`, `Meeting`, `Participant`, `Segment`, `ConsentRecord`, `Claim`, `Prerequisite`, `Decision`, `Link`, `MemoryEmbedding`, `AuditLog`, `Notification`, `Invite`, `SpeakerProfile`. |
| **Backend Schemas** | `backend/app/schemas/` | Functional | Pydantic v2 schemas for auth, projects, meetings, analysis, tasks, audit, briefing, iCloud sync, task dependencies. |
| **Backend API Routers** | `backend/app/api/v1/` | Functional | Auth, Projects, Meetings, Memory, Tasks, Reports, Notifications. All authenticated and project-scoped. |
| **Backend Tests** | `backend/tests/` | Functional | **26 passed in 4.91s**. All mock-based without real API billing. |
| **iOS App Entry** | `ios/EasePrototype0/App/EaseApp.swift` | Functional | Direct launch into `MainTabView` with `.preferredColorScheme(.dark)`. |
| **iOS Environment** | `ios/EasePrototype0/App/AppEnvironment.swift` | Functional | `@MainActor` ObservableObject with active project, user, and project loading. |
| **iOS API Client** | `ios/EasePrototype0/Services/APIClient.swift` | Functional | Supports GET/POST/PATCH/DELETE and multipart meeting uploads. |
| **iOS Glass Design** | `ios/EasePrototype0/Views/Components/GlassComponents.swift` | Functional | Native `.ultraThinMaterial`, `GlassStatusPill`, `GlassActionButton`, glowing shadows. |
| **iOS Dashboard** | `ios/EasePrototype0/Views/Dashboard/DashboardView.swift` | Partially Implemented | Has welcome header, project list, and follow-ups. Needs full IA Level 2 integration (Active vs Shared projects, My Tasks tabs, Upcoming Activities, Notifications sheet). |
| **iOS Project Space** | `ios/EasePrototype0/Views/Space/ProjectSpaceView.swift` | Partially Implemented | Has Overview, Discussions, Memory, Tasks, Briefing, Team & iCloud. Needs full section-specific subviews per spec. |
| **iOS Capture Flow** | `ios/EasePrototype0/Views/Capture/CaptureFlowView.swift` | Partially Implemented | Has participant selection, spoken announcement, affirmative consent, live recording, and upload. Needs end-to-end integration with Discussion Report review before memory transfer. |
| **iOS Tasks & Blockers** | `ios/EasePrototype0/Views/Space/TasksDependenciesView.swift` | Functional | Blocker chain visual cards, dependency linking, nudges, Reminders export. Needs full Task Details view and 4-role permissions. |
| **iOS Collaboration & iCloud**| `ios/EasePrototype0/Views/Space/MembersView.swift` | Functional | Apple ID collaborator invites, iCloud folder sync, Markdown reports. Needs 4 roles (Owner, Editor, Contributor, Viewer) enforcement. |
| **iOS Project Memory** | `ios/EasePrototype0/Views/Space/ProjectMemoryView.swift` | Partially Implemented | Searchable memory items with relation chips. Needs Decision History timeline and reviewable suggested relationships. |
| **iOS Planning View** | Missing | Missing | Level 1 Tab / Level 2 Planning (Calendar, Schedule Discussion, Deadlines, Reminders) not yet implemented in main navigation. |
| **iOS Settings View** | `ios/EasePrototype0/Views/Settings/SettingsView.swift` | Partially Implemented | Has Voice vault deletion and retention days. Needs Account & Apple ID, Permissions, and Data Export/Deletion. |
| **Apple Watch App** | `ios/EaseWatch/WatchContentView.swift` | Functional | Builds with `xcodebuild`. Communicates with iPhone via WCSession. |
| **Home Screen Widget** | `ios/EaseWidget/EaseWidget.swift` | Functional | Builds with `xcodebuild`. Displays latest project follow-up and PlayBrief AppIntent. |

---

## 4. Gaps Identified Against Master Prompt Specification

1. **Global App Structure (Level 1)**:
   - Current `MainTabView` only has 3 tabs: Dashboard, Capture, Settings.
   - Master prompt requires 6 sections:
     1. Home / Dashboard
     2. Project Space
     3. Capture Discussion
     4. Planning (Calendar & Schedule)
     5. Apple Ecosystem
     6. Settings
2. **Four Collaboration Roles**:
   - Master prompt strictly mandates 4 roles: `Owner`, `Editor`, `Contributor`, `Viewer`.
   - Current implementation only handled `owner` and `member`. Backend models, database permissions, and UI role controls must support all 4 roles.
3. **Discussion Participant vs Project Collaborator**:
   - Master prompt requires clear separation: A discussion participant attended an audio recording, but does NOT automatically gain project access unless explicitly invited as a project collaborator.
4. **Planning Module (Calendar & Scheduling)**:
   - Need a dedicated Planning screen with an actual calendar view, scheduled discussions, deadlines, reminders, and upcoming follow-ups.
5. **Apple Ecosystem Dedicated View**:
   - Dedicated UI for iCloud Sync & Shared Storage status, Apple Watch remote pairing & status, and Home Screen Widget setup instructions.
6. **Settings & Data Management**:
   - Comprehensive settings: Account & Apple ID, Privacy & Consent Records audit, Notifications preferences, Permissions status, Data Export (JSON/Markdown ZIP), and Data Deletion.
7. **Demonstration Dataset ("Product Launch")**:
   - Sample project "Product Launch" with:
     - Aarav Mehta — Owner
     - Riya Sharma — Editor
     - Kabir Singh — Contributor
     - Neha Kapoor — Viewer
     - Sample decisions, unresolved issues, tasks, and blocker dependency chain.
     - Resettable demo dataset mechanism.
