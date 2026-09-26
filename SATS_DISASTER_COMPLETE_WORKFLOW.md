# SATS Disaster — Complete Project Documentation

> **Smart Assistance and Tracking System — Disaster Management Platform**
> Problem Statement: **SIH26206** · Theme: **Disaster Management**
> Status legend used in this document: ✅ IMPLEMENTED · 🟡 PARTIALLY IMPLEMENTED · 🔎 MANUAL VERIFICATION REQUIRED · 🔮 FUTURE SCOPE
>
> This document describes **only the current codebase** (verified by inspection + `flutter analyze` + `flutter test`).

---

## 1. 🌐 Project Overview

| Item | Detail |
|---|---|
| **Project** | SATS Disaster (internal package: `village_verse`) |
| **Full name** | Smart Assistance and Tracking System — Disaster Management Platform |
| **Problem Statement** | SIH26206 |
| **Theme** | Disaster Management |
| **One line** | A Flutter + Firebase platform connecting **citizens and authorities** across the full disaster lifecycle — preparedness → alert → response → recovery. |
| **Target users** | Citizens (villagers), Village Authority, District Authority, Rescue Team, Admin (legacy) |
| **Geographic focus** | **Andhra Pradesh, India** — district → mandal → village hierarchy (bundled AP geography + hospital/blood-bank datasets) |

**Telugu explanation:**

> SATS Disaster అనేది disaster వచ్చినప్పుడు మాత్రమే పనిచేసే app కాదు. Disaster **కి ముందు** village preparedness నుంచి, disaster **సమయంలో** alerts, shelters, incident reporting, SOS వరకు, disaster **తర్వాత** damage assessment మరియు recovery వరకు — citizen మరియు authority ఇద్దరినీ ఒకే platform లో connect చేసే disaster-management system.

---

## 2. 🤔 Why SATS Disaster Exists

Disaster సమయంలో information అనేదే అత్యంత ముఖ్యమైన "resource". కానీ ప్రస్తుతం ఇది చాలా చోట్ల విడివడి (scattered) ఉంటుంది:

- Citizens కి తమ village కి సంబంధించిన warning తెలియకపోవచ్చు — general news తెలుస్తుంది కానీ "మా ఊరికి వస్తుందా?" అనే సందేహం ఉంటుంది.
- Authority దగ్గర warnings broadcast చేసే direct channel లేకపోవచ్చు.
- Citizen కి evacuate అవ్వాలంటే **ఏ shelter లో ఖాళీ ఉంది, ఎలా వెళ్ళాలి** అనే information కావాలి.
- Citizen incident (వ్యక్తి చిక్కుకుంది, నీరు పెరిగింది) ని **location + photo evidence** తో report చేయాలి.
- Authority వచ్చే reports ని **triage** చేసి, track చేసి, resolve చేస్తున్నట్టు citizen కి కనిపించాలి.
- Disaster తర్వాత damage ఎంత జరిగిందో, relief ఎక్కడ దాకా చేరిందో record కావాలి.
- ఎవరైనా missing అయితే coordinate చేసే system కావాలి.

### Current Problem → SATS Disaster Solution

| # | Current Problem | SATS Disaster Solution (implemented) |
|---|---|---|
| 1 | Local warnings reach citizens late or never | Authority creates alert → **village/mandal/district-targeted in-app notification** fan-out |
| 2 | No single place for shelter info | Shelters module with **capacity, status, address, Google Maps directions** |
| 3 | Incident reporting via phone calls/word of mouth | **Report Incident** form with GPS, photo evidence, rescue/medical needs |
| 4 | No tracking of report status | **Realtime triage workflow** (Reported → … → Resolved) visible to the reporter |
| 5 | Post-disaster damage untracked | **Damage Assessment** records with status flow |
| 6 | Relief distribution untracked | **Relief Resources** with required/available/allocated quantities |
| 7 | Personal emergency response depends on luck | **SOS**: guardians get SMS + call + live location (original SATS foundation, disaster-aware) |
| 8 | Missing-person coordination ad-hoc | **Missing Person Alerts** with disaster linkage and "Found Safe" resolution |

---

## 3. 🧭 Core Concept — Before / During / After

```
        BEFORE DISASTER              DURING DISASTER              AFTER DISASTER
   ┌──────────────────────┐    ┌──────────────────────────┐   ┌─────────────────────────┐
   │ Village preparedness │    │ Disaster alert (targeted)│   │ Damage assessment       │
   │ Evacuation routes    │ →  │ Evacuation info          │ → │ Relief resources        │
   │ Emergency contacts   │    │ Shelters + directions    │   │ Village recovery status │
   │ Blood banks/hospitals│    │ Incident reporting + SOS │   │ Disaster closed         │
   └──────────────────────┘    └──────────────────────────┘   └─────────────────────────┘
```

| Stage | SATS Disaster Features (implemented) |
|---|---|
| **Before** | Village Preparedness (risk level, hazards, checklist, evacuation routes, contacts) · Public Hospitals directory · Blood Bank directory + donor search · National helplines |
| **During** | Disaster events with lifecycle · Geo-targeted alerts + in-app notifications · Evacuation screen · Shelters (capacity/status/directions) · Incident reporting with GPS + photo · Realtime triage · SOS (SMS + call + live location + stealth power-button) · Missing Person Alerts |
| **After** | Damage Assessment workflow · Relief Resource tracking · Recovery status derivation (Response → Recovery → Restored) · Alert close (history preserved) |

---

## 4. 👥 User Roles (from `lib/utils/roles.dart` + Firestore rules)

| Role | Purpose | Main access | Key permissions |
|---|---|---|---|
| **Citizen** | Disaster information స్వీకరించడం, help పొందడం | Home · Report · SOS · Get Help tabs | Receive targeted alerts, view shelters/preparedness/hospitals/blood banks, report incidents, create missing-person alerts, trigger SOS, community posts |
| **Village Authority** (`village_authority`) | తమ village operations manage చేయడం | Command · Incidents · Shelters · Alerts tabs | Create/edit/close disasters, shelter CRUD, preparedness publish, damage/resources management, incident triage |
| **District Authority** (`district_authority`) | మొత్తం situation ని wide scope లో చూడటం, wide alerts | Same command center, district-wide data | Same as village authority + mandal/district-scope alerts and feeds |
| **Rescue Team** (`rescue`) | Assigned incidents పై పనిచేయడం | Incident feeds + triage updates | Read incidents, update triage fields (rules), manage damage/resources |
| **Admin** (`admin`, legacy) | Original SATS admin — full authority equivalence | Same as district authority | Treated as district-level authority (kept for backward compatibility; do not assign to new accounts) |

**Telugu:**

> **Citizen**: disaster information receive చేస్తాడు, incidents report చేస్తాడు, shelters చూస్తాడు, SOS use చేస్తాడు.
> **Authority**: disaster events, alerts, shelters, incidents, damage, resources వంటి operational information manage చేస్తుంది.

> 🔒 Security note: sign-up చేసిన ప్రతి కొత్త user **ఎప్పుడూ citizen మాత్రమే** (Firestore rule enforces `role == "citizen"`). Authority roles **out-of-band** (Firebase console / Admin SDK seed) ద్వారా మాత్రమే వస్తాయి, మరియు `role` field తర్వాత మార్చలేం (immutable).

---

## 5. 🧑‍🌾 Citizen Complete Workflow (implemented)

