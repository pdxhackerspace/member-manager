# Member Zone rename — deploy notes

Reference for the Member Manager → Member Zone rename. Delete once every environment is
past it.

## Blocking — do before deploying

- **Set `DATABASE_FIELD_ENCRYPTION_KEY` and `EMAIL_LOOKUP_HMAC_KEY` explicitly in every
  environment.** The `SensitiveData` key-derivation salts changed from `member-manager-*`
  to `member-zone-*`. The salts only apply when a variable is unset and the key is derived
  from `secret_key_base` — an environment on that fallback gets different keys after the
  deploy and cannot decrypt its own data or match any email lookup digest. Neither variable
  was previously in any `.env` example, so assume the fallback is in use until verified.
  See [encrypted-fields.md](encrypted-fields.md).
- **Rename the OIDC scope in Authentik to `member_zone_admin`.** `config/initializers/omniauth.rb`
  requests the new name. Admin login breaks until Authentik matches.
- **Point deploy targets at the renamed image**, `ghcr.io/<owner>/member-zone`. The old path
  stops receiving builds.
- **Run migrations.** `20260806000000_rename_member_manager_source_key_to_member_zone`
  moves `member_sources.key` from `member_manager` to `member_zone`. Data-only, reversible.

## Non-blocking — do soon

- **Rename the four Authentik webhook objects** to `MemberZone Webhook`, `MemberZone User
  Events`, `MemberZone Group Events`, `MemberZone Notifications`. `Authentik::WebhookSetup`
  finds them by name, so until then the old objects are orphaned and a setup run creates
  duplicates.
- **Move deployments off `MEMBER_MANAGER_BASE_URL` to `MEMBER_ZONE_BASE_URL`**, then drop
  the fallback in `config/initializers/member_zone.rb`.
- **Stale Authentik user/group attributes.** The app now writes `member_zone_id`,
  `member_zone_application`, `member_zone_group_id`, `member_zone_synced_at`. Writes merge
  rather than replace, so the `member_manager_*` keys linger. Cosmetic — nothing reads them.
- **Local dev volumes.** Compose project names changed, so named volumes get a new
  `memberzone-*` prefix and local dev/test databases start empty. Old volumes and
  `member_manager_*` images can be pruned.

## Open — deliberately not renamed

- **Staging and production database names** stay `member_manager_staging` and
  `member_manager_production` (`config/database.yml`, and the `DATABASE_URL` examples in
  `.env.staging.example` / `.env.production.example`). Renaming needs an `ALTER DATABASE`
  plus a coordinated env change. Decide whether to do it or make the old names permanent.
- **The GitHub repository** is still `pdxhackerspace/member-manager`. The workflows build
  the image name from `github.repository_owner`, not the repo name, so a repo rename is
  independent of this work.
- **Action Cable `channel_prefix`** was renamed to `member_zone_*`. Harmless, but in-flight
  connections drop at deploy.

## Backward compatibility kept in code

- `MEMBER_MANAGER_BASE_URL` still read as a fallback — `MemberZoneConfig.base_url`.
- `member-manager.role-definitions` still accepted on import — `DefinitionExport::LEGACY_FORMAT`.
- `membermanager:anonymized_export v1` still accepted on restore — `DatabaseAnonymizer::LEGACY_DUMP_MARKER`.
- Mail trace headers are now `X-MemberZone-*` with no fallback, which is fine: headers are
  set when the message is rendered at delivery time, so queued mail picks up the new names.

## Not touched

- Git history and changelogs.
- `SensitiveData` ciphertext and digests — no re-encryption pass was run.
