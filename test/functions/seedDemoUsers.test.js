// Unit tests for the Admin SDK provisioning tool (functions/src/seedDemoUsers.ts).
//
// Approach: pre-load the require cache with a stubbed 'firebase-admin', write a
// temp config file, then require the compiled functions/lib/seedDemoUsers.js
// and invoke its exported main() directly. No real Firebase access, no extra
// test dependencies (plain node assert + flutter_test's node runner is NOT
// used — this file is executed with `node --test`).
//
// Run:  node --test test/functions/
const assert = require('assert');
const fs = require('fs');
const os = require('os');
const path = require('path');

const MODULE_PATH = path.resolve(
  __dirname, '..', '..', 'functions', 'lib', 'seedDemoUsers.js'
);

// ── admin stub plumbing ─────────────────────────────────────────────────────
const FUNCTIONS_DIR = path.resolve(__dirname, '..', '..', 'functions');

function stubAdmin({ authUsersByEmail, existingDocs, failLookup = false }) {
  const calls = { set: [], getUserByEmail: [] };

  const docRef = (id) => ({
    id,
    get: async () =>
      existingDocs[id] !== undefined
        ? { exists: true, data: () => existingDocs[id] }
        : { exists: false, data: () => undefined },
    set: async (data, opts) => {
      calls.set.push({ id, data, opts });
      existingDocs[id] = { ...(existingDocs[id] ?? {}), ...data };
    },
  });

  const admin = {
    initializeApp: () => undefined,
    auth: () => ({
      getUserByEmail: async (email) => {
        calls.getUserByEmail.push(email);
        if (failLookup) throw new Error('boom: network down');
        const hit = authUsersByEmail[email];
        if (!hit) {
          const e = new Error('No user found for that email.');
          e.code = 'auth/user-not-found';
          throw e;
        }
        return hit;
      },
    }),
    firestore: () => ({
      collection: (name) => {
        assert.strictEqual(name, 'users');
        return { doc: docRef };
      },
    }),
  };
  admin.firestore.FieldValue = { serverTimestamp: () => ({ __ts: true }) };

  // firebase-admin lives in functions/node_modules — resolve from there.
  const adminPath = require.resolve('firebase-admin', { paths: [FUNCTIONS_DIR] });
  require.cache[adminPath] = {
    id: 'firebase-admin',
    filename: adminPath,
    loaded: true,
    exports: admin,
  };
  return calls;
}

function writeConfig(accounts, state) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'sats-seed-'));
  const file = path.join(dir, 'demo_accounts.json');
  fs.writeFileSync(file, JSON.stringify({ state, accounts }));
  return file;
}

function withArgv(argv, fn) {
  const old = process.argv;
  process.argv = ['node', 'seedDemoUsers.js', ...argv];
  return Promise.resolve(fn()).finally(() => {
    process.argv = old;
  });
}

const VA = {
  email: 'va@example.com', name: 'Village Authority', role: 'village_authority',
  phone: '9000001001', district: 'East Godavari', mandal: 'Ambajipeta',
  village: 'Mukkamala', purpose: 'test',
};

