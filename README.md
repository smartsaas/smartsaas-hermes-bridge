# SmartSaaS ↔ Hermes platform bridge

Telegram-style messaging platform plugin for [Hermes Agent](https://hermes-agent.nousresearch.com/).

Hermes dials **out** to SmartSaaS (long-poll). No public URL is required on the machine running Hermes — works from home while you use SmartSaaS on the go.

## Install

```bash
git clone https://github.com/smartsaas/smartsaas-hermes-bridge.git
cd smartsaas-hermes-bridge

# 1. Platform plugin
mkdir -p ~/.hermes/plugins
cp -R plugins/smartsaas ~/.hermes/plugins/smartsaas

# 2. Optional: SmartSaaS product skill (API tools)
mkdir -p ~/.hermes/skills
cp -R skills/smartsaas ~/.hermes/skills/smartsaas

# 3. Env (Integrations → Hermes → Issue bridge token)
cat >> ~/.hermes/.env <<'EOF'
SMARTSAAS_BASE_URL=https://api.smartsaas.pro
SMARTSAAS_BRIDGE_TOKEN=paste-token-from-smartsaas
# Optional — for skill scripts:
# SMARTSAAS_API_KEY=your-protected-api-key
SMARTSAAS_ALLOW_ALL_USERS=true
EOF

# 4. Enable plugin + start gateway
hermes plugins enable smartsaas --no-allow-tool-override
hermes gateway run
```

For local SmartSaaS backend development use `SMARTSAAS_BASE_URL=http://localhost:4000`.

**One active gateway per bridge token.** Multiple machines with the same token compete for the same inbox.

## How it works

| Direction | Path |
|-----------|------|
| SmartSaaS → Hermes | User chat / orchestrator enqueues → adapter `POST …/bridge/poll` |
| Hermes → SmartSaaS | Adapter `send()` → `POST …/bridge/reply` → app socket `hermes:message` |
| Skill tools | Shell scripts → `/api/protected/*` with `SMARTSAAS_API_KEY` |

## Bridge API (adapter)

- `POST /api/protected/hermes/bridge/heartbeat` — mark online
- `POST /api/protected/hermes/bridge/poll` — long-poll inbox
- `POST /api/protected/hermes/bridge/reply` — deliver agent reply
- `POST /api/protected/hermes/bridge/typing` — typing indicator

Auth: `Authorization: Bearer <SMARTSAAS_BRIDGE_TOKEN>`

## License

MIT