```
Citizen Login
   ↓
Profile / Location (village, mandal, district)
   ↓
Citizen Home  ── "Is there danger near me?"
   ↓
Active Disaster (safety hero / All Clear)
   ↓
Alert notification → Alert Detail (instructions, severity, status)
   ↓
Evacuation (if evacuationRequired)
   ↓
Shelters (capacity + status) → Get Directions → Google Maps
   ↓
Report Incident (type, severity, GPS, photo, needs)
   ↓
Authority Triage (realtime status back to citizen)
   ↓
Recovery / Relief status for the village
```

### 5.1 Citizen Login → Profile / Location
- **What citizen does**: phone/Google sign-in, completes profile with **village, mandal, district**.
- **What system does**: stores profile in `users/{uid}`; every screen uses this geographic identity for targeting. Role is always `citizen` at signup (rules).
- **Why it matters**: village-level targeting అంతా ఈ profile fields మీదే ఆధారపడి ఉంటుంది. Profile లేకుంటే targeted alerts రావు.

### 5.2 Citizen Home — Safety Status Hero
- **What citizen does**: app open చేయగానే తన area status చూస్తాడు.
- **What system does**: realtime stream of the **primary active disaster** for their area (`DisasterService.getPrimaryDisasterForAreaStream`, deterministic ranking: village > mandal > district scope, then severity, then newest). No disaster → calm **"All Clear"** card with preparedness shortcut.
- **Why it matters**: citizen కి 3 సెకన్లలో మూడు సమాధానాలు — *ప్రమాదం ఉందా? నేనేం చేయాలి? ఎక్కడ help దొరుకుతుంది?*

### 5.3 Alert → Alert Detail
- **What citizen does**: notification నొక్కగానే exact alert detail తెరుచుకుంటాడు (deep link via `relatedDocumentId`).
- **What system does**: shows type, severity badge, lifecycle status, instructions, affected areas, evacuation emphasis, demo-data tag when seeded.
- **Why it matters**: general news కాకుండా **official, area-specific** instruction.

### 5.4 Evacuation → Shelters → Directions → Incident → Recovery
- Detailed flows in sections 8–10 and 17 below.

---

## 6. 🚨 Disaster Alert Workflow (implemented exactly as coded)

```
Authority
   ↓
Create Disaster Event  (disasters collection)
   ↓
Affected Geography (villages / mandals / districts lists)
   ↓
Create Alert (severity, instructions, evacuationRequired)
   ↓
DisasterAlertNotificationService  →  Geographic Targeting
   ↓
In-App Notification Documents (deterministic IDs)
   ↓
Citizen Notification Screen  →  deep link
   ↓
Alert Detail Screen  →  Evacuation if required
```

**Verified implementation facts:**

| Aspect | Current behavior |
|---|---|
| **Disaster types** | `flood, cyclone, fire, earthquake, landslide, infrastructure_collapse, other` |
| **Severity** | `low, medium, high, critical` |
| **Lifecycle** | `monitoring → active → contained → closed` (events are **never deleted**; close sets `status='closed'` + `endedAt`) |
| **Instructions** | Free-text actionable guidance shown on the alert detail screen |
| **Evacuation flag** | `evacuationRequired` boolean drives the Evacuation screen + alert body text |
| **Geographic targeting** | `DisasterAlertTargeting.matchScope`: village-list match (scope `village`) → mandal-list (`mandal`) → district-list (`district`); most specific wins; blank user fields never match |
| **Notification creation** | One `disaster_alert` document per affected user in the existing `notifications` collection (single batch, max 500 ops); body auto-generated from type/severity/area/evacuation flag |
| **Duplicate protection** | Deterministic doc ID `disaster_{disasterId}_{userId}` — re-running fan-out **overwrites** the same doc, never duplicates |
| **Deep linking** | `relatedDocumentId` = disaster doc ID → Notifications screen opens `DisasterAlertDetailScreen` for that exact alert |
| **Edit behavior** | `updateDisasterEvent` **does NOT re-fan-out notifications** — citizens never get duplicate alerts when an authority edits wording/status. Fan-out happens **only on creation**. |
| **Close behavior** | `closeDisasterEvent` returns `false` if already closed (no second write, no duplicate `endedAt`) |
| **FCM** | ❌ Disaster alerts use **in-app Firestore notifications only** — no FCM push for disaster alerts |

**Telugu:**

> Authority disaster create చేసినప్పుడు, assigned geography (villages/mandals/districts) ఆధారంగా affected citizens కి alert notifications పంపబడతాయి. Alert ని edit చేసినప్పుడు duplicate notification పంపబడదు — ఇది deliberate design. Disaster close చేస్తే history preserved అవుతుంది, delete అవ్వదు.

---

## 7. 📍 Geographic Targeting (GeoMatch) — the core concept

**The hierarchy:**

```
District  (widest)
   └── Mandal
         └── Village   (most specific)
```

**Normalization (`GeoMatch.normalize`)** — applied to *both* stored and comparison values:

1. lowercase → 2. trim → 3. **remove ALL internal whitespace**
   `" MUKKA MALA "` → `"mukkamala"` · `"East Godavari"` → `"eastgodavari"`

**Two matching modes (both implemented, deliberately different):**

| Mode | Where used | Rule |
|---|---|---|
| **Strict 3-level (AND)** — `GeoMatch.matches3Level` | Shelters, incidents, damage, resources, missing-person scope | item visible **only if village AND mandal AND district all match**. Blank fields never match. |
| **Affected-scope (OR)** — `GeoMatch.affectsStrict` | Disaster events (alerts) | alert matches if **village OR mandal OR district** appears in the disaster's affected lists — because a disaster covering a mandal legitimately affects every village in it. |

**How each feature uses it (verified):**

| Feature | Targeting behavior |
|---|---|
| Disaster alerts | Authority picks affected villages/mandals/districts → citizen matched with OR-semantics → notification scope recorded (`village`/`mandal`/`district`) |
| Primary disaster pick | Deterministic: village-scope first, then severity, then newest |
| Shelters | Firestore query `village == normalize(user.village)` (falls back to mandal query when profile village empty) → **then** strict 3-level client filter |
| Incidents | Stored normalized; authority feeds stream by village/mandal/district; reporter stream by `reportedBy` |
| Incident → authority notification | Authority users of the area matched client-side on normalized fields |

> ⚠️ **Documented limitations (kept honest, not hidden):**
> 1. **Shelter visibility is strict 3-level**: a shelter in the *same mandal but a different village* is **not** shown to a citizen whose village is set. This is intended (disaster targeting), but it means neighboring-village shelters stay invisible unless the profile village field is empty (then mandal-level stream is used).
> 2. **Normalization is whitespace/case-only** — punctuation variants (e.g. `"St. Paul's Nagar"` vs `"St Pauls Nagar"`) or spelling variants will **not** match. Data entry must be consistent.
> 3. **Legacy users-document field mapping**: on `users` docs the mandal value is stored in the `village` field and the village value in `street` (see `UserFieldKeys`). Dart-side `UserModel` maps these correctly, but raw console reads can be confusing.
> 4. Authority lookup for notifications reads **all** authority users then filters client-side (avoids a composite index; fine at demo scale, not optimized for very large scale).

**Telugu:**

> GeoMatch అంటే simple: రెండు వైపులా place names ని normalize చేసి (lowercase, trim, spaces remove), తర్వాత పోల్చడం. Shelters/incidents వంటి disaster items కి **strict** matching (village+mandal+district మూడూ సరిపోవాలి). Disaster alerts కి **scope** matching (village లేదా mandal లేదా district — ఎక్కువ specific scope ముందు). Hospitals కి మాత్రం GeoMatch అస్సలు apply చేయబడదు — అది directory కాబట్టి (section 18 చూడండి).

