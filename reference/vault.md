# 🔐 HashiCorp Vault Master CLI Cheat Sheet (2026)

> **The complete guide for Developers, DevOps, and Security Administrators.**

---

## 🏗️ 1. Environment & Setup
Before running commands, ensure your CLI is pointing to the correct server.

| Variable | Description |
| :--- | :--- |
| `export VAULT_ADDR='https://127.0.0.1:8200'` | Sets the Vault server address. |
| `export VAULT_TOKEN='hvs.xxxxxx'` | Manually sets the access token (not recommended for production). |
| `export VAULT_SKIP_VERIFY=true` | Skips TLS verification (Dev/Local only!). |
| `vault version` | Check CLI and Server version. |

---

## 🔑 2. Authentication & Tokens
| Command | Usage |
| :--- | :--- |
| `vault login` | Standard login (Prompts for token). |
| `vault login -method=userpass` | Login via username/password. |
| `vault login -method=oidc` | Browser-based SSO login. |
| `vault token lookup` | See TTL and policies of current session. |
| `vault token renew` | Extend the life of a renewable token. |
| `vault token create` | Create a child token (useful for CI/CD). |
| `vault auth list` | View all enabled authentication methods. |
| `vault auth enable <type>` | Enable a method (e.g., `aws`, `github`, `kubernetes`). |
| `vault logout` | Revoke local session. |

---

## 📦 3. Key-Value (KV) Secrets Management
*Note: These commands assume KV Version 2 (the current standard).*

| Action | Command |
| :--- | :--- |
| **Write Secret** | `vault kv put secret/apps/web user="admin" pass="pw123"` |
| **Read Secret** | `vault kv get secret/apps/web` |
| **Get Field** | `vault kv get -field=pass secret/apps/web` |
| **List Keys** | `vault kv list secret/apps/` |
| **View Version** | `vault kv get -version=2 secret/apps/web` |
| **Patch Secret** | `vault kv patch secret/apps/web new_key="value"` |
| **Soft Delete** | `vault kv delete secret/apps/web` |
| **Perm. Delete** | `vault kv destroy -versions=1,2 secret/apps/web` |
| **Undelete** | `vault kv undelete -versions=1 secret/apps/web` |

---

## 📜 4. Policy & Access Control
Policies are HCL files that define permissions.

| Command | Description |
| :--- | :--- |
| `vault policy write <name> <file>.hcl` | Upload/Update a policy. |
| `vault policy list` | List all available policies. |
| `vault policy read <name>` | Display the HCL content of a policy. |
| `vault policy delete <name>` | Remove a policy. |

---

## ⚙️ 5. Secrets Engines (Dynamic & Shared)
| Command | Description |
| :--- | :--- |
| `vault secrets list` | View all enabled engines. |
| `vault secrets enable <type>` | Enable (e.g., `pki`, `transit`, `database`). |
| `vault secrets disable <path>` | Disable and wipe data at that path. |
| `vault secrets tune` | Change default TTLs or max TTLs for an engine. |
| `vault write <path> @config.json` | Configure engine settings via JSON/HCL. |

---

## 🛠️ 6. Operator & Admin (The "Pro" Section)
High-level cluster maintenance and disaster recovery.

| Command | Description |
| :--- | :--- |
| `vault status` | Check seal status, HA mode, and node ID. |
| `vault operator init` | **First-time setup:** Generates unseal keys. |
| `vault operator unseal` | Enter a key shard to open the Vault. |
| `vault operator seal` | Immediate lock down (Emergency use). |
| `vault operator raft snapshot save <file>.snapshot` | Backup the database. |
| `vault operator raft list-peers` | View all cluster members. |
| `vault operator step-down` | Force the leader to give up control (for updates). |
| `vault monitor` | Watch server logs in real-time. |
| `vault debug` | Capture system info for support/troubleshooting. |

---

## 🏢 7. Enterprise & Advanced Features
| Command | Description |
| :--- | :--- |
| `vault namespace create <name>` | Create an isolated environment (Enterprise). |
| `vault namespace list` | Show all active namespaces. |
| `vault read sys/replication/status` | Check Disaster Recovery/Performance health. |
| `vault lease lookup <lease_id>` | Check status of dynamic secrets (e.g., AWS/SQL creds). |
| `vault audit enable file file_path=/var/log/vault.log` | Enable request logging. |

---

## 💡 8. Global Flags & Shortcuts
* `-format=json`: Output data for `jq` parsing.
* `-format=yaml`: Output data in YAML.
* `-field=<name>`: Extract a single value.
* `vault path-help <path>`: The **built-in documentation** for any API path.
