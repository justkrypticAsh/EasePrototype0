# IMPLEMENTATION_PLAN.md — EASE Master Engineering Roadmap

**Project**: EASE (AI-Powered Project Memory Assistant)  
**Standard**: Full-stack Production Grade • Connected End-to-End Workflows • Native Glassmorphism  
**Date**: November 13, 2026

---

## Phase 1: Repository Audit & Architecture Plan (Completed)
- [x] Complete code inventory across backend, iOS, watchOS, and widget targets.
- [x] Generate `PROJECT_AUDIT.md`.
- [x] Generate `FEATURE_IMPLEMENTATION_MATRIX.md`.
- [x] Generate `SCREEN_OWNERSHIP.md`.
- [x] Generate `IMPLEMENTATION_PLAN.md`.

---

## Phase 2: Shared Design System, Models, Navigation & API Contracts
- [x] Establish Liquid Glassmorphism design tokens in `GlassComponents.swift` (`.glassCard()`, `GlassStatusPill`, `GlassActionButton`, glowing shadows).
- [ ] Enhance Core Models:
  - Add 4-Role RBAC hierarchy: `Owner`, `Editor`, `Contributor`, `Viewer` in `Project.swift` and backend `models/project.py`.
  - Add `TaskDependencyItem`, `ICloudReport`, `ICloudSyncInfo`, `ConsentRecordDetail`, `DecisionVersion`.
- [ ] Update `MainTabView.swift` to reflect the approved Level 1 6-tab Information Architecture:
  1. Home / Dashboard
  2. Project Space
  3. Capture Discussion (quick modal trigger)
  4. Planning (Calendar & Schedule)
  5. Apple Ecosystem (iCloud, Watch, Widgets)
  6. Settings & Data Management
- [ ] Provide unified demonstration dataset seeder ("Product Launch" project with Aarav, Riya, Kabir, Neha).

---

## Phase 3: Developer 1 Workstream — Home, Projects and Planning
- [ ] **Home Dashboard (`DashboardView.swift`)**:
  - Connect Active Projects vs Shared Projects carousel.
  - Implement My Tasks summary section (Pending, Done, Blocked).
  - Implement Upcoming Activities & Deadlines feed.
  - Connect Notifications Sheet trigger.
- [ ] **Planning Module (`PlanningView.swift` & `ScheduleDiscussionSheet.swift`)**:
  - Actual interactive calendar view (month/week grid with activity markers).
  - Schedule Discussion workflow (select project, select collaborators, set date/time, trigger reminder).
  - Apple Reminders & Calendar sync via EventKit.
- [ ] **Project Overview & Activity Timeline (`ProjectOverviewSection.swift`)**:
  - Project identity, domain badge, activity feed, recent discussions, recent decisions, open issues, task summary.

---

## Phase 4: Developer 2 Workstream — Capture and Discussion Intelligence
- [ ] **Connected Capture Flow (`CaptureFlowView.swift`)**:
  - Step 1: Select Project Space
  - Step 2: Select Discussion Participants
  - Step 3: Spoken Recording Announcement via `AVSpeechSynthesizer`
  - Step 4: Explicit Participant Affirmative Consent collection with timestamps
  - Step 5: Declined consent aborts recording with clear feedback
  - Step 6: Live Audio Recording with pulsing waveform and timer
  - Step 7: Automatic Audio Upload to backend
  - Step 8: Background AI Processing status with retry
  - Step 9: Structured Discussion Report generation
  - Step 10: Pre-approval review before transferring to Project Memory and Tasks
- [ ] **Discussion Library & Details (`DiscussionDetailView.swift`)**:
  - Timestamp-synchronized transcript playback.
  - Speaker Name editing ("Speaker 1" ➔ "Aarav Mehta").
  - Extracted Claims, Confirmed Decisions, Unresolved Issues, and Follow-ups with jump-to-audio buttons.

---

