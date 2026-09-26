# SATS Disaster — Authority/Responder Demo Runbook

End-to-end screening demo: **Citizen reports → Authority/Responder sees & acts → Citizen sees the update.** Every step uses real accounts and real Firestore data in `sats-disaster-sih`. No fake data is involved in this workflow.

---

## 0. Prerequisites (one-time, before demo day)

### 0.1 Pick 4 real Google accounts
The app is **Google-Sign-In only** (`lib/services/auth_service.dart`). Demo personas must therefore be real Google identities you control — e.g. four Gmail accounts (or 1 citizen + 3 authority-side accounts if phone availability is limited).

Recommended: create four fresh Gmails, e.g.
- `sats.demo.citizen@gmail.com` → Citizen (Mukkamala)
- `sats.demo.vauthority@gmail.com` → Village Authority (Mukkamala)
- **You only need the emails; no passwords are ever needed by any script.**

### 0.2 Sign in once per account (creates the Auth user)
- Run the app on a device/emulator (`flutter run`) → **Continue with Google** → pick each of the 4 accounts once.
- This creates the Firebase Auth user. After sign-in, the app walks you through Profile Setup; you may complete it as Citizen — the provisioning tool will overwrite the relevant fields afterward.

### 0.3 Configure admin credentials
```bash
# Option A (recommended): service account key
#   Firebase Console → Project settings → Service accounts → Generate new private key
#   Save OUTSIDE the repo (it's git-ignored by name pattern anyway)
export GOOGLE_APPLICATION_CREDENTIALS=/absolute/path/sats-disaster-sih-service-account.json

# Option B: gcloud ADC
gcloud auth application-default login
# (ADC must be for the sats-disaster-sih project, or pass --project=sats-disaster-sih)
```

### 0.4 Prepare the account config
```bash
cp tool/demo_accounts.example.json tool/demo_accounts.json
# Edit tool/demo_accounts.json — put the 4 real Gmail addresses in.
# Keep district/mandal/village exactly as in the template (they match the app's
# bundled AP dataset and the demo seed geography):
#   district = East Godavari, mandal = Ambajipeta, village = Mukkamala
```

### 0.5 Provision
```bash
cd functions
npm run seed:demo-users:dry     # preview: shows found/missing/changed per account
npm run seed:demo-users         # write
```
Expected output per account:
- `✓ auth user found: uid=...`
- `+ PROFILE MISSING — will create users/<uid>` (first run) **or** `= profile already correct` (re-runs)
- Summary lines: `profiles created / updated / already correct / auth missing`

Re-running is safe: it updates the same `users/{uid}` docs and can never create duplicate auth users (it only looks them up by email).

### 0.6 (Optional) Seed background demo dataset
If you want the dashboards to have some ambient context beyond the live incident created during the demo:
```bash
# from repo root — runs the existing seed inside the Flutter engine
SATS_SEED=1 flutter test test/tool/seed_flutter_harness_test.dart
```
All seeded docs are tagged `demo: true`. This is optional — the core workflow needs nothing pre-seeded.

---

## 1. Demo flow (screening)

**Setup:** two devices (or one device + emulator). Device A = citizen account, Device B = authority/rescue accounts.

| # | Step | Expected result |
|---|------|-----------------|
| 1 | Device A: sign in as **Citizen** | Citizen app (Home/Report/SOS/Help tabs) |
| 2 | Device A: complete profile if asked (Mukkamala / Ambajipeta / East Godavari) | Profile saved |
| 3 | Device A: **Report** tab → submit an incident (e.g. *flood, critical, "Water entering houses near canal bund", rescue required*) | Confirmation; incident stored in `incidents` with `reportedBy = <citizen uid>` |
| 4 | Device B: sign in as **Village Authority** | Command dashboard (Command/Incidents/Shelters/Alerts tabs) |
| 5 | Device B: **Incidents** tab | The citizen's incident appears at top (critical first), tagged *RESCUE REQUIRED* |
| 6 | Device B: open incident → advance status (Reported → Verified) | Success; `updatedBy` = village authority uid |
| 7 | Device A: **My Incidents** (Home → see status) + notification | Status shows **Verified**; "Incident Update" notification arrives — realtime |
| 8 | Device B: sign out → sign in as **District Authority** | District-wide feed |
| 9 | Device B: **Incidents** tab | Same incident visible (district scope ⊇ mandal scope) |
| 10 | Device B: **Alerts** tab → create an alert for Ambajipeta mandal | Citizen (Device A) receives the targeted in-app alert |
| 11 | Device B: sign out → sign in as **Rescue** | Command dashboard (Incidents/Shelters/Alerts) |
| 12 | Device B: **Incidents** tab | Rescue-required incidents in Ambajipeta visible; status action available |
| 13 | Device B: advance status to Triaged/Dispatched | Success — rescue can update triage fields per rules |
| 14 | Device A: check status again | Shows latest status; workflow closed loop |

