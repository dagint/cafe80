# Tailscale: RustDesk host on your tailnet (one-way access)

This host can be joined to your tailnet so you can reach it from other Tailscale devices (SSH, admin) without opening extra ports. The host should **not** be allowed to initiate connections to other tailnet resources.

## 1. Join the host

- Create a **tagged** auth key in [Tailscale Admin](https://login.tailscale.com/admin/settings/keys):
  - Tag: `tag:rustdesk-server` (or e.g. `tag:servers`)
  - Reusable: no (one-time use for this machine)
- On the VPS (one-time), run:
  ```bash
  TAILSCALE_AUTHKEY=tskey-auth-xxxx ./scripts/hardening/ubuntu-tailscale.sh
  ```
  Or add `TAILSCALE_AUTHKEY` to your `.env` and sync to GitHub; use it in a one-time setup step or runbook (never commit the key).

## 2. ACL: others can reach this host; this host cannot reach others

In **Tailscale Admin → Access controls**, define ACLs so that:

- **Other** devices (e.g. your admin machines, or `autogroup:members`) can connect **to** this host.
- This host (**tag:rustdesk-server**) has **no** rules where it is the **source** of traffic to other tailnet IPs. Deny-by-default then blocks outbound from this host to the rest of the tailnet.

Example (adjust groups/tags to match your tailnet):

```json
{
  "acls": [
    {
      "action": "accept",
      "src": ["autogroup:members"],
      "dst": ["tag:rustdesk-server:*"]
    }
  ],
  "tagOwners": {
    "tag:rustdesk-server": ["autogroup:admin"]
  }
}
```

- Only `autogroup:members` can connect to machines tagged `rustdesk-server` (all ports). Tighten by replacing `*` with a port list, e.g. `["tag:rustdesk-server:22", "tag:rustdesk-server:21115-21119"]`.
- There is **no** rule with `"src": ["tag:rustdesk-server"]`, so this host cannot open connections to other tailnet devices.

Result: the RustDesk VPS is reachable from your tailnet (e.g. SSH over Tailscale, or RustDesk relay via Tailscale IP), but the VPS cannot access other tailnet resources.

## 3. Using the host over Tailscale

- **SSH**: From any tailnet device, `ssh deploy@<rustdesk-tailscale-name-or-ip>` (no need to expose SSH on the public internet if you prefer).
- **RustDesk**: Public clients still use `RUSTDESK_RELAY_HOST` (public IP/domain). Tailnet clients can optionally use the host’s Tailscale hostname as ID/Relay server for traffic over the tailnet.