---

## 8. 🏃 Evacuation Workflow (implemented)

```
Alert (evacuationRequired = true)
   ↓
Citizen opens Evacuation screen
   ↓
Evacuation status card (from active disaster)
   ↓
Evacuation Routes (from village preparedness)
   ↓
"View Nearest Shelters" button → Shelters screen
   ↓
Emergency Contacts (village contacts or fallback 112)
```

**Verified behavior:**

| Element | Implementation |
|---|---|
| Evacuation status | Realtime from primary disaster: **"Evacuation required"** (danger styling) or **"No evacuation ordered"** (safe styling); shows affected villages + instructions |
| No active disaster | Honest empty state: "There is no active disaster for {village}. Review your routes below…" |
| Routes | Text route descriptions from `preparedness.evacuationRoutes` — **not** map-optimized routes. Empty state: "No evacuation routes published for {village} yet. Contact your village office." |
| Shelters shortcut | Button navigates to Shelters screen |
| Contacts | From `preparedness.emergencyContacts`; empty state advises **call 112** |

> 🔎 **Explicitly NOT implemented**: turn-by-turn evacuation route optimization, route planning through maps, or dynamic route recalculation. Routes are **published text descriptions**. (Future scope.)

**Telugu:**

> Evacuation screen citizen కి మూడు విషయాలు చూపిస్తుంది: (1) evacuation అవసరమా లేదా, (2) village office publish చేసిన routes, (3) దగ్గరి shelters కి direct button. Routes లేకపోతే app అబద్ధం చెప్పదు — "routes ఇంకా publish అవ్వలేదు" అని చెప్పి village office ని contact అవ్వమంటుంది.

---

## 9. 🏠 Shelter Workflow (implemented)

### Authority side

```
Authority → Shelters tab
   ↓
Create Shelter (name, village, mandal, district)
   ↓
Add location  →  locationText (address) + "Use Current Location" (GPS)
   ↓  → latitude, longitude stored
Set capacity, occupancy, status, amenities, supplies, contact phone
   ↓
Publish (create)  ·  Edit (update)  ·  Delete (remove)
```

- Full **CRUD** for authorities (Firestore rules: create/update/delete = authority-only; update restricted to shelter fields only).
- `ShelterModel` fields: name, district, mandal, village, **locationText**, **latitude**, **longitude**, capacity, occupancy, status (`active`/`closed`), amenities, supplies, contactPhone, demo flag.
- Occupancy updates drive availability (`capacity − occupancy`); ≥80% shows *Limited*, full shows *FULL*, closed shows *CLOSED*.

### Citizen side

```
View shelters (strict 3-level matching — section 7)
   ↓
Shelter card: name · address · village • mandal · status chip · capacity bar · facilities chips
   ↓
Open Shelter Details
   ↓
Get Directions → MapsDirections helper → Google Maps (deep link, no API key)
```

**Directions & fallback (verified):**

| Case | Behavior |
|---|---|
| Coordinates present | `https://www.google.com/maps/dir/?api=1&destination={lat},{lng}` via the shared `MapsDirections` helper (`LaunchMode.externalApplication` — Maps app, else browser) |
| Coordinates missing | Button disabled + calm text: *"Directions aren't available for this shelter yet. Use the address shown above."* |
| Launch fails (no Maps/browser) | SnackBar: *"Could not open Google Maps. Please try again or use the shelter address."* |

**Telugu — ఎందుకు ఉపయోగం:**

> Evacuation సమయంలో citizen కి అత్యవసరమైన ప్రశ్న: "నేను ఎక్కడికి వెళ్ళాలి? అక్కడ చోటు ఉందా?" Shelters screen ఈ రెండింటికీ సమాధానం ఇస్తుంది — status chip (OPEN/LIMITED/FULL/CLOSED) వెంటనే చెబుతుంది, capacity bar ఎంత నిండిందో చూపిస్తుంది, Get Directions ఒక tap లో Google Maps navigation తీసుకెళ్తుంది.

---

## 10. 📝 Incident Reporting Workflow (implemented)

```
Citizen → Report tab
   ↓
Select Incident Type
   ↓
Select Severity
   ↓
Description
   ↓
GPS Location (auto "Use Current Location")
   ↓
Photo / Evidence (uploaded to Cloudinary)
   ↓
People Affected (count)
   ↓
Rescue / Medical Needs + resources required
   ↓
Submit → IncidentService → incidents collection
   ↓
Authority notified (in-app) → Authority Incident Feed
   ↓
Triage (section 11) → Citizen sees realtime status in "My Incidents"
```

**Actual vocabularies from `DisasterIncidentModel`:**

| Field | Values |
|---|---|
| **Incident types (10)** | flood, cyclone, fire, earthquake, landslide, infrastructure_collapse, **person_trapped**, **medical**, missing_person, other |
| **Severity (4)** | low, medium, high, critical |
| **Resource requirements** | boats, food, drinking_water, medical_team, tarpaulins, rescue_team, generator, transport |
| **Flags** | affectedPeople count, rescueRequired + rescuePeopleCount, medicalRequired |
| **Location** | GPS lat/lng (optional) + village/mandal/district from profile (stored normalized — report is routeable even without GPS) |
| **Evidence** | photo(s) uploaded to Cloudinary, URLs in `media` |
| **Disaster link** | `disasterId` set automatically when reported during an active disaster |

**Draft persistence (low network):** the form **autosaves a draft** (`IncidentDraftService` via SharedPreferences) — typed data survives app kills/connectivity drops and can be restored. *(Draft only — actual submission needs connectivity; the app does not claim offline submission.)*

**Telugu:**

> Citizen form లో type, severity select చేసి, ఏం జరిగిందో రాసి, GPS location పట్టి, photo తీసి attach చేసి, ఎంతమంది affected అయ్యారో, rescue/medical కావాలా అని చెప్పి submit చేస్తాడు. Network లేకపోయినా draft save అవుతుంది — తర్వాత open చేస్తే restore అవుతుంది. Submit అయ్యాక authority కి in-app notification వెళ్తుంది.

---

## 11. ⚖️ Incident Triage Workflow (implemented)

```
Reported → Verified → Triaged → Dispatched → Resolved
                                    (Rejected/"Mark Invalid" exits the flow at any point)
```

**Verified behavior:**

| Aspect | Implementation |
|---|---|
| Realtime feed | Authority Incident Feed streams by village/mandal/district; severity-sorted (critical first) |
| Severity filter | Feed supports severity filtering |
| Detail | Full incident detail: description, GPS (Google Maps link), photo evidence, affected count, rescue/medical needs, required resources, reporter |
| Status updates | One **single forward step** per action (`nextTriageStatus`) — authorities cannot invent a status; "Mark Invalid" is a separate action (`rejected`) |
| Rules | Update allowed only to `status/assignedTo/updatedBy/updatedAt`, authority/rescue only. **Reporter cannot edit after submit** (audit trail preserved). Delete: not allowed. |
| Citizen visibility | "My Incidents" realtime stream — citizen watches their report move through the workflow |
| Assignment | `assignedTo` field records the responsible team/user |

> ⚠️ **Explicitly stated**: **"Dispatched" is a workflow state only.** There is **no external rescue-dispatch integration** (no 108/Government CAD system connection, no team GPS dispatch). The authority records that response was dispatched; actual dispatch is manual/offline.

