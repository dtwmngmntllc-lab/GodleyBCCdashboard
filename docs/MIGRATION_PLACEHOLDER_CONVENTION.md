# Migration Placeholder Convention

Some files in `supabase/migrations/` are **placeholder migrations**: they
contain literal substitution tokens (e.g. `AGENCY_ID_PLACEHOLDER`,
`CLIENT_AGENCY_NAME`) that must be replaced with real per-client values
*before* the SQL is executed.

Applying a placeholder migration as-is inserts literal strings like
`'AGENCY_ID_PLACEHOLDER'` into the database — usually catastrophic. This
document defines the convention so that human operators and Claude
sessions handle these files consistently.

## Identifying a placeholder migration

A placeholder migration has all of:

1. A header stating "Per-Client Setup — Run Once Per New Client" (or
   equivalent).
2. A `SETUP CHECKLIST` listing every token that must be substituted, with
   guidance on each value's source.
3. One or more all-caps placeholder tokens in the SQL body. The canonical
   tokens used in this repo are:
   - `AGENCY_ID_PLACEHOLDER` — the agency UUID.
   - `CLIENT_*` — per-client values (e.g. `CLIENT_AGENCY_NAME`,
     `CLIENT_PRIMARY_EMAIL`, `CLIENT_TAX_ID`).

By contrast, **static migrations** (001-003, 005-007, etc.) ship final
SQL that applies unchanged.

## The exemplar: `004_seed_agency_record.sql`

`004` is the canonical placeholder migration for this repo. Its header
documents the full per-client substitution checklist and remains the
reference for token naming and section structure. When authoring a new
placeholder migration, mirror `004`'s header pattern.

## Applying a placeholder migration

Recommended flow per install:

1. **Never edit the repo copy.** Copy the file into a working location
   outside the repo, e.g. `/tmp/install/004.sql`.
2. **Substitute tokens** in the working copy. A simple `sed` pattern:
   ```bash
   sed -i \
     -e "s/AGENCY_ID_PLACEHOLDER/<actual-uuid>/g" \
     -e "s/CLIENT_AGENCY_NAME/<actual-name>/g" \
     -e "s/CLIENT_PRIMARY_EMAIL/<actual-email>/g" \
     # ... one -e per token in the SETUP CHECKLIST
     /tmp/install/004.sql
   ```
3. **Verify** before applying. The working copy must pass:
   ```bash
   grep -E "(_PLACEHOLDER|CLIENT_[A-Z])" /tmp/install/004.sql && echo "NOT READY"
   ```
   That command must produce *no* matches (and therefore not print
   "NOT READY"). If anything matches, finish substituting first.
4. **Apply via the Supabase MCP tool** against the install project. Do
   not pipe the substituted copy through `supabase db push`, and do not
   commit it back to the repo (see next section).

## Install-specific migrations: do not push to repo

After substitution, the resulting SQL contains hardcoded UUIDs and PII
(agency name, tax ID, email, phone, etc.). Per the established invariant:

- Substituted copies apply via the Supabase MCP tool only.
- They stay out of git entirely. Either keep the working copy under
  `/tmp/` and discard after applying, or store outside the repo (e.g.
  `~/installs/<agency-id>/`).
- The repo carries only the placeholder template.

If a substituted copy appears in this repo (filename like
`<n>_..._<agency>.sql` containing real UUIDs or PII), it was committed in
error. Replace its content with the placeholder template, or move it out
of `supabase/migrations/` if it serves another purpose.

## Related convention: `.template.sql` (master template repo)

The master template repo (`bcc-master-template`) uses an additional
convention for files where in-file token substitution is impractical: a
`.template.sql` filename suffix (e.g.
`014_seed_canonical_recipes.template.sql`). The install repo receives a
substituted, renamed copy (e.g. `014_seed_canonical_recipes_godley.sql`).

This is a sibling convention to the in-file token mechanism documented
above and is used only in the master template. Install repos use the
in-file token mechanism.

## Related installer: `supabase/seed/seed_bcc_automations.sql`

Once `004` has been applied (agency record exists), the generic seeder
function `seed_bcc_automations(p_agency_id uuid, p_config jsonb,
p_payroll_variant text)` provisions the canonical 14-recipe automation
suite for that agency. It is parameter-driven and contains **no in-file
placeholders** — it is normal DDL, just shelved under `supabase/seed/`
rather than `supabase/migrations/` because it is a tooling-scoped
installer function rather than a versioned schema change.

## See also

- `supabase/migrations/004_seed_agency_record.sql` — placeholder exemplar
- `supabase/seed/seed_bcc_automations.sql` — generic automation seeder
- `CLAUDE.md` — broader install conventions and invariants
