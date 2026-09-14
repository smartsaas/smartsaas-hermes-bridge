---
name: smartsaas
description: "SmartSaaS product APIs for Hermes. Install under ~/.hermes/skills/smartsaas. Env: SMARTSAAS_BASE_URL, SMARTSAAS_API_KEY. Run scripts via terminal — never curl with pasted keys."
requires:
  env:
    - SMARTSAAS_BASE_URL
    - SMARTSAAS_API_KEY
  bins:
    - python3
---

# SmartSaaS Skill (Hermes)

Use this skill when the user asks to create datasets, projects, knowledge, campaigns, agents, or other SmartSaaS product actions **from Hermes**.

This is **not** the messaging bridge. The Telegram-style bridge is the `smartsaas` **platform plugin** (`~/.hermes/plugins/smartsaas`). This skill gives Hermes shell tools into `/api/protected/*`.

## Install

```bash
cp -R skills/smartsaas ~/.hermes/skills/smartsaas
# in ~/.hermes/.env:
# SMARTSAAS_BASE_URL=https://api.smartsaas.pro
# SMARTSAAS_API_KEY=<protected API key from SmartSaaS>
```

## Rules

- Run scripts in `scripts/` via the terminal tool. **Never** ask the user for an API key in chat.
- Scripts need `SMARTSAAS_BASE_URL` and `SMARTSAAS_API_KEY` in the environment.
- Do **not** auto-add dataset items unless the user explicitly asks.
- Positional args only for create/add dataset scripts (same as OpenClaw SmartSaaS skill).

## Example

```bash
./scripts/create-dataset.sh "investor-list" "" '{"dataTitle":"investor-list","dataSchema":{"fields":[{"name":"Name","type":"string"}]},"dataTags":["customers"]}'
```

See script names under `scripts/` for datasets, projects, knowledge, CRM, AI helpers, and more.