**Negative checks (do at least once):**
- Citizen account: try opening an authority URL/screenshot — citizens have no Command tabs (UI-level), and Firestore rules deny incident *updates* for citizens (rules-level). Rule-level check: attempt status change from the citizen's Firebase console data viewer is not possible; instead verify from Device A that "My Incidents" is read-only — there is no edit control by design, and the rules enforce it server-side.
- Village authority scope: the village feed streams incidents where `mandal == 'ambajipeta'`; an incident reported in a different mandal (e.g. create one from a second citizen account in Kakinada) does **not** appear in the village feed, but **does** appear for the district authority.

## 2. What "provisioned" means (data shape)

For each provisioned account, `users/{uid}` will contain (legacy field mapping — see `lib/models/user_model.dart`):

| users-doc field | holds | example |
|---|---|---|
| `role` | AppRoles value | `village_authority` |
| `district` | district name | `East Godavari` |
| `village` | **mandal** name (legacy) | `Ambajipeta` |
| `street` | **village** name (legacy) | `Mukkamala` |
| `name`, `phone`, `email`, `state` | profile | … |
| `isDemoData` | provisioning marker | `true` |

Do not "fix" these field names in the doc — the app's `UserModel` maps them deliberately.

## 3. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `✗ AUTH MISSING` in seed output | That Google account never signed in to the app | Sign in once (step 0.2), re-run seed |
| Authority logs in but sees citizen tabs | `users/{uid}.role` not yet written (seed not run for that account) | Run `npm run seed:demo-users` |
| Authority sees empty incident feed | Incident was reported in a different mandal/district than the authority's scope | Check scope fields in `tool/demo_accounts.json` vs the reporting citizen's profile |
| Splash shows "Account Problem — does not have access" | Profile doc missing or permission-denied on `users/{uid}` | Re-run provisioning; check service-account credentials |
| Splash shows "Connection Issue" | Real connectivity problem | Check network, tap Retry |
| Seed errors `PERMISSION_DENIED` on `users` | ADC/service account lacks Firestore role | Use a service account with **Firebase Admin** + **Cloud Datastore User** |
| Google sign-in fails with ApiException 10 | SHA-1 not registered in Firebase console | `cd android && ./gradlew signingReport`, add SHA-1 to Firebase project settings |

## 4. Security notes

- Provisioning **only** attaches roles/profiles to accounts that already exist in Firebase Auth — the tool cannot mint users and never touches passwords.
- Roles are assigned via the Admin SDK, which bypasses Firestore rules — exactly the out-of-band path the rules were designed for. Client-side role escalation remains impossible (`firestore.rules`: create requires `role == "citizen"`, updates may not change `role`).
- No rules were weakened. Citizens still cannot read other citizens' incident data beyond their own; authority/rescue scope enforcement lives in the app's streams (village/mandal/district queries) plus the unchanged rules.
- `tool/demo_accounts.json` (real emails) and any service-account keys are git-ignored; only the `*.example.json` template is committed.

## 5. Post-demo teardown (optional)

```bash
# Firebase console → Authentication: disable the 4 demo users (do NOT delete —
# deletion breaks the users/{uid} docs' future re-provisioning).
# Firestore: users/{uid} docs can stay; isDemoData=true marks them.
# Demo dataset (if seeded): docs tagged demo:true in disasters/shelters/etc.
```