**Telugu:**

> Report వచ్చిన వెంటనే authority feed లో కనిపిస్తుంది (critical ముందు). Authority ఒక్కో step ముందుకు మార్చగలదు: Reported → Verified → Triaged → Dispatched → Resolved. Citizen తన report status ని realtime లో చూస్తూ ఉంటాడు — "నా report ఎవరైనా చూశారా?" అనే uncertainty పోతుంది. ఇది internal workflow మాత్రమే; బయటి rescue system integration లేదు.

---

## 12. 🆘 SOS Workflow (implemented — original SATS foundation + disaster additions)

### Original SATS SOS foundation (reused, verified in code)

| Capability | Implementation |
|---|---|
| **SOS trigger** | Big red button with **2-second hold-to-confirm** (`EmergencySosButton` — progress ring, haptic ticks; release early cancels) |
| **Guardian check** | Requires at least one guardian configured, else fails with clear message |
| **Live location** | GPS fix → Google Maps link; location tracked **every 5 seconds** and written to the emergency document while active |
| **Emergency session** | `emergencies` doc: user info, location, `status: active`, guardian count, trigger mode |
| **SMS to all guardians** | Native Android SMS (`SMSService` MethodChannel) with name, phone and live-location link |
| **Automatic guardian call** | Calls the first guardian and plays a **recorded emergency voice message** during the call (native `CallService`), monitors call state, stops playback when call ends |
| **In-app notifications** | Guardian app users (matched by normalized phone) get an `sos` notification document |
| **Realtime deactivation** | Firestore **transaction claim** (`status != active` or `endedSmsSent` → no-op) — double-deactivation never sends a second "ended" SMS; guardians receive "emergency ended" SMS |
| **Restore on restart** | `restoreActiveEmergency()` re-attaches location tracking for an active emergency after app restart |
| **Emergency history** | Past emergencies viewable (Emergency History screen) |

### Disaster-aware SOS additions

| Addition | Implementation |
|---|---|
| **Disaster context attached** | Emergency doc gets `disasterId` + `disasterContext` (e.g. "Cyclone (HIGH)") of the citizen's area primary disaster, when one exists. SOS still works normally with no disaster. |
| **Village/mandal/district fields** | Stored on the emergency for area-based response |
| **Stealth SOS** 🔎 | **Native Android** power-button watcher (`PowerButtonSosService.kt` + `StealthSosManager.kt` + `BootReceiver.kt`) — triggers SOS after repeated power presses, works when screen locked / app killed / after reboot. Trigger mode recorded as `stealth_power_button`. |

**Notification channels used for SOS (verified):** in-app Firestore notifications ✅ · SMS (native) ✅ · Phone call + voice playback (native) ✅ · **FCM push via Cloud Function** (`functions/src/emergencySosAlert.ts` on `emergencies` create → high-priority FCM to guardian tokens) — 🟡 present in repo, delivery depends on the function being deployed + guardian FCM tokens registered (native side).

**Telugu:**

> SOS అనేది personal emergency system: 2 సెకన్లు hold చేయగానే — guardians అందరికీ SMS (live location link తో), మొదటి guardian కి auto call లో emergency voice message, in-app notification, మరియు 5 సెకన్లకి ఒకసారి location update. Disaster జరుగుతుంటే ఆ emergency record కి ఆ disaster context attach అవుతుంది. Phone screen lock అయినా, app close అయినా power button stealth SOS పనిచేస్తుంది (native Android service). Safe అయ్యాక deactivate చేస్తే guardians కి "ended" SMS వెళ్తుంది — duplicate రాదు (transaction తో guarantee).

---

## 13. 🔍 Missing Person Workflow (implemented)

```
Citizen → Create Missing Person Alert
   ↓
Details: photo, full name, age, gender, last-seen location & time,
         clothes description, notes, guardian contact, WhatsApp number
   ↓
Stored in missing_person_alerts (with reporter's village/mandal/district)
   ↓
   ├── disasterId link (optional) — when missing during an active disaster
   ↓
Public visibility (all authenticated users read) + in-app missing_person notifications
   ↓
Anyone can mark → "Found Safe" (status + foundAt restricted fields)
```

**Verified facts:** creation by any authenticated user · rules allow **any** user to mark found-safe but **only** on the fields `status, foundAt, updatedAt` · creator can edit/delete their own alert · `disasterId` linkage is optional and backward compatible (Phase 5 addition) · contact actions (call / WhatsApp) available from the alert.

**Telugu:**

> Disaster సమయంలో ఎవరైనా కనపడకపోతే citizen photo తో alert పెడతాడు. అది అందరికీ కనిపిస్తుంది; ఎవరైనా ఆ వ్యక్తిని చూస్తే "Found Safe" అని mark చేయగలరు. ఆ alert ఆ disaster సమయంలో జరిగితే ఆ disaster కి link అవుతుంది — తర్వాత analysis కి ఉపయోగం.

---

## 14. 🛡️ Preparedness Workflow (BEFORE disaster — implemented)

```
Authority
   ↓
Village Preparedness record (publish / update — upsert by village key)
   ↓
preparedness/{villageKey}          (villageKey = lowercase village name)
   ↓
Citizen sees it in Help (village contacts) and Evacuation screen (routes)
```

**Actual fields in `VillagePreparednessModel`:**

| Field | Content |
|---|---|
| `riskLevel` | low / moderate / high / severe |
| `hazards` | e.g. `['cyclone', 'flood']` |
| `checklist` | preparedness items with done flags (`{label, done}`) → progress fraction |
| `vulnerableCount` | elderly / disabled / infants / pregnant residents count |
| `sheltersCount` | designated shelters serving the village |
| `evacuationRoutes` | text descriptions of evacuation routes |
| `emergencyContacts` | `[{name, phone}]` — tappable call rows in Help |

**Empty states (verified):** no record / no contacts → *"Your village hasn't published emergency contacts yet. In an emergency, call 112."* · no routes → *"No evacuation routes published … Contact your village office."*

**Telugu:**

> Preparedness అంటే disaster రాకముందే village ready గా ఉండటం. Authority risk level, hazards, checklist (siren test లాంటివి), evacuation routes, emergency contacts publish చేస్తారు. Citizen కి ముందుగానే తన village plan తెలుస్తుంది. Publish చేయకపోతే app ఖాళీ గా ఉండదు — 112 కి call చేయమని చెబుతుంది.

---

## 15. 📊 Damage Assessment Workflow (implemented)

```
Authority / Rescue  (post-disaster field survey)
   ↓
Create Damage Assessment
   (damageType, severity, description, village/mandal/district,
    GPS optional, affected people estimate, photo via Cloudinary,
    disasterId link)
   ↓
Status flow: Reported → Verified → Assessed → Recovered
   ↓
Citizen sees village recovery progress (read-only)
```

**Verified facts:**

| Aspect | Implementation |
|---|---|
| **Who creates** | Authority or rescue only (rules: `reportedBy == caller` enforced) |
| **Who sees** | All authenticated users read (public recovery progress) |
| **Damage types (9)** | house, road, bridge, electricity, water, communication, public_building, agriculture, other |
| **Severity** | low / medium / high / critical |
| **Data** | estimatedAffectedPeople, photoUrl, notes/description, lat/lng + Google Maps location link |
| **Status transitions** | One forward step per action (`nextStatus`); delete not allowed (audit trail) |
| **Disaster linkage** | `disasterId` optional field |

