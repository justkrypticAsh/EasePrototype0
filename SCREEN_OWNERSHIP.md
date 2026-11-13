# SCREEN_OWNERSHIP.md — EASE Component & Screen Ownership Division

**Architecture Model**: Four-Developer Workstream Division with Unified Core Contracts  
**Project**: EASE (AI-Powered Project Memory Assistant)  
**Date**: November 13, 2026

---

## 1. Shared Core & Foundation (All Developers / Technical Lead)

All developers build on top of these shared models, protocols, and design components.

| Component / Layer | File Path | Scope & Responsibility |
|---|---|---|
| **App Entry & Navigation** | `ios/EasePrototype0/App/EaseApp.swift` | Root WindowGroup, dark mode, environment injection. |
| **Global State Manager** | `ios/EasePrototype0/App/AppEnvironment.swift` | Active project, current user, project loading, auth state. |
| **Glassmorphic Design Tokens**| `ios/EasePrototype0/Views/Components/GlassComponents.swift` | `.glassCard()`, `GlassStatusPill`, `GlassActionButton`, colors. |
| **Shared API Client** | `ios/EasePrototype0/Services/APIClient.swift` | Network transport, headers, error handling, file uploads. |
| **Shared Keychain Storage** | `ios/EasePrototype0/Services/KeychainHelper.swift` | Token, user id, and secure credential storage. |
| **Core Models** | `ios/EasePrototype0/Models/Project.swift`<br>`ios/EasePrototype0/Models/User.swift`<br>`ios/EasePrototype0/Models/Meeting.swift`<br>`ios/EasePrototype0/Models/ExtractionItems.swift` | Shared DTOs conforming to backend Pydantic schemas. |
| **Backend Database & Base** | `backend/app/database.py`<br>`backend/app/models/` | Async SQLAlchemy engine, base model, relationships. |
| **Backend Route Middleware** | `backend/app/api/deps.py` | JWT validation, demo-mode fallback, 4-role RBAC checks. |

---

## 2. Developer 1 — Home, Projects and Planning

**Module Boundary**: Top-level entry points, aggregated executive views, multi-project navigation, and calendar planning.

| Screen / Component | File Path | Type | Ownership & Purpose |
|---|---|---|---|
| **Global Navigation Container** | `ios/EasePrototype0/Views/Dashboard/MainTabView.swift` | View | Owns the Level 1 6-tab navigation structure. |
| **Executive Home Dashboard** | `ios/EasePrototype0/Views/Dashboard/DashboardView.swift` | View | Welcome greeting, projects carousel, blocker alert feed. |
| **Projects List (Active & Shared)**| `ios/EasePrototype0/Views/Dashboard/ProjectsListView.swift` | View | Filter projects by Active vs Shared, create project sheet. |
| **Project Overview & Activity** | `ios/EasePrototype0/Views/Space/ProjectOverviewSection.swift` | Subview | Identity, activity timeline, quick stats, member overview. |
| **Planning & Calendar View** | `ios/EasePrototype0/Views/Planning/PlanningView.swift` | View | Level 1 Planning tab: monthly/weekly calendar, deadlines. |
| **Schedule Discussion Sheet** | `ios/EasePrototype0/Views/Planning/ScheduleDiscussionSheet.swift`| View | Select project, select collaborators, set time, add Reminder. |
| **Notifications Sheet** | `ios/EasePrototype0/Views/Dashboard/NotificationsSheet.swift` | View | Project activity notifications, nudges, and alerts. |
| **Backend Planning & Projects** | `backend/app/api/v1/projects.py` | API | Project CRUD, activity audit feed, calendar item routes. |

---

## 3. Developer 2 — Capture and Discussion Intelligence

**Module Boundary**: Audio recording lifecycle, participant consent verification, STT transcription, diarization, speaker management, and structured discussion report review.

| Screen / Component | File Path | Type | Ownership & Purpose |
|---|---|---|---|
| **Capture Discussion Workflow** | `ios/EasePrototype0/Views/Capture/CaptureFlowView.swift` | View | 8-step connected recording & consent workflow. |
| **Audio Recorder Service** | `ios/EasePrototype0/Services/AudioRecorder.swift` | Service | AVFoundation audio recording, level meters, file management. |
| **Audio Player Service** | `ios/EasePrototype0/Services/AudioPlayer.swift` | Service | Timestamp-accurate audio snippet playback and seeking. |
| **Discussion Library View** | `ios/EasePrototype0/Views/Space/DiscussionLibraryView.swift` | View | Chronological list of discussions with duration and status. |
| **Discussion Detail & Player** | `ios/EasePrototype0/Views/Space/DiscussionDetailView.swift` | View | Synchronized transcript, claims, decisions, timestamps. |
| **Speaker Name Editing Sheet** | `ios/EasePrototype0/Views/Space/SpeakerNameEditSheet.swift` | View | User correction of "Speaker N" to recognized team members. |
| **Discussion Report Review** | `ios/EasePrototype0/Views/Capture/DiscussionReportReviewView.swift` | View | Pre-approval review before transferring to Memory & Tasks. |
| **Backend Audio & STT Services**| `backend/app/services/audio_normalizer.py`<br>`backend/app/adapters/stt/` | Service | Ffmpeg 16kHz mono normalization, AssemblyAI / Deepgram STT. |
| **Backend Diarization & Pipeline**| `backend/app/services/diarization_postproc.py`<br>`backend/app/services/pipeline.py` | Service | Gap merging, overlap flags, async meeting state orchestrator. |

