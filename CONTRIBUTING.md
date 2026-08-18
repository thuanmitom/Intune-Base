# Contributing

This is primarily a personal, field-tested reference — but corrections and real-world cases make it
better for everyone.

## Ground rules

1. **Accuracy over volume.** A wrong fix wastes more time than no fix. If something is
   community-reverse-engineered rather than documented, **say so** (as the docs already do for
   MMP-C internals, GRS layout, etc.).
2. **Cite the channel.** When adding a troubleshooting note, state whether it's the native MDM
   channel, the IME, or MMP-C — that context is half the value.
3. **Test scripts on a test device.** Anything that writes to the registry or restarts a service
   must be verified on a non-production device first, and should carry a safety note.
4. **Keep it current.** Intune changes fast. Note the date/build where behavior is version-specific.

## How to add a solved case

1. Copy [`templates/case-runbook-template.md`](templates/case-runbook-template.md) into a
   `cases/` folder (create it if needed), named `YYYY-MM-DD-short-title.md`.
2. Fill in the sections. **Redact secrets** from any pasted logs (tokens, keys, IVs, UPNs if
   sensitive).
3. Link it from the relevant runbook if it's a common pattern.

## Style

- Markdown, wrapped around ~100 chars where practical.
- Prefer tables for code/fix lookups, prose for concepts.
- Use fenced code blocks with a language hint (`powershell`, `cmd`, `xml`).
- Reference internal files with relative links so they work on GitHub.

## What not to include

- Secrets, real tenant IDs, real device serials/UPNs.
- Copy-pasted content from other sites — link and paraphrase instead.