> ⚠️ **Explicitly NOT implemented**: AI image damage detection. Photos are **evidence only** — severity/damageType are manually recorded by the authority. The status is the **recorded administrative state**, not a claim that physical repair is complete.

**Telugu:**

> Disaster తర్వాత authority field లో survey చేసి — ఏ ఇంటికి, ఏ road కి damage అయిందో, ఎంత severity కి అని record చేస్తారు, photo evidence తో. Status ని step by step ముందుకు మార్చి చివరికి "Recovered" అని mark చేస్తారు. Citizen తన village recovery ఎంత దూరం అయిందో చూడగలడు.

---

## 16. 📦 Relief / Resource Workflow (implemented)

```
Resource Needed (requiredQuantity)
   ↓
Available (quantity on the ground)
   ↓
Allocated (allocatedQuantity — dispatched by authority)
   ↓
Exhausted / shortfall resolved
```

**Verified facts:**

| Aspect | Implementation |
|---|---|
| **Document model** | One doc per **(disaster, village, resourceType)** in `resources` |
| **Quantities** | `requiredQuantity`, `quantity` (available), `allocatedQuantity` + `unit` (litres/packets/units) |
| **Derived figures** | `shortfall` (required − available), `coverage` (0–100%), `isCovered`, `isExhausted` |
| **Statuses** | needed → available → allocated → exhausted |
| **Validation** | `ResourceModel.validate`: no negatives; **allocated ≤ available**; **allocated ≤ required**; type & village mandatory |
| **Resource types** | drinking_water, food_packets, medicines, blankets, emergency_kits, boats, generators, rescue_equipment, tarpaulins, cooked_food (+ extensible free strings) |
| **Context** | village/mandal/district + optional `disasterId` |
| **Access** | read: everyone · write: authority/rescue · delete: never |

**Telugu — ఎలా ఉపయోగపడుతుంది:**

> Post-disaster లో "ఏ village కి ఎంత నీళ్ళు/food/medicines కావాలి, ఎంత ఉంది, ఎంత dispatch అయ్యింది" అనేది కనిపించకపోతే relief ఒకే చోట పేరుకుపోతుంది, కొన్ని villages miss అవుతాయి. Resource model వల్ల shortfall (ఎంత సరిపోదు) కనిపిస్తుంది — authority దాన్ని prioritize చేయగలరు. Citizen కూడా "మా ఊళ్ళో relief వచ్చిందా" అని చూడగలడు.

---

## 17. 🛠️ Recovery Workflow (implemented)

```
Damage records  +  Resource records  +  Incidents  +  Shelters
                        ↓
        RecoveryStatusHelper.deriveForVillage  (pure computation)
                        ↓
   Response Ongoing → In Recovery → Restored
   (display meter: 0.35 → 0.70 → 1.00)
```

**Actual derivation logic (verified in `recovery_status_helper.dart`):**

| Condition (checked in order) | Derived status |
|---|---|
| Any **open incidents** exist | `response` — "Response Ongoing" |
| No damage & no resources recorded | `response` if any shelter still holds occupants, else `restored` |
| All damage recovered AND no resource shortages | `restored` |
| Otherwise (incidents handled but damage/relief remains) | `recovery` — "In Recovery" |

- For a **closed disaster**: all damage recovered → `restored`, else `recovery`.
- No separate state machine — status is **computed from stored data each time**, so it can never drift from reality.
- **Screens**: citizen **Village Recovery** (Help → Village Recovery) shows water/relief/shelter availability and derived status; authority dashboard uses the same derivation for disaster-level overview (`deriveForDisaster`).

**Telugu:**

> Recovery status అనేది ఎవరైనా manually set చేసేది కాదు — stored data నుంచి **calculate** అవుతుంది: incidents అన్నీ resolve అయ్యాయా? damage అంతా recovered ఆ? resources లో shortfall లేదా? ఈ logic వల్ల status ఎప్పుడూ real data తో సరిపోతూ ఉంటుంది.

---

## 18. 🏥 Hospitals / Public Assistance (implemented)

### Public Hospitals — ✅ IMPLEMENTED (migrated from original SATS, restyled)

```
Citizen → Get Help (Help / Assistance)
   ↓
Public Hospitals
   ↓
Browse / Search (name · district · address — also raw dataset names)
   ↓
District filter chips (All districts → 16 AP districts)
   ↓
Hospital card: 🏥 name · address • district · distance (if GPS)
   ↓
Hospital Details
   ↓
📞 Call Hospital (tel: dialer)      🧭 Get Directions (Google Maps)
```

| Aspect | Implementation |
|---|---|
| **Data source** | **Bundled local JSON assets** — `assets/data/hospitals/*.json` (16 district files: anantapuramu … ysr_kadapa), loaded & cached by `HospitalService`. **No Firebase reads** in the citizen flow. (A read-only Firestore `hospitals` collection + upload scripts also exist from the original SATS, but the current UI uses the assets.) |
| **Search** | Case-insensitive across hospital name (display **and** raw dataset name — legacy village-style names like "Owk" remain findable), district (slug + display form), and address |
| **District filter** | Chips built from what the dataset actually contains; single-select + "All districts" |
| **Call** | `tel:` launch (same mechanism as Help helplines); hidden/disabled when no phone; failures show a human-readable message |
| **Directions** | Shared `MapsDirections` helper (same one shelters use — **no second implementation, no API key**); button only appears with valid coordinates; disabled + explanatory text otherwise |
| **GeoMatch** | ❌ **Deliberately NOT applied** — hospitals are a directory, may legitimately be outside the user's village. Useful narrowing = search + district filter (+ nearest-first sort when GPS available) |
| **Legacy data handling** | `nan` addresses shown as "Address not available"; generic/village-style names get display fallbacks; malformed records skipped without breaking the district load |
| **Honesty** | No live hospital availability/bed data — the app never claims a hospital is "accepting disaster patients" |

**Telugu:**

> Original SATS లో ఉన్న Public Hospitals directory ని SATS Disaster లోకి తీసుకొచ్చాం — కొత్త premium design తో. Citizen Help screen నుంచి hospitals open చేసి, name/district తో search చేసి, hospital details చూసి, call చేయవచ్చు, Google Maps directions తీసుకోవచ్చు. ఇది disaster targeting కాదు — పూర్తి directory అందరికీ అందుబాటులో ఉంటుంది. Data అంతా app లోపలే (offline-friendly), Firestore read ఏమీ జరగదు.

### Other assistance services (all ✅ implemented)

| Service | Source | Citizen actions |
|---|---|---|
| **Blood Bank Directory** | Bundled `ap_blood_banks.json` (AP blood banks with phone/coordinates) | Browse, search by name/address/type, distance-sorted with GPS, call, directions |
| **Blood Donor Search** | Firestore `users` (`bloodGroup` + `isBloodDonor`) | Find donors by blood group, call, WhatsApp with prefilled request |
| **Emergency Numbers** | Static list in Help | One-tap call: **112** emergency · **108** ambulance · **100** police · **101** fire · **1077** disaster management |
| **Village Emergency Contacts** | `preparedness.emergencyContacts` | Tappable call rows; graceful 112 fallback when unpublished |
| **Civic complaints (non-emergency)** | Original SATS `complaints` system (kept reachable) | File & track non-emergency civic complaints |

---

## 19. 🔔 Notification Architecture (actual, verified)

