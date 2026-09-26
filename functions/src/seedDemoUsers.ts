// ─────────────────────────────────────────────────────────────────────────────
//  SATS Disaster — Demo Account Provisioning Tool (Admin SDK)
// ─────────────────────────────────────────────────────────────────────────────
//
//  WHY THIS EXISTS
//  The app is Google-Sign-In-only (lib/services/auth_service.dart), so demo
//  personas must be REAL Google accounts. Client-side code cannot assign
//  authority roles (firestore.rules forbids role escalation by design), and
//  the Firebase client SDK cannot look users up by email. Only the Admin SDK
//  can do both, so provisioning lives here.
//
//  WHAT IT DOES
//  For each entry in the account config (tool/demo_accounts.json):
//    1. Looks up the Google account in Firebase Auth by email.
//       - Found    → reuses that uid (no duplicate user is created).
//       - Missing  → reports it and skips (you must sign in to the app once
//                    with that Google account, or create it in the console;
//                    this tool never fabricates auth users).
//    2. Creates or updates users/{uid} with name/phone/role and the location
//       scope, using the project's LEGACY field mapping (see
//       lib/models/user_model.dart, UserFieldKeys):
//           users doc "village" field  = mandal name
//           users doc "street" field   = village name
//       Merging is additive: existing fields the tool does not manage (e.g.
//       photoUrl, bloodGroup, dateOfBirth) are preserved.
//
//  IDEMPOTENCE
//  - Auth users are never created, only looked up → re-running can never
//    duplicate an account.
//  - users/{uid} writes use set(..., {merge: true}) on deterministic fields →
//    re-running updates the same document in place.
//  - Re-running reports what changed and what was already correct.
//
//  USAGE (from functions/)
//    npm run seed:demo-users                     # default config path
//    npm run seed:demo-users -- --config=../tool/demo_accounts.json
//    GOOGLE_APPLICATION_CREDENTIALS=/path/service-account.json npm run seed:demo-users
//    node lib/src/seedDemoUsers.js --dry-run     # report only, write nothing
//
//  CREDENTIALS (never hardcoded):
//    - GOOGLE_APPLICATION_CREDENTIALS pointing at a service-account JSON with
//      "Firebase Authentication Admin" + "Cloud Datastore User" roles, OR
//    - `firebase login` + `firebase functions:shell` / ADC from gcloud.
//      (Application Default Credentials.)
// ─────────────────────────────────────────────────────────────────────────────

import * as fs from 'fs';
import * as path from 'path';
import * as admin from 'firebase-admin';

interface DemoAccountSpec {
  /** Google account email — must already exist in Firebase Auth. */
  email: string;
  name: string;
  /** One of: citizen | village_authority | district_authority | rescue */
  role: string;
  phone: string;
  /** Legacy users-doc fields: district → "district", mandal → "village", village → "street". */
  district: string;
  mandal: string;
  village: string;
  purpose: string;
}

interface DemoAccountsConfig {
  /** Defaults shown here; all overridable per-account. */
  state?: string;
  accounts: DemoAccountSpec[];
}

const VALID_ROLES = ['citizen', 'village_authority', 'district_authority', 'rescue'];

// ── CLI ──────────────────────────────────────────────────────────────────────

function parseArgs(argv: string[]): { configPath: string; dryRun: boolean } {
  let configPath = path.resolve(__dirname, '..', '..', 'tool', 'demo_accounts.json');
  let dryRun = false;
  for (const arg of argv.slice(2)) {
    if (arg.startsWith('--config=')) {
      configPath = path.resolve(arg.slice('--config='.length));
    } else if (arg === '--dry-run') {
      dryRun = true;
    }
  }
  return { configPath, dryRun };
}

// ── Main ─────────────────────────────────────────────────────────────────────

