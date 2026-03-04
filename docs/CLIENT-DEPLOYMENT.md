# Client deployment: unattended access and security

How to set up **unattended connections** for servers and workstations you support, and how to ensure **Enable remote configuration modification** is never enabled (and stays off).

---

## 1. Unattended connections

Unattended access means you can connect **without** someone at the machine clicking “Allow.” The client must have a **permanent password** set.

### Per machine (manual)

1. Install RustDesk on the server/workstation and point it to your RustDesk server (ID/Relay + Key).
2. In the client: **Settings → Security** (or **General**) → set **Remote password** (permanent password).
3. Save. You can now connect from your tech client using the machine’s **ID** and this **password**.
4. Add the machine to your **address book** (ID + optional alias) so you don’t have to retype it.

### Per machine (scripted / RMM)

After installing RustDesk and applying your server config:

- **Windows (PowerShell):**
  ```powershell
  & "$env:ProgramFiles\RustDesk\rustdesk.exe" --password "YourSecurePassword"
  ```
- **Linux/macOS:**
  ```bash
  rustdesk --password 'YourSecurePassword'
  ```
  (May need to run as the user who runs the GUI client, or with appropriate permissions.)

Use a **strong, unique password per machine** (or per group) and store it in your password manager or RMM. Avoid plain-text passwords in shared scripts; use your RMM’s secret store or a similar mechanism.

### Mass deployment (PowerShell example)

The [RustDesk client deployment docs](https://rustdesk.com/docs/en/self-host/client-deployment/) include a PowerShell script that:

- Downloads and installs RustDesk.
- Applies your server config (config string).
- Sets a permanent password (variable `rustdesk_pw`).
- Outputs the machine’s **ID** and **password** so you can add it to your address book or asset DB.

Adapt that script: set `rustdesk_pw` from your secret store, and never commit passwords to the repo.

---

## 2. Ensure “Enable remote configuration modification” is never enabled

This setting (**Settings → Security → Permissions → Enable remote configuration modification**) lets the **remote** tech change the **controlled** machine’s RustDesk settings (including security options). You want it **off** so remote users cannot turn it on or weaken security.

### Default and option name

- **Default:** **Off** (`N`) in the RustDesk client.
- **Option name:** `allow-remote-config-modification`.  
  Values: `Y` (allow) or `N` (disallow).

So a **fresh install** starts with it disabled. The risk is someone (or a bad actor) enabling it later.

### How to keep it disabled

| Approach | What to do |
|----------|------------|
| **Policy** | Document: “Do not enable ‘Enable remote configuration modification’ on any managed machine.” Train techs and check during audits. |
| **Set explicitly after install** | After installing/configuring RustDesk, force it off: `rustdesk --option allow-remote-config-modification N` (Windows: full path to `rustdesk.exe`; Linux/macOS: `rustdesk`). Run as the user that runs RustDesk. |
| **Post-deploy verification** | In your deployment or RMM script, after install + config + password, run the same `--option allow-remote-config-modification N` so every deployed machine is set to N. |
| **Periodic enforcement (optional)** | A scheduled task or RMM job that runs e.g. daily: `rustdesk --option allow-remote-config-modification N`. That way even if someone toggled it, it gets turned off again. |

### Important caveat (OSS)

- **RustDesk OSS** does not support locking this via a config file that is guaranteed to survive: the client may overwrite or ignore pre-deployed config on launch in some versions.
- So **do not rely only on a pre-deployed config file**. Use **default (N) + policy + post-install and/or periodic `--option allow-remote-config-modification N`** so it is never effectively “deployed” as enabled.
- There are **reported bugs** where the setting could be changed remotely (e.g. via keyboard) even when disabled. Treat this as defense-in-depth: keep it off, enforce with script/task, and monitor.

### Pro / custom clients

- **RustDesk Server Pro** can enforce this via **Control Roles** (restrict “Remote configuration modification” for roles).
- If you build a **custom client** (e.g. with a client builder), set the default for this option to **N** in the build so new installs never ship with it enabled.

---

## 3. Suggested deployment checklist (per machine)

1. Install RustDesk and apply your **ID/Relay server** and **Key** (config string or manual).
2. Set **permanent password** for unattended access (UI or `rustdesk --password ...`).
3. Run **`rustdesk --option allow-remote-config-modification N`** (or your OS equivalent) so remote config modification is off and explicitly set.
4. Add the machine to your address book (ID + alias).
5. (Optional) Add a scheduled task / RMM job to re-apply `allow-remote-config-modification N` periodically.

This keeps unattended access under your control and ensures “Enable remote configuration modification” is not enabled and is re-enforced over time.