```
                    ┌────────────────────────────────────────────┐
                    │        IN-APP FIRESTORE NOTIFICATIONS       │
                    │        (notifications collection)           │
                    └────────────────────────────────────────────┘
Authority creates disaster ──→ DisasterAlertNotificationService
                               (targeting → batch write, disaster_{id}_{uid})
Citizen reports incident  ──→ IncidentService._notifyAuthorities
                               (authority users of area, incident_{id}_{uid})
Citizen triggers SOS      ──→ sos notifications to guardian app users
Missing person alert      ──→ missing_person notifications
Complaint / community post ─→ existing original-SATS notifications
                    ↓
Citizen/Authority Notification Screen (unread badge, per-type icons)
                    ↓
Deep link: relatedDocumentId → exact detail screen
           (disaster_alert → DisasterAlertDetailScreen, etc.)
```

**Technologies actually used (verified):**

| Channel | Used? | Where |
|---|---|---|
| In-app Firestore notifications | ✅ Primary | All alert/incident/SOS/missing-person/community/complaint notifications |
| **FCM** | 🟡 **SOS guardians only** | `functions/src/emergencySosAlert.ts` Cloud Function (on `emergencies` create → high-priority push to guardian device tokens). **No FCM for disaster alerts**; no `firebase_messaging` plugin in the Flutter app. |
| SMS | ✅ | SOS guardian SMS via native Android (section 12) |
| Cloud Functions | 🟡 | One function only (SOS FCM). Disaster fan-out is client batch writes — no Cloud Functions involved. |

---

## 20. 🗄️ Firestore / Data Architecture (current collections)

| Collection | Purpose | Main User |
|---|---|---|
| `users` (+ `guardians` subcollection) | Profiles incl. role, village/mandal/district, blood group, donor flag, normalized phone | All |
| `disasters` | Disaster events: type, severity, lifecycle, affected lists, evacuation flag | Authority writes; all read |
| `shelters` | Shelter CRUD: capacity/occupancy/status, locationText + lat/lng | Authority writes; all read |
| `incidents` | Citizen incident reports + triage status | Citizen writes; authority/rescue triage |
| `preparedness` | Village preparedness (doc ID = village key) | Authority writes; all read |
| `damage_assessments` | Post-disaster damage records | Authority/rescue write; all read |
| `resources` | Relief resource need/stock/allocation | Authority/rescue write; all read |
| `notifications` | In-app notifications (typed, targeted, deep-linked) | Service-layer writes; owner reads |
| `missing_person_alerts` | Missing person reports + Found Safe resolution | All write own; all read |
| `emergencies` | SOS sessions with live location | Owner-only (rules) |
| `complaints` (+ `messages`) | Legacy civic complaints (kept reachable) | Citizen + admin |
| `posts` (+ `reactions`) / `pinned_posts` | Community posts & reactions | All |
| `hospitals` | Read-only seeded hospital data (original SATS; current UI uses assets) | No client writes |

**Composite indexes** (`firestore.indexes.json`): incidents by village/mandal/district/reportedBy/disasterId + createdAt · disasters by status + createdAt · damage_assessments & resources by area fields + disasterId · notifications by targetUserId + createdAt · complaints/posts by area + createdAt.

---

## 21. 🔐 Security (verified against `firestore.rules`)

| Rule area | Enforced behavior |
|---|---|
| Default | **Deny all** unmatched paths |
| Sign-up | Self-signup can **only** create `role == "citizen"`; `role` field **immutable** after creation (no client escalation) |
| Authority data | `disasters`, `shelters`, `preparedness`: create/update/delete = authority-only; disasters & preparedness can never be deleted |
| Incident integrity | Create only with `reportedBy == caller`; reporters can't modify after submit; updates limited to triage fields by authority/rescue; no deletes |
| Damage/resources | Creator identity enforced (`reportedBy == caller`); authority/rescue write; read public; no deletes |
| SOS emergencies | Create/read/update **owner-only** (`userId == auth.uid`); no deletes |
| Notifications | Read/update/delete **only where `targetUserId == auth.uid`** |
| Missing persons | Public read; any user may mark found-safe but **only** on `status/foundAt/updatedAt` fields |
| Hospitals | Read-only from clients (`write: false`) |
| Ownership | Complaints, posts: owner-only edit/delete; post reactions restricted to counter fields |

**Telugu:**

> "Citizen UI లో Edit/Delete controls లేకపోవడం మాత్రమే security కాదు — Firestore rules కూడా unauthorized writes ని block చేస్తాయి." ఉదాహరణకి: citizen hack చేసి incident status మార్చబోతే rules అనుమతించవు. Role escalation (citizen → authority) కూడా rules తో ఆగిపోతుంది.

---

## 22. 📶 Offline / Low Network (actual capabilities)

| Capability | Status | Mechanism |
|---|---|---|
| Firestore offline persistence | ✅ | `main.dart`: `persistenceEnabled: true` + unlimited cache — cached data remains readable without network; queued writes replay on reconnect |
| Incident draft persistence | ✅ | Report form autosaves to SharedPreferences (`IncidentDraftService`); restore on reopen; cleared on submit |
| Hospital / blood-bank data | ✅ | **Bundled assets** — fully available offline (no network needed at all) |
| Realtime streams | ✅ with caveat | Serve from cache offline, then resync |
| First-time data & submissions | 🔎 requires network | Initial Firestore fetch, submitting incidents/alerts, sending SMS/calls (telephony) |
| Full offline-first operation | ❌ | Not claimed — the app degrades gracefully but is cloud-backed |

---

## 23. 🔁 Original SATS → SATS Disaster

### Reused from Original SATS (verified present)

- Authentication (email/Google) + user profiles with AP geography fields
- GPS / location services (`geolocator`, `LiveLocationService`, `LocationService`)
- **SOS foundation**: 2-sec hold, guardians, native SMS, native call + voice playback, emergency history, realtime deactivation
- **Stealth SOS** native Android stack (power-button watcher, boot receiver)
- **AP geography dataset** (`andhra_pradesh.json` — districts/subDistricts/villages)
- **Public Hospitals** dataset + directory (assets) · **Blood banks** dataset
- Firebase foundation + Firestore offline persistence
- Cloudinary media uploads
- Community posts & civic complaints systems (kept, demoted to non-emergency)
- Shared Google Maps directions helper (`maps_directions.dart`) & `tel:` calling pattern

### New Disaster Management Layer (built for SATS Disaster)

- Disaster events with lifecycle + instructions + evacuation flag
- Geo-targeted alert fan-out with deterministic duplicate protection
- Alert editing (no duplicate fan-out) + close-with-history
- Evacuation screen tied to preparedness
- Shelters CRUD + strict-3-level citizen view + directions
- Incident reporting (10 types, GPS, Cloudinary evidence, rescue/medical needs, draft autosave)
- Realtime incident triage workflow
- Village preparedness publishing
- Damage assessment workflow
- Relief resource tracking with validation
- Data-derived recovery status (RecoveryStatusHelper)
- Disaster-linked missing persons (`disasterId`)
- Authority Disaster Command Center (4-tab)
- Demo-data seeding + honest "DEMO" tagging

---

## 24. 🧰 Technology Stack

### Frontend
- **Flutter** (Dart) · Material 3 · custom design system (`app_theme.dart`: AppColors/AppText/AppSpacing, shared cards, status chips, empty/error states)
- Role-adaptive single-shell navigation (citizen vs authority tab sets)

### Backend / Cloud
- **Firebase** · **Cloud Firestore** (realtime listeners, batch writes, transactions) · **Firebase Authentication** (email + Google sign-in)
- Firebase Cloud Functions (TypeScript) — SOS FCM push