export async function main(): Promise<void> {
  const { configPath, dryRun } = parseArgs(process.argv);

  if (!fs.existsSync(configPath)) {
    console.error(`✗ Config not found: ${configPath}`);
    console.error('');
    console.error('Create it from the template:');
    console.error('  cp tool/demo_accounts.example.json tool/demo_accounts.json');
    console.error('Then replace the placeholder emails with the REAL Google');
    console.error('account emails (e.g. Gmail) you will use in the demo.');
    throw new Error(`config not found: ${configPath}`);
  }

  const raw = JSON.parse(fs.readFileSync(configPath, 'utf8')) as DemoAccountsConfig;
  const state = raw.state ?? 'Andhra Pradesh';
  const accounts = raw.accounts ?? [];

  if (accounts.length === 0) {
    console.error('✗ Config has no accounts.');
    process.exitCode = 1;
    return;
  }

  // Validate before touching anything.
  const errors: string[] = [];
  const seenEmails = new Set<string>();
  accounts.forEach((acc, i) => {
    const label = `accounts[${i}] (${acc.email ?? 'missing email'})`;
    if (!acc.email || !acc.email.includes('@')) errors.push(`${label}: invalid email`);
    if (seenEmails.has(acc.email)) errors.push(`${label}: duplicate email in config`);
    seenEmails.add(acc.email);
    if (!VALID_ROLES.includes(acc.role)) {
      errors.push(`${label}: role must be one of ${VALID_ROLES.join(', ')}`);
    }
    if (acc.role === 'village_authority' && (!acc.village || !acc.mandal || !acc.district)) {
      errors.push(`${label}: village_authority requires village + mandal + district`);
    }
    if (acc.role === 'district_authority' && !acc.district) {
      errors.push(`${label}: district_authority requires district`);
    }
    if (acc.role === 'citizen' && (!acc.village || !acc.mandal || !acc.district)) {
      errors.push(`${label}: citizen requires village + mandal + district`);
    }
  });
  if (errors.length > 0) {
    console.error('✗ Config validation failed:');
    for (const e of errors) console.error(`  - ${e}`);
    throw new Error('config validation failed');
  }

  // ── Initialize Admin SDK (Application Default Credentials) ──
  // Explicit project override keeps the tool honest about what it touches:
  // the Firebase CLI's active project or env can redirect ADC silently.
  const projectArg = process.argv.find((a) => a.startsWith('--project='));
  const projectId = projectArg ? projectArg.slice('--project='.length) : 'sats-disaster-sih';
  admin.initializeApp({ projectId });
  console.log(`Project: ${projectId}${dryRun ? '  (DRY RUN — nothing will be written)' : ''}`);
  console.log(`Accounts in config: ${accounts.length}`);
  console.log('');

  let created = 0;
  let updated = 0;
  let unchanged = 0;
  let missing = 0;

  for (const acc of accounts) {
    const label = `${acc.email} → ${acc.role}`;
    console.log(`─ ${label}`);
    console.log(`  purpose: ${acc.purpose}`);

    // 1. Resolve the Google account by email (NEVER create auth users).
    let user: admin.auth.UserRecord;
    try {
      user = await admin.auth().getUserByEmail(acc.email);
    } catch (err: any) {
      if (err?.code === 'auth/user-not-found') {
        console.log('  ✗ AUTH MISSING — no Firebase Auth user with this email.');
        console.log('    Sign in once with this Google account (app or console →');
        console.log('    Authentication → Users → Add user is NOT the same; it must be');
        console.log('    a real Google identity for Google Sign-In to work), then re-run.');
        missing++;
        console.log('');
        continue;
      }
      throw err;
    }

    console.log(`  ✓ auth user found: uid=${user.uid}`);

    // 2. Build the users/{uid} payload with the LEGACY field mapping.
    //    Do not reorder these comments — the mapping is intentional and
    //    documented in lib/models/user_model.dart (UserFieldKeys).
    const docData: Record<string, unknown> = {
      name: acc.name,
      phone: acc.phone,
      email: acc.email,
      role: acc.role,
      district: acc.district,
      village: acc.mandal,  // LEGACY: users-doc "village" field stores the MANDAL name
      street: acc.village,  // LEGACY: users-doc "street" field stores the VILLAGE name
      state,
      // Presence flags let re-runs distinguish "tool wrote this" from
      // "someone else wrote this" without mutating unmanaged fields.
      isDemoData: true,
    };

    // 3. Compare with the existing doc (if any) for accurate reporting.
    const db = admin.firestore();
    const ref = db.collection('users').doc(user.uid);
    const snap = await ref.get();

    if (!snap.exists) {
      console.log(`  + PROFILE MISSING — will create users/${user.uid}`);
      if (!dryRun) {
        await ref.set(
          {
            ...docData,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true },
        );
      }
      created++;
      console.log(`    role=${acc.role}  district=${acc.district}  mandal=${acc.mandal}  village=${acc.village}`);
    } else {
      const before = snap.data() ?? {};
      const changes: string[] = [];
      for (const [key, value] of Object.entries(docData)) {
        const current = before[key];
        const same =
          current !== undefined &&
          JSON.stringify(current) === JSON.stringify(value);
        if (!same) changes.push(`${key}: ${JSON.stringify(current) ?? '∅'} → ${JSON.stringify(value)}`);
      }
      if (changes.length === 0) {
        unchanged++;
        console.log('  = profile already correct (no changes)');
      } else {
        console.log('  ~ profile exists — updating:');
        for (const c of changes) console.log(`      ${c}`);
        if (!dryRun) await ref.set(docData, { merge: true });
        updated++;
      }
    }
    console.log('');
  }

  // ── Summary ──
  console.log('═ Summary ' + '═'.repeat(50));
  console.log(`  profiles created:    ${created}`);
  console.log(`  profiles updated:    ${updated}`);
  console.log(`  already correct:     ${unchanged}`);
  console.log(`  auth missing (skip): ${missing}`);
  if (missing > 0) {
    console.log('');
    console.log('  Some Google accounts are not in Firebase Auth yet. Sign in once');
    console.log('  with each (run the app → Continue with Google) and re-run this tool.');
  }
  console.log('');
  console.log('Next: verify with the checklist in tool/DEMO_RUNBOOK.md');
}

// Execute only when run directly; main() stays importable for tests.
if (require.main === module) {
  main().catch((err) => {
    console.error('✗ seed failed:', err?.message ?? err);
    process.exitCode = 1;
  });
}
