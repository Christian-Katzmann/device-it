#!/usr/bin/env node
// ~/.device-it/registry.json CRUD. Usage:
//   registry.mjs add '{"slug":"x","name":"X","url":"https://...","profileIdentifier":"dk.deviceit.x","project":"deviceit-x"}'
//   registry.mjs list | get <slug> | remove <slug>
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const file = path.join(os.homedir(), '.device-it', 'registry.json');
const load = () => { try { return JSON.parse(fs.readFileSync(file, 'utf8')); } catch { return { apps: [] }; } };
const save = (r) => { fs.mkdirSync(path.dirname(file), { recursive: true }); fs.writeFileSync(file, JSON.stringify(r, null, 2)); };

const [cmd, arg] = process.argv.slice(2);
const reg = load();

switch (cmd) {
  case 'add': {
    const entry = JSON.parse(arg);
    entry.updatedAt = new Date().toISOString();
    const i = reg.apps.findIndex(a => a.slug === entry.slug);
    if (i >= 0) reg.apps[i] = { ...reg.apps[i], ...entry }; else reg.apps.push(entry);
    save(reg);
    console.log(JSON.stringify({ ok: true, slug: entry.slug }));
    break;
  }
  case 'list':
    console.log(JSON.stringify(reg.apps, null, 2));
    break;
  case 'get': {
    const a = reg.apps.find(a => a.slug === arg);
    if (!a) { console.error('not found'); process.exit(1); }
    console.log(JSON.stringify(a, null, 2));
    break;
  }
  case 'remove': {
    const before = reg.apps.length;
    reg.apps = reg.apps.filter(a => a.slug !== arg);
    save(reg);
    console.log(JSON.stringify({ ok: true, removed: before - reg.apps.length }));
    break;
  }
  default:
    console.error('usage: registry.mjs add <json> | list | get <slug> | remove <slug>');
    process.exit(1);
}