### Location & Maps
- GPS via `geolocator` · `location_service.dart` / `live_location_service.dart`
- **Google Maps URLs deep linking** (`MapsDirections` — keyless `api=1` directions URLs) + Maps location links on incidents/damage
- Geocoding (`geocoding` package)

### Notifications
- Firestore in-app notifications (primary) · native SMS · native calls · FCM (SOS guardians via Cloud Function)

### Media
- **Cloudinary** image upload (incident evidence, damage photos, missing-person photos)

### Native Android (Kotlin — `com.sats.disaster`)
- `SMSService` channel — emergency SMS · `CallService` channel — guardian calls + emergency voice playback + call-state monitoring
- `PowerButtonSosService.kt` + `StealthSosManager.kt` + `BootReceiver.kt` — stealth SOS (works locked/killed/after reboot)

### Data
- Firestore collections (section 20) · AP geography JSON · 16-district hospitals JSON · AP blood-banks JSON

### Testing
- **Flutter Test** — **304 tests, all passing** (models, services, targeting, shelters, hospitals, recovery, helpers, dashboards)
- **Flutter Analyze** — **0 errors, 0 warnings** (remaining items are pre-existing `info` lints in legacy scripts)

### Key packages (from `pubspec.yaml`)
`firebase_core` · `firebase_auth` · `cloud_firestore` · `google_sign_in` · `cloud_firestore` offline persistence · `geolocator` · `geocoding` · `permission_handler` · `url_launcher` · `image_picker` · `file_picker` · `cached_network_image` · `http` (Cloudinary) · `shared_preferences` · `vibration`

---

## 25. 🏗️ System Architecture

```
                        SATS DISASTER (Flutter)
                                  │
              ┌───────────────────┴───────────────────┐
              │                                       │
   CITIZEN (4 tabs)                       AUTHORITY (4 tabs)
   Home · Report · SOS · Get Help         Command · Incidents · Shelters · Alerts
              │                                       │
              └───────────────────┬───────────────────┘
                                  ↓
                    Service Layer (Dart)
       DisasterService · IncidentService · HospitalService ·
       ShelterService · SOSService · GuardianAlertService ·
       RecoveryStatusHelper · GeoMatch (pure logic)
                                  ↓
                              Firebase
              ┌───────────────────┼────────────────────┐
              ↓                   ↓                    ↓
        Authentication      Cloud Firestore       Cloud Function
                            (realtime streams,    emergencySosAlert
                             offline cache,       (SOS → FCM to
                             batch/transactions)   guardians)
                                  │
                        Notifications (typed docs)
                                  │
                          Native Android (Kotlin)
                     SOS SMS · Calls + voice · Stealth SOS
                                  │
                    Bundled datasets (offline)
                  AP geography · hospitals · blood banks
```

---

## 26. 🎬 Complete End-to-End Demo Story (all steps implemented)

**Scenario: Cyclone warning — Ambajipeta mandal, East Godavari**

| # | Screen | User | Action | System response |
|---|---|---|---|---|
| 1 | Alerts tab | Authority | Creates disaster "Cyclone Hudhud Alert", type=cyclone, severity=high, affected villages incl. Mukkamala, evacuation required | Event saved (`monitoring/active`); targeted `disaster_alert` notifications fan out to affected users |
| 2 | Notifications | Citizen (Mukkamala) | Sees unread alert notification | Taps → deep-links to **Cyclone Hudhud Alert** detail |
| 3 | Alert Detail | Citizen | Reads severity badge, instructions, "Evacuation required" | Evacuation emphasis shown |
| 4 | Evacuation | Citizen | Opens Evacuation | "Evacuation required" card + published village routes + contacts |
| 5 | Shelters | Citizen | Opens Shelters → picks "ZP High School" (OPEN, 120 spaces) | Capacity bar + status chip; taps **Get Directions** |
| 6 | Google Maps | Citizen | Navigates to shelter | Keyless Maps deep link opens turn-by-turn |
| 7 | Report tab | Citizen | Reports **Person Trapped**, severity=critical, GPS + photo, rescue required, 3 people | Incident stored; authorities of the area notified; draft autosaved if network drops mid-form |
| 8 | Incidents tab | Authority | Sees critical incident at top, opens detail | Views map link + photo evidence; sets **Verified → Triaged → Dispatched** |
| 9 | My Incidents | Citizen | Watches status change in realtime | Sees "Dispatched" — help is moving |
| 10 | Shelters tab | Authority | Updates shelter occupancy as families arrive | Citizens see LIVE/FULL status change |
| 11 | Damage tab (authority) | Authority | Records road damage + house damage with photos (disaster linked) | Status flow Reported → … begins |
| 12 | Resources | Authority | Records village needs: drinking water 2000 L, have 800 → shortfall 1200 | Prioritized relief list with coverage % |
| 13 | Recovery | Authority/Citizen | Village status derives **Response Ongoing → In Recovery** as incidents close & damage recovers | Computed from real data |
| 14 | Alerts tab | Authority | Closes disaster when threat passes | Status `closed` + endedAt; history preserved; citizens' home shows All Clear |

---

## 27. 📋 Feature Matrix

| Module | Citizen | Authority | Main Purpose |
|---|---|---|---|
| Disaster Alerts | Receive targeted alerts, view detail | Create / edit / close events | Area-specific warnings |
| Notifications | Read, deep-link, mark read | Receive incident notifications | Reliable in-app delivery |
| Evacuation | View status, routes, contacts | (via preparedness publishing) | Safe movement guidance |
| Shelters | View, status, directions | Full CRUD + occupancy mgmt | Evacuation destinations |
| Incident Reporting | Report with GPS/photo/needs | Realtime feed + triage | Ground-truth reporting |
| Incident Triage | Track own report status | Reported→Resolved workflow | Accountable response |
| SOS | Trigger (manual/stealth), deactivate | — | Personal emergency response |
| Missing Persons | Create alerts, mark found safe | Visibility | Reunification |
| Preparedness | View routes/contacts/risk | Publish village data | Before-disaster readiness |
| Damage Assessment | View village progress | Record & progress assessments | Post-disaster accounting |
| Relief Resources | View availability | Track need/stock/allocation | Fair relief distribution |
| Recovery | Village recovery status | Disaster-level overview | Lifecycle closure |
| Hospitals | Search, call, directions | — | Medical assistance directory |
| Blood Banks / Donors | Search banks & donors, call, WhatsApp | — | Medical resource directory |
| Community / Complaints | Posts, civic complaints | Admin complaint handling | Original SATS engagement |
| SOS Guardians | Manage guardians | — | SOS prerequisite setup |

---

## 28. ✨ What Makes SATS Disaster Different (factual)

1. **Village-level targeting** — alerts reach exactly the affected villages/mandals/districts, not a whole state broadcast (GeoMatch normalization + deterministic fan-out).
2. **Citizen + Authority in one system** — the report→triage→resolution loop closes inside one platform with realtime visibility for both sides.
3. **Full lifecycle** — before (preparedness), during (alerts/shelters/incidents/SOS), after (damage/resources/recovery) — not just alerts.
4. **Realtime incident triage** — enforced single-forward-step status flow with an intact audit trail (rules-backed).
5. **Shelter navigation** — capacity/status + keyless Google Maps directions with honest fallbacks.
6. **Location-based reporting** — GPS + Cloudinary evidence + profile geography (routeable even without GPS fix).
7. **Integrated SOS foundation** — battle-tested guardian SMS/call/live-location/stealth system, now disaster-context aware.
8. **Recovery derived from data** — recovery status is computed, never hand-waved.
9. **Existing AP geographic hierarchy** — district/mandal/village data already bundled; hospitals & blood banks included.
10. **Honest UI** — demo data labeled, missing data clearly stated, no fake availability claims.

