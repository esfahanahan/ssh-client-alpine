# ssh-client-alpine

OpenSSH client on Alpine 3.22 for CI jobs that would otherwise run `apk add openssh-client` on every pipeline.

This image is a client only. It does not contain `sshd`, and it does not accept SSH connections.

The base is `alpine:3.22`, pinned to the multi-arch index digest `sha256:5291449c3df73caf6ed85e649dec1b9e818b39a5d8c871e97afc13e9cd5e8fa8` (resolved 2026-10-11). That index includes `linux/amd64` and `linux/arm64`. No host keys, `known_hosts` entries, or identity files are baked in.

## Users

The default user is `ssh` (uid 1000, gid 1000). Its home is `/home/ssh`, and `/home/ssh/.ssh` is mode `700`.

The image is still usable as root. `/root/.ssh` is also mode `700`. Switch to root when a CI job has to read a root-owned key. GitLab File variables are often mode `600` and owned by root, which the `ssh` user cannot read.

```bash
docker run --rm --user root ssh-client-alpine:local ssh -V
```

GitLab Runner's Docker executor accepts the same override:

```yaml
image:
  name: ghcr.io/esfahanahanbot/ssh-client-alpine:1.2.3
  docker:
    user: root
```

## Build

Single architecture, loaded into the local engine:

```bash
docker build --tag ssh-client-alpine:local .
```

`linux/amd64` and `linux/arm64` together need Buildx. A multi-arch image cannot be loaded into the local engine with `--load`; push it to GHCR (a public registry) or build one platform for a local run.

```bash
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --tag ghcr.io/esfahanahanbot/ssh-client-alpine:1.2.3 \
  --push \
  .
```

Version tags such as `v1.2.3` build both platforms in GitHub Actions and push to GHCR (`ghcr.io/<owner>/<repo>`) and Docker Hub (`<namespace>/ssh-client-alpine`) with provenance. Neither registry is private. GitHub may create the package as private on the first push; set the package visibility to public if the repository is public. On Docker Hub, confirm the repository is public after the first push.

## Usage

The default command is `ssh`. `scp`, `ssh-keygen`, `ssh-agent`, and `ssh-add` are on `PATH`.

`ssh -F` is the only config OpenSSH reads. `/etc/ssh/ssh_config` and `~/.ssh/config` are ignored, so each file in `/etc/ssh/profiles/` is a complete config. Profiles do not set a port. The default stays 22. Pass `ssh -p` or `scp -P` yourself.

`BatchMode yes` is set on every profile. OpenSSH then refuses to prompt for a password, a passphrase, or a host-key confirmation. A missing key, a key that needs a passphrase, or a rejected host fails the process immediately instead of waiting.

If the first argument is `ssh`, `scp`, `ssh-keygen`, `ssh-agent`, `ssh-add`, or `sh`, the entrypoint executes it unchanged. `SSH_PROFILE` is not applied in that case; pass `-F` yourself. For any other arguments, the entrypoint runs `ssh`, and `SSH_PROFILE=skip-host-check` becomes `ssh -F /etc/ssh/profiles/skip-host-check`.

Strict profile, non-default port, private key mounted read-only. The key file on the host must be mode `600`. Root is used here because a `600` key owned by another uid is not readable by the `ssh` user.

```bash
docker run --rm \
  --user root \
  --volume "$PWD/id_ed25519:/run/secrets/id_ed25519:ro" \
  ssh-client-alpine:local \
  ssh -F /etc/ssh/profiles/strict \
    -i /run/secrets/id_ed25519 \
    -p 2222 \
    user@203.0.113.10 \
    true
```

The same profile selected by the entrypoint, without putting `ssh` first:

```bash
docker run --rm \
  --user root \
  --env SSH_PROFILE=strict \
  --volume "$PWD/id_ed25519:/run/secrets/id_ed25519:ro" \
  ssh-client-alpine:local \
  -i /run/secrets/id_ed25519 \
  -p 2222 \
  user@203.0.113.10 \
  true
```

`scp` accepts `-F` as well. Its port flag is `-P`.

```bash
docker run --rm \
  --user root \
  --volume "$PWD/id_ed25519:/run/secrets/id_ed25519:ro" \
  --volume "$PWD/artifact.bin:/tmp/artifact.bin:ro" \
  ssh-client-alpine:local \
  scp -F /etc/ssh/profiles/strict \
    -i /run/secrets/id_ed25519 \
    -P 2222 \
    /tmp/artifact.bin \
    user@203.0.113.10:/tmp/artifact.bin
```

GitLab CI, with a File-type variable `DEPLOY_KEY`. GitLab stores the key in a temp file and sets the variable to that path. Clear the entrypoint so the job shell runs. `BatchMode` makes a missing or unreadable key fail the job.

```yaml
deploy:
  image:
    name: ghcr.io/esfahanahanbot/ssh-client-alpine:1.2.3
    entrypoint: [""]
    docker:
      user: root
  script:
    - ssh -F /etc/ssh/profiles/skip-host-check -i "$DEPLOY_KEY" -p 2222 user@203.0.113.10 true
    - scp -F /etc/ssh/profiles/skip-host-check -i "$DEPLOY_KEY" -P 2222 artifact.bin user@203.0.113.10:/tmp/artifact.bin
```

### Profiles

| Profile | `-F` path | Behavior |
| --- | --- | --- |
| `strict` | `/etc/ssh/profiles/strict` | `StrictHostKeyChecking yes`. Refuses unknown hosts and never prompts. This is the safe default. |
| `accept-new` | `/etc/ssh/profiles/accept-new` | Trust on first use. Writes `~/.ssh/known_hosts` for the user that runs `ssh`. A changed key still fails. |
| `skip-host-check` | `/etc/ssh/profiles/skip-host-check` | `StrictHostKeyChecking no` and `UserKnownHostsFile /dev/null`. This trusts whatever answers at that address. It exists so a deploy does not hang on "Are you sure you want to continue connecting". |
| `batch` | `/etc/ssh/profiles/batch` | Never prompts, and sends keepalives. Use it when the job already has a `known_hosts` file. Unknown hosts still fail, because `BatchMode` cannot confirm them. |

There is no jump-host profile. A bastion belongs in the caller's own complete `-F` file, via `ProxyJump`. That file replaces the system config, so copy in the options you still need:

```
Host *
    ProxyJump bastion.example
    StrictHostKeyChecking yes
    BatchMode yes
    ConnectTimeout 10
    IdentitiesOnly yes
```

```bash
ssh -F /path/to/that-file -p 2222 user@203.0.113.10
```