## Phase 5: Developer 3 Workstream — Project Memory and Briefings
- [ ] **Project Memory Knowledge Layer (`ProjectMemoryView.swift`)**:
  - Cross-discussion relationship cards: `CONFIRMS`, `CONTRADICTS`, `UPDATES`, `RESOLVES_PREREQUISITE`.
  - Human review sheet for suggested contradictions.
  - Decision History & Evolution timeline (`DecisionHistoryView.swift`).
  - Source verification: navigate from any memory item back to its source meeting and audio timestamp.
  - Natural Language Q&A search over project memory with strict citations.
- [ ] **Pre-Meeting Briefings (`BriefingView.swift`)**:
  - 60-90s spoken-style briefing script (Previous Context, Key Decisions, Unresolved Issues, Blocked Items).
  - Spoken audio briefing using `AVSpeechSynthesizerService`.

---

## Phase 6: Developer 4 Workstream — Tasks, Collaboration, Apple Ecosystem & Settings
- [ ] **Tasks & Blocker Engine (`TasksDependenciesView.swift`)**:
  - Visual Blocker Chain cards: "Waiting on [Person B] to finish [Task B]".
  - 1-tap Collaborator Nudge with haptic feedback.
  - Automatic unblocking when blocker prerequisite is marked "done".
  - Add Blocker dependency linking sheet.
- [ ] **4-Role Collaboration (`MembersView.swift`)**:
  - Support Owner, Editor, Contributor, Viewer roles.
  - Add collaborator via Apple ID (`user@icloud.com`).
  - Strict distinction: Discussion Participant vs Project Collaborator.
  - Role editing and member removal with backend authorization checks.
- [ ] **Apple Ecosystem Hub (`AppleEcosystemView.swift`)**:
  - iCloud Shared Workspace folder sync (`iCloud Drive ❯ EASE ❯ Reports`).
  - Native Apple Share Sheet (`UIActivityViewController` / `CKShare`).
  - Apple Watch Remote pairing & live status.
  - Home Screen Widget configuration guide.
- [ ] **Settings & Data Management (`SettingsView.swift`)**:
  - Account & Apple ID profile.
  - Privacy & Consent records audit viewer.
  - Biometric Voice Vault purge.
  - Data export (Markdown reports + JSON archive).
  - Data deletion with confirmation.

---

## Phase 7: Cross-Module Integration & End-to-End User Flows
- [ ] Verify and connect all 10 End-to-End flows:
  - Flow 1: First Project (Home ➔ Create Project ➔ Overview ➔ Invite ➔ Space)
  - Flow 2: Capture Discussion (Overview ➔ Capture ➔ Consent ➔ Record ➔ Upload ➔ AI Report)
  - Flow 3: Discussion to Memory (Report ➔ Review Claims/Decisions ➔ Memory ➔ Decision Details)
  - Flow 4: Discussion to Task (Report ➔ Follow-up Action ➔ Task ➔ Assign ➔ Mark Complete)
  - Flow 5: Dependency Management (Task ➔ Add Prerequisite ➔ Blocked ➔ Complete ➔ Unblocked)
  - Flow 6: Cross-Discussion Intelligence (New Discussion ➔ Memory Link ➔ Suggest Relation ➔ Verify)
  - Flow 7: Pre-Meeting Briefing (Briefings ➔ Context ➔ Key Decisions ➔ Audio Briefing)
  - Flow 8: Collaboration (People ➔ Invite Apple ID ➔ Role ➔ Access Permissions)
  - Flow 9: Planning (Calendar ➔ Schedule Discussion ➔ Project & Collaborators ➔ Reminders)
  - Flow 10: Privacy and Data (Settings ➔ Consent Records / Biometric Vault ➔ Export or Delete)

---

## Phase 8: QA, Testing, UI Polish & Final Documentation
- [ ] Run full backend test suite (`pytest backend/tests/ -v`).
- [ ] Verify clean compilation of iOS target (`xcodebuild build`).
- [ ] Verify clean compilation of watchOS target (`EaseWatch`).
- [ ] Verify clean compilation of Widget target (`EaseWidget`).
- [ ] Commit all milestones and push to GitHub repository.