> ఈ features అన్నీ ఒకే platform లో కలిసి పనిచేయడమే నిజమైన విలువ — alert వచ్చాక shelter దొరుకుతుంది, shelter వెళ్ళే దారి కనిపిస్తుంది, దారిలో ఏదైనా problem అయితే report చేయగలరు, report మీద action అవుతుంది, disaster తర్వాత recovery కనిపిస్తుంది.

---

## 29. ⚠️ Current Limitations / Future Scope

> Nothing below is implemented; none of these are bugs. Stated openly for the PPT.

| Area | Current state | Future scope |
|---|---|---|
| AI damage assessment | Photos are evidence only | AI-assisted severity estimation from images |
| Disaster forecasting | Manual authority creation | Predictive early warnings (weather API/GIS) |
| Satellite / GIS integration | Not present | Satellite flood/cyclone overlays |
| Rescue dispatch integration | **"Dispatched" is a workflow state only** — no external 108/CAD integration | Real dispatch integration, team GPS tracking |
| Logistics optimization | Manual resource records | Route/convoy optimization for relief |
| WhatsApp integration | WhatsApp only for blood-donor contact (prefilled message) | Official WhatsApp alert channel |
| FCM for disaster alerts | In-app Firestore notifications only | FCM push for disaster alerts + web dashboard |
| Offline-first submissions | Draft persistence only; submission needs network | Full offline queue & sync |
| Live hospital availability | Static directory (honest about it) | Real-time bed/availability feeds |
| Push notification reliability (SOS FCM) | Cloud Function exists in repo | 🔎 Manual verification: deployed function + guardian token registration on real devices |
| Bilingual UI | English UI, Telugu used in docs | Local-language UI |

---

## 30. 📑 PPT Quick Reference (copy-paste ready)

**Slide 1 — Problem**
- Disasters demand instant, local, trustworthy information
- Villagers get general news, not village-level warnings
- Shelter locations & capacity unknown during evacuation
- Incident reporting = phone calls; no tracking, no evidence
- Post-disaster damage & relief untracked
- Missing-person coordination is ad-hoc

**Slide 2 — Why Current Systems Are Limited**
- Broadcast warnings ignore village boundaries
- No feedback loop: citizens never know if their report was acted on
- Multiple disconnected tools (calls, papers, word of mouth)
- No single record of what happened, where, and what was done
- Personal emergencies (SOS) disconnected from disaster context

**Slide 3 — Proposed Solution**
- One Flutter + Firebase platform: citizens ↔ authorities
- Village/mandal/district geographic targeting (GeoMatch)
- Full lifecycle: preparedness → alert → response → recovery
- Realtime incident triage with audit trail
- SOS with SMS + call + live location + stealth power-button trigger
- Integrated AP hospitals & blood-bank directories (offline data)

**Slide 4 — Target Users**
- Citizen: receive alerts, evacuate safely, report incidents, SOS
- Village Authority: village operations & triage
- District Authority: wide-scope alerts & overview
- Rescue Team: assigned incident handling

**Slide 5 — Before / During / After**
- Before: preparedness, routes, contacts, hospitals, blood banks
- During: targeted alerts, evacuation, shelters, incidents, SOS
- After: damage assessment, resource tracking, recovery status, close
- Status always computed from real data

**Slide 6 — Citizen Workflow**
- Login → profile (village/mandal/district) → Home status hero
- Alert → detail → evacuation → shelter → directions
- Report incident (type/severity/GPS/photo/needs) with draft autosave
- Track status realtime; view recovery; call 112/108 anytime

**Slide 7 — Authority Workflow**
- Create disaster → set affected geography → alert fans out
- Command dashboard: incidents, shelters, resources, damage
- Triage: Reported → Verified → Triaged → Dispatched → Resolved
- Publish preparedness; close disaster with history preserved

**Slide 8 — Key Features**
- Geo-targeted alerts (deterministic, duplicate-proof)
- Shelters with capacity bar + Google Maps directions
- Incident evidence: GPS + Cloudinary photos
- SOS: 2-sec hold, guardians, stealth power-button SOS
- Missing-person alerts with disaster linkage
- Data-derived recovery (Response → Recovery → Restored)

**Slide 9 — Architecture**
- Flutter app (role-adaptive: citizen vs authority shells)
- Service layer: pure testable logic (GeoMatch, RecoveryHelper, targeting)
- Firebase: Auth + Firestore (realtime, offline cache, batch, transactions)
- Native Android Kotlin: SMS, calls, stealth SOS
- Cloud Function: SOS → FCM push to guardians

**Slide 10 — Technology Stack**
- Flutter / Dart / Material 3 + custom design system
- Firebase Auth · Cloud Firestore · Cloud Functions
- geolocator · geocoding · url_launcher (keyless Maps deep links)
- Cloudinary media · SharedPreferences drafts
- Kotlin native channels · 304 passing Flutter tests

**Slide 11 — Security**
- Default-deny Firestore rules; role immutable after creation
- Sign-up can only create citizens; authorities provisioned out-of-band
- Creator identity enforced on incidents/damage
- Owner-only SOS & notifications; field-restricted updates
- UI hides actions AND rules block unauthorized writes

**Slide 12 — Innovation / Differentiation**
- Village-level targeting, not state-wide broadcast
- Closed loop: report → triage → resolution, visible to reporter
- One platform for the entire lifecycle
- Recovery status derived, never hand-entered
- Honest UI: demo tags, explicit empty states, no fake claims

**Slide 13 — Demo Workflow**
- Authority: create cyclone + alert → citizen notified (targeted)
- Citizen: alert → evacuation → shelter → directions
- Citizen: report person trapped (GPS + photo, critical)
- Authority: triage to Dispatched; update shelter occupancy
- Aftermath: damage → resources shortfall → recovery → close

**Slide 14 — Future Scope**
- AI damage assessment · predictive forecasting
- Satellite/GIS overlays · real dispatch integration
- FCM push for disaster alerts · offline-first sync
- Live hospital availability · local-language UI

---

## 31. 🎤 One-Line Pitches

### Simple
> "SATS Disaster అనేది disaster సమయంలో ప్రతి గ్రామస్థుడికి సరైన సమాచారం, సరైన సమయంలో అందించి, help చేర్చే ఒక mobile platform."

### Judge-friendly
> "SATS Disaster connects citizens and authorities across the entire disaster lifecycle — village-targeted alerts, shelter navigation, evidence-based incident reporting with realtime triage, and data-derived recovery — in one Flutter + Firebase platform."

### Technical
> "A Flutter/Firebase disaster-management platform using normalized 3-level geographic matching (village-mandal-district), deterministic Firestore notification fan-out with transactional dedup, enforced triage state machines via security rules, native Kotlin SOS channels (SMS/call/stealth power-button), and pure-function recovery derivation — validated by 304 passing tests."

---

*Documentation generated from a verified inspection of the current codebase (`flutter analyze`: 0 errors / 0 warnings · `flutter test`: 304/304 passing). Sections marked 🟡/🔎/🔮 describe partial, device-verification, or future items respectively.*
