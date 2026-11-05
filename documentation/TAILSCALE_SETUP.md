# GitHub Actions + Tailscale + Attic Cache Setup

This guide walks you through enabling GitHub Actions to access muninn's Attic binary cache via Tailscale.

## Overview

The CI workflow now:
1. Joins your Tailscale network via **Workload Identity Federation** (ephemeral GitHub OIDC token)
2. Verifies muninn is reachable
3. Authenticates to the Attic cache with a scoped token
4. Speeds up builds with the binary cache
5. Auto-pushes build outputs back to the cache

**Security:** No long-lived secrets in GitHub; each workflow run gets a unique ephemeral token.

---

## Setup (4 steps, ~5 minutes)

### Step 1: Create Tailscale OIDC Credential (Part A: Settings)

1. Go to [Tailscale Admin Console → Settings → OAuth clients](https://login.tailscale.com/admin/settings/oauth)
2. Click **+ Add credential**
3. Select **OpenID Connect** (should be the default selection on the right)
4. Fill in the form:
   - **Description:** `GitHub runner ci` (or similar)
   - **Issuer:** Select `GitHub` from the dropdown (Issuer URL auto-fills to `https://token.actions.githubusercontent.com`)
   - **Subject:** `repo:amatos:367718/magnanix@1435869087:*`
5. Click **Continue** to proceed to Step 1B (Scopes)

### Step 1B: Create Tailscale OIDC Credential (Part B: Scopes)

On the Scopes screen:

1. Under **Devices**, check `auth_keys` (writable) — this allows the credential to create ephemeral devices
2. Click the **Tags** section and add: `tag:ci`
3. Click **Create credential**

Once created, you'll see the **Client ID**. Copy it — you'll need it for Step 2.

### Step 2: Add GitHub Secrets

1. Go to your repo's **Settings → Secrets and variables → Actions**
2. Create three new secrets:

| Secret Name | Value |
|---|---|
| `TS_OAUTH_CLIENT_ID` | Client ID from Step 1B |
| `TS_AUDIENCE` | `https://api.tailscale.com` |
| `ATTIC_TOKEN` | Generate in Step 3 |

### Step 3: Generate Attic Token on muninn

1. SSH into muninn:
   ```bash
   ssh muninn
   ```

2. Generate a token (recommended: allow push):
   ```bash
   sudo atticd-atticadm make-token --sub ci-github --validity "1y"
   ```
   
   Or if you prefer pull-only access:
   ```bash
   sudo atticd-atticadm make-token --sub ci-github --pull-only --validity "1y"
   ```

3. Copy the token output and paste it as the `ATTIC_TOKEN` secret in Step 2

### Step 4: Apply Tailscale ACL

1. Go to [Tailscale Admin Console → ACLs](https://login.tailscale.com/admin/acls)
2. Open the `documentation/tailscale-policy/acl.hujson` file from this repo
3. Copy the entire JSON content
4. Paste into the admin console's ACL editor
5. Click **Save and apply**

---

## Verify Setup

Once all 4 steps are complete:

1. Go to **Actions** tab in GitHub
2. Click **Update flake inputs** → **Run workflow**
3. Watch the logs for:
   - ✅ "Joined Tailscale"
   - ✅ "muninn.ts.matos.cc is reachable"
   - ✅ "Successfully authenticated to Attic"
   - ✅ PR created with updated `flake.lock` and `flake.nix`

4. Optional: SSH to muninn and check cache:
   ```bash
   attic cache list
   ```

---

## How It Works

```
GitHub Actions starts
  ↓
GitHub provides ephemeral OIDC token
  ↓
Tailscale action exchanges OIDC token for Tailscale device credentials
  ↓
Runner joins Tailscale as tag:ci ephemeral node
  ↓
Tailscale ACL permits only access to muninn:8080
  ↓
Runner authenticates to Attic cache
  ↓
Nix builds use cache for downloads
  ↓
Build outputs are pushed back to cache
  ↓
Workflow completes, ephemeral node logs out
```

---

## Troubleshooting

### "invalid OIDC token"
- **Cause:** Subject in Tailscale credential doesn't match your repo path
- **Fix:** Verify Subject is exactly `repo:amatos:367718/magnanix@1435869087:*` in your credential settings

### "failed to connect to muninn.ts.matos.cc:8080"
- **Cause:** ACL not applied, or muninn offline
- **Fix:** Check ACL is saved in Tailscale console; verify muninn is connected

### "requested tags [tag:ci] are invalid"
- **Cause:** Credential missing `tag:ci` tag or doesn't have `auth_keys` scope
- **Fix:** Edit the credential in Tailscale console and ensure both are set

### "invalid authentication token"
- **Cause:** `ATTIC_TOKEN` is empty, wrong, or expired
- **Fix:** Regenerate with `atticd-atticadm make-token` on muninn; update GitHub secret

---

## Security Notes

✅ **No long-lived secrets**
- GitHub's OIDC token is ephemeral (valid ~5 minutes per workflow run)
- Different token for each run; can't be reused

✅ **Scoped access**
- ACL restricts `tag:ci` to muninn:8080 only
- CI can't reach other machines or services

✅ **Scoped Attic token**
- Can be made pull-only if desired
- 1-year TTL; easy to rotate

---

## Files Modified

- `.github/workflows/update-flake-lock.yml` — Workflow now joins Tailscale + uses Attic
- `documentation/tailscale-policy/acl.hujson` — Version-controlled ACL policy

## References

- [Tailscale GitHub Action + Workload Identity Federation](https://github.com/tailscale/github-action#workload-identity-federation)
- [Tailscale ACL documentation](https://tailscale.com/kb/1018/acls/)
- [Attic binary cache documentation](https://docs.attic.rs/)