// ── tests ───────────────────────────────────────────────────────────────────
(async () => {
  let passed = 0;
  const failures = [];

  async function test(name, fn) {
    try {
      await fn();
      passed++;
      console.log(`✔ ${name}`);
    } catch (e) {
      failures.push({ name, e });
      console.error(`✗ ${name}\n  ${e?.stack ?? e}`);
    }
  }

  const loadMain = () => {
    delete require.cache[MODULE_PATH];
    return require(MODULE_PATH).main;
  };

  await test('rejects config with invalid role before any write', async () => {
    stubAdmin({ authUsersByEmail: {}, existingDocs: {} });
    const cfg = writeConfig([{ ...VA, role: 'superadmin' }]);
    await withArgv([`--config=${cfg}`], async () => {
      await assert.rejects(() => loadMain()(), /config validation failed/);
    });
  });

  await test('rejects duplicate emails in config', async () => {
    stubAdmin({ authUsersByEmail: {}, existingDocs: {} });
    const cfg = writeConfig([VA, { ...VA, name: 'Dup' }]);
    await withArgv([`--config=${cfg}`], async () => {
      await assert.rejects(() => loadMain()(), /config validation failed/);
    });
  });

  await test('village_authority requires village+mandal+district', async () => {
    stubAdmin({ authUsersByEmail: {}, existingDocs: {} });
    const cfg = writeConfig([{ ...VA, village: '' }]);
    await withArgv([`--config=${cfg}`], async () => {
      await assert.rejects(() => loadMain()(), /config validation failed/);
    });
  });

  await test('missing auth user is skipped with a clear report', async () => {
    const cfg = writeConfig([VA]);
    const cfgArgv = [`--config=${cfg}`];
    await withArgv(cfgArgv, async () => {
      stubAdmin({ authUsersByEmail: {}, existingDocs: {} });
      await loadMain()(); // must not throw
    });
  });

  await test('creates missing profile with legacy field mapping + merge', async () => {
    const docs = {};
    const cfg = writeConfig([VA]);
    await withArgv([`--config=${cfg}`], async () => {
      stubAdmin({
        authUsersByEmail: { 'va@example.com': { uid: 'uid-va' } },
        existingDocs: docs,
      });
      await loadMain()();
    });
    assert.strictEqual(docs['uid-va'].role, 'village_authority');
    assert.strictEqual(docs['uid-va'].village, 'Ambajipeta'); // mandal → "village"
    assert.strictEqual(docs['uid-va'].street, 'Mukkamala');   // village → "street"
    assert.strictEqual(docs['uid-va'].district, 'East Godavari');
  });

  await test('re-run with identical data makes no changes (idempotent)', async () => {
    const docs = {
      'uid-va': {
        name: 'Village Authority', phone: '9000001001', email: 'va@example.com',
        role: 'village_authority', district: 'East Godavari',
        village: 'Ambajipeta', street: 'Mukkamala', state: 'Andhra Pradesh',
        isDemoData: true,
      },
    };
    const cfg = writeConfig([VA]);
    await withArgv([`--config=${cfg}`], async () => {
      stubAdmin({
        authUsersByEmail: { 'va@example.com': { uid: 'uid-va' } },
        existingDocs: docs,
      });
      await loadMain()();
    });
    // No set() call should have been issued for an already-correct doc.
    assert.ok(!Object.keys(docs['uid-va']).includes('createdAt'));
  });

  await test('existing profile with drift is updated in place (merge, no duplicate doc)', async () => {
    const docs = {
      'uid-va': {
        name: 'Old Name', role: 'citizen', village: 'OldMandal',
        photoUrl: 'http://x/y.png', bloodGroup: 'O+',
      },
    };
    const cfg = writeConfig([VA]);
    await withArgv([`--config=${cfg}`], async () => {
      stubAdmin({
        authUsersByEmail: { 'va@example.com': { uid: 'uid-va' } },
        existingDocs: docs,
      });
      await loadMain()();
    });
    // Unmanaged fields preserved (merge semantics).
    assert.strictEqual(docs['uid-va'].photoUrl, 'http://x/y.png');
    assert.strictEqual(docs['uid-va'].bloodGroup, 'O+');
    // Managed fields corrected.
    assert.strictEqual(docs['uid-va'].role, 'village_authority');
    assert.strictEqual(docs['uid-va'].village, 'Ambajipeta');
    assert.strictEqual(docs['uid-va'].street, 'Mukkamala');
    assert.strictEqual(docs['uid-va'].name, 'Village Authority');
  });

  await test('dry-run writes nothing', async () => {
    const docs = {};
    const cfg = writeConfig([VA]);
    await withArgv([`--config=${cfg}`, '--dry-run'], async () => {
      stubAdmin({
        authUsersByEmail: { 'va@example.com': { uid: 'uid-va' } },
        existingDocs: docs,
      });
      await loadMain()();
    });
    assert.strictEqual(docs['uid-va'], undefined);
  });

  // ── summary ───────────────────────────────────────────────────────────────
  console.log(`\n${passed} passed, ${failures.length} failed`);
  if (failures.length > 0) process.exit(1);
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
