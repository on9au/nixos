#!/usr/bin/env node
// Imports Up Bank's spending account and Savers into Actual, categorised with
// Up's own categories. Run by actual-up-import*.service; see the homelab README.
//
// Environment:
//   ACTUAL_SERVER_URL, ACTUAL_SESSION_TOKEN, ACTUAL_BUDGET_ID, ACTUAL_E2E_PASSWORD
//     from actual-session; with no server URL, ACTUAL_BUDGET_ID is a local budget
//   UP_TOKEN_FILE     Up personal access token (default: the systemd credential)
//   UP_SINCE_DAYS     only this many days back; unset imports everything
//   UP_ACCOUNT_NAMES  JSON {"<Up name>": "<Actual name>"}; otherwise the same name
//   DRY_RUN=1         change nothing, report what would happen
import fs from "node:fs";
import api from "@actual-app/api";

const env = process.env;
const upUrl = env.UP_API_URL ?? "https://api.up.com.au/api/v1";
const upToken = fs
  .readFileSync(env.UP_TOKEN_FILE ?? `${env.CREDENTIALS_DIRECTORY}/up-token`, "utf8")
  .trim();
const dryRun = env.DRY_RUN === "1";
const sinceDays = env.UP_SINCE_DAYS ? Number(env.UP_SINCE_DAYS) : null;
const accountNames = JSON.parse(env.UP_ACCOUNT_NAMES || "{}");
const would = dryRun ? "Would create" : "Creating";

async function* up(path, params = {}) {
  let url = new URL(upUrl + path);
  for (const [k, v] of Object.entries(params)) url.searchParams.set(k, v);
  while (url) {
    const res = await fetch(url, {headers: {Authorization: `Bearer ${upToken}`}});
    if (res.status === 429) {
      await new Promise((r) => setTimeout(r, 10_000));
      continue;
    }
    if (!res.ok) throw new Error(`Up answered ${res.status} for ${url.pathname}: ${await res.text()}`);
    const body = await res.json();
    yield* body.data;
    url = body.links?.next ? new URL(body.links.next) : null;
  }
}

const all = async (it) => {
  const out = [];
  for await (const x of it) out.push(x);
  return out;
};

const same = (a, b) => a.toLowerCase() === b.toLowerCase();
const cents = (money) => money.valueInBaseUnits;

// en-CA formats as YYYY-MM-DD, in TZ, which the unit sets to the box's zone.
const day = (iso) =>
  new Intl.DateTimeFormat("en-CA", {year: "numeric", month: "2-digit", day: "2-digit"}).format(new Date(iso));

const notes = (at) =>
  [at.message, at.foreignAmount && `${at.foreignAmount.value} ${at.foreignAmount.currencyCode}`]
    .filter(Boolean)
    .join(" · ") || undefined;

const upAccounts = (await all(up("/accounts", {"page[size]": 100}))).filter(
  (a) => a.attributes.ownershipType === "INDIVIDUAL" && ["TRANSACTIONAL", "SAVER"].includes(a.attributes.accountType),
);
const upIds = new Set(upAccounts.map((a) => a.id));
const upCategories = new Map((await all(up("/categories"))).map((c) => [c.id, c]));

await api.init({
  dataDir: env.ACTUAL_DATA_DIR ?? "/tmp",
  ...(env.ACTUAL_SERVER_URL && {serverURL: env.ACTUAL_SERVER_URL, sessionToken: env.ACTUAL_SESSION_TOKEN}),
});
if (env.ACTUAL_SERVER_URL) {
  await api.downloadBudget(env.ACTUAL_BUDGET_ID, env.ACTUAL_E2E_PASSWORD ? {password: env.ACTUAL_E2E_PASSWORD} : undefined);
} else {
  await api.loadBudget(env.ACTUAL_BUDGET_ID);
}

// Up account id -> Actual account id; missing in a dry run for accounts not made yet.
const actualFor = new Map();
const accounts = await api.getAccounts();
for (const a of upAccounts) {
  const name = accountNames[a.attributes.displayName] ?? a.attributes.displayName;
  let id = accounts.find((x) => !x.closed && same(x.name, name))?.id;
  if (!id) {
    console.log(`${would} account ${name}`);
    if (!dryRun) id = await api.createAccount({name, offbudget: false}, 0);
  }
  if (id) actualFor.set(a.id, id);
}