---

## 4. Developer 3 — Project Memory and Briefings

**Module Boundary**: Persistent cross-discussion knowledge graph, relationship inference, decision history evolution, natural language Q&A, and pre-meeting spoken briefings.

| Screen / Component | File Path | Type | Ownership & Purpose |
|---|---|---|---|
| **Project Memory Hub** | `ios/EasePrototype0/Views/Space/ProjectMemoryView.swift` | View | Searchable project knowledge, claims, and verified relations. |
| **Memory Relationship Cards** | `ios/EasePrototype0/Views/Space/MemoryLinkCard.swift` | Component| Visual cards for CONFIRMS, CONTRADICTS, UPDATES, RESOLVES. |
| **Decision History & Evolution**| `ios/EasePrototype0/Views/Space/DecisionHistoryView.swift` | View | Timeline showing how earlier decisions were modified/updated. |
| **Cross-Discussion Q&A View** | `ios/EasePrototype0/Views/Space/MemorySearchSection.swift`| Subview | Semantic search with citation cards linking to source audio. |
| **Relationship Review Sheet** | `ios/EasePrototype0/Views/Space/ReviewRelationshipSheet.swift`| View | Human review for suggested contradictions or updates. |
| **Project Briefing View** | `ios/EasePrototype0/Views/Space/BriefingView.swift` | View | 60-90s context, key decisions, and unresolved issues. |
| **Speech Synthesizer Service** | `ios/EasePrototype0/Services/SpeechSynthesizerService.swift`| Service | AVSpeechSynthesizer audio playback with progress callback. |
| **Backend Vector & Memory Engine**| `backend/app/services/memory_engine.py`<br>`backend/app/api/v1/memory.py` | Service / API | Gemini 768-dim embeddings, relation judge, brief generator. |

---

## 5. Developer 4 — Tasks, Collaboration, Apple Ecosystem, and Settings

**Module Boundary**: Task dependencies and blocker graph, 4-role collaboration RBAC, iCloud shared folder sync, Apple Watch & Widget extensions, privacy vault, and settings.

| Screen / Component | File Path | Type | Ownership & Purpose |
|---|---|---|---|
| **Tasks & Dependencies Hub** | `ios/EasePrototype0/Views/Space/TasksDependenciesView.swift`| View | Blocker graph, collaborator dependency cards, nudges. |
| **Task Details Sheet** | `ios/EasePrototype0/Views/Space/TaskDetailSheet.swift` | View | Detailed task info, assignee, due date, blocker chain. |
| **Collaboration & Members Hub** | `ios/EasePrototype0/Views/Space/MembersView.swift` | View | Apple ID invites, 4 roles (Owner/Editor/Contributor/Viewer). |
| **iCloud Shared Folder Service**| `ios/EasePrototype0/Services/ICloudWorkspaceService.swift`| Service | Exports Markdown reports to `iCloud Drive ❯ EASE ❯ Reports`. |
| **Apple Ecosystem Status Hub** | `ios/EasePrototype0/Views/AppleEcosystem/AppleEcosystemView.swift`| View | iCloud Drive sync status, Apple Watch remote, Widget status. |
| **Apple Watch Remote Target** | `ios/EaseWatch/WatchContentView.swift` | Target | Standalone watchOS companion checking recording consent. |
| **Home Screen Widget Target** | `ios/EaseWidget/EaseWidget.swift` | Target | WidgetKit timeline with follow-ups & PlayBrief AppIntent. |
| **Settings & Privacy Hub** | `ios/EasePrototype0/Views/Settings/SettingsView.swift` | View | Account, Consent Records audit, Biometric vault purge. |
| **Apple Reminders Service** | `ios/EasePrototype0/Services/EventKitService.swift` | Service | EventKit integration to push tasks to Apple Reminders app. |
| **Backend RBAC & Tasks API** | `backend/app/api/v1/tasks.py`<br>`backend/app/core/security.py` | API / Core | 4 roles permissions, dependency tree, blocker notification. |