// Up's child category -> the Actual category of the same name, made under a
// group named for Up's parent category if there isn't one.
const groups = await api.getCategoryGroups();
const categories = await api.getCategories();
const categoryIds = new Map();
async function categoryFor(upId) {
  if (!upId) return undefined;
  if (categoryIds.has(upId)) return categoryIds.get(upId);
  const upCategory = upCategories.get(upId);
  const name = upCategory.attributes.name;
  let id = categories.find((c) => !c.is_income && same(c.name, name))?.id;
  if (!id) {
    const parent = upCategories.get(upCategory.relationships.parent.data?.id)?.attributes.name ?? "Up";
    console.log(`${would} category ${parent} / ${name}`);
    if (!dryRun) {
      let group = groups.find((g) => !g.is_income && same(g.name, parent));
      if (!group) {
        group = {id: await api.createCategoryGroup({name: parent}), name: parent};
        groups.push(group);
      }
      id = await api.createCategory({name, group_id: group.id});
      categories.push({id, name});
    }
  }
  categoryIds.set(upId, id);
  return id;
}

const payees = await api.getPayees();
const params = {"page[size]": 100, "filter[status]": "SETTLED"};
if (sinceDays) params["filter[since]"] = new Date(Date.now() - sinceDays * 86_400_000).toISOString();

for (const a of upAccounts) {
  const name = a.attributes.displayName;
  const account = actualFor.get(a.id);
  const txns = [];

  for await (const t of up(`/accounts/${a.id}/transactions`, params)) {
    const at = t.attributes;
    const base = {
      date: day(at.createdAt),
      cleared: true,
      imported_id: t.id,
      imported_payee: at.rawText ?? at.description,
      notes: notes(at),
    };
    const from = t.relationships.transferAccount.data?.id;

    if (from && upIds.has(from)) {
      // A move between two imported accounts is taken from the receiving side
      // only (Round Ups included); Actual makes the other side itself, so the
      // sending side's own copy would be a duplicate.
      if (cents(at.amount) < 0) continue;
      const payee = payees.find((p) => p.transfer_acct === actualFor.get(from));
      txns.push({...base, amount: cents(at.amount), payee: payee?.id, payee_name: payee ? undefined : at.description});
    } else {
      txns.push({
        ...base,
        amount: cents(at.amount),
        payee_name: at.description,
        category: await categoryFor(t.relationships.category.data?.id),
      });
    }

    // Instant cashback (Perk-Up, Happy Hour) has no transaction of its own.
    if (at.cashback) {
      txns.push({
        ...base,
        imported_id: `${t.id}-cashback`,
        amount: cents(at.cashback.amount),
        payee_name: at.cashback.description,
        notes: undefined,
      });
    }
  }

  if (!account) {
    console.log(`${name}: ${txns.length} transactions to import once the account exists`);
    continue;
  }
  const result = await api.importTransactions(account, txns, {defaultCleared: true, dryRun});
  for (const e of result.errors ?? []) console.error(`${name}: ${e.message}`);
  console.log(`${name}: ${txns.length} from Up, ${result.added.length} new, ${result.updated.length} already there`);
}

// After every account, since importing one adds transfers to the others. Up's
// balance counts held transactions, which aren't imported until they settle.
let mismatch = false;
if (!dryRun) {
  for (const a of upAccounts) {
    const held = (await all(up(`/accounts/${a.id}/transactions`, {"page[size]": 100, "filter[status]": "HELD"})))
      .reduce((sum, t) => sum + cents(t.attributes.amount), 0);
    const expected = cents(a.attributes.balance) - held;
    const actual = await api.getAccountBalance(actualFor.get(a.id));
    if (actual !== expected) {
      mismatch = true;
      console.error(`${a.attributes.displayName}: balance is ${actual / 100} in Actual, ${expected / 100} at Up (settled only)`);
    }
  }
}

await api.shutdown();
if (mismatch) process.exit(3);
