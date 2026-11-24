# Fork changes (ETech-Nepal/JeMPI vs. upstream jembi/JeMPI)

This fork is upstream JeMPI at commit `f5cc0ac2` (2025-04-16) plus 7 commits that adapt the **single-node "low" Docker Swarm deployment** to run on one small server, behind an HTTPS edge proxy. No application logic was changed except one Jackson annotation. Hardware numbers and domain examples below come from the config diffs.

16 files changed, +161 / -262 lines.

## Main reason

JeMPI is hosted on the same server as another project (identity-mediator), and **everything is exposed through a single edge Caddy**. Most changes follow from that: no published host ports, services reached over the shared `frontend` network, a loopback-only registry, a public-domain/HTTPS switch for Keycloak, and scripts that no longer touch anything outside JeMPI's own stack (no host-wide `docker prune`, stack matching scoped to `jempi_*`).

**Target and scope:** this is a **demo** deployment, sized for a v4 machine with **8 GB RAM and 50 GB disk**. That is why memory limits are low and heavy optional services are off.

## Summary

| Goal | What changed |
|------|--------------|
| Stop depending on Bitnami images | Official Kafka, Postgres and Keycloak images |
| Fit on a small machine | Lower RAM limits, smaller Dgraph cache, Ratel and EM disabled |
| Expose nothing directly | No published ports; an edge Caddy (separate stack) reverse-proxies over the `frontend` network |
| Public HTTPS + Keycloak login | `PUBLIC_DOMAIN` switch, `KC_HOSTNAME`, proxy headers |
| Better matching on this dataset | Link config uses `dob` and `gender` instead of `city` |
| Make the scripts safer and more portable | Any JDK 21, no host-wide `docker prune`, loopback-only registry |

## Changes by commit

### `a048d275` chore: replace Bitnami images with official Kafka/Postgres/Keycloak, trim low stack, fix NODE1_IP
- **Images** (`conf/images/conf-hub-images.sh`): `bitnami/keycloak:21.1.2` → `quay.io/keycloak/keycloak:26.7.2`, `bitnami/kafka:3.7` → `apache/kafka:3.9.0`, `bitnami/postgresql:15.5.0` → `postgres:16-alpine`.
  *Why:* Bitnami pulled its free public images, so the old tags can no longer be pulled.
- **Stack files** (`docker-stack-low-0.yml`, `docker-stack-low-1.yml`):
  - Env vars and mount paths rewritten for the new images (`POSTGRES_*`, `/var/lib/postgresql/data`; Kafka `KAFKA_CFG_*` → `KAFKA_*`, data dir `/var/lib/kafka/data`; Keycloak `KC_*` with `start-dev`).
  - Kafka internal-topic replication factors set to 1 (single broker cannot satisfy 3).
  - Keycloak healthcheck uses a bash `/dev/tcp` probe because the official image has no `curl`.
  - Dgraph alpha cache `4096` MB → `512` MB; EM Scala `replicas: 1` → `0`.
- **Postgres data dir owner** (`d-stack-create-dirs.sh`): `chown 1001:1001` → `70:70` (uid of the alpine `postgres` user).
- **`create-env-linux-low-1.sh`**: RAM limits cut from 8–16 GB per service to 256 MB–2 GB; `SCALE_RATEL=0`.
  *Why:* the original limits assume a large multi-node server; the demo host has only 8 GB RAM in total, shared with the other project.
- **`NODE1_IP`**: `hostname -i` → `hostname -I | awk '{print $1}'` (`-i` can return `127.0.1.1` on Debian-style hosts). Applied to the low and high env scripts.

### `c88fc9cc` build: accept any JDK 21, drop host-wide docker prune, skip sbt EM and tests
- `build-check-jdk.sh`: compares only the major version, so `21.0.x` builds are accepted instead of requiring the exact patch version.
- `build-app-image.sh`, `d-stack-create-dirs.sh`: removed `docker system prune --volumes`.
  *Why:* it deleted unrelated containers, images and volumes on a shared host.
- `build-all-java.sh`: `mvn clean package -DskipTests`; the Scala **EM** (M/U recalculation) module is no longer built or pushed, since it needs `sbt` and is scaled to 0 replicas in the stack.

### `f40af575` feat: admin portal behind edge Caddy, loopback ports
- Removed every `ports:` publish from the low stack (Postgres, HAProxy, Zero, Alpha, Ratel). HAProxy is now reached only through the shared `frontend` network by an edge Caddy running in a separate stack.
- `create-env-linux-low-1.sh`: new optional `PUBLIC_DOMAIN` switch. When set, it points Keycloak (`jempi-auth.<domain>`), the UI and API (`jempi.<domain>`) at HTTPS and enables secure session cookies. When unset, the old `IP:port` setup is used (Keycloak URL moved from `:8080` to `:8084`).
- `c-registry-1-create.sh`: the local registry changed from a Swarm service published on all interfaces to a plain container bound to `127.0.0.1:5000`; `REGISTRY_NODE_IP` is now `localhost:5000/v2`.
  *Why:* nothing but the local Docker daemon should be able to reach the registry or the databases.

### `fe8b0b99` fix: apply no-published-ports and KC_HOSTNAME to low-0 stack and deployment/common registry script
Same stack edits as above applied to `docker-stack-low-0.yml` (the "scaled to 0" variant used when bringing the stack up in stages) and to `deployment/common/c-registry-1-create.sh`, which are copies of the files in the commit above. Adds `KC_HOSTNAME: ${KC_FRONTEND_URL}` and `KC_PROXY_HEADERS: xforwarded` so Keycloak issues tokens with the public URL as issuer behind the proxy.

### `31462ab6` feat: use the identity-mediator link config (dob/gender rules, dob trigram index); registry localhost fixes
**Matching config** — changed in `devops/linux/docker/data-config/config-reference-link-dp.json`. This is a **permanent** change for our own requirements, not a demo-only tweak: the link rules use `dob` and `gender` instead of `city`, with a trigram index added on `dob`. Details:

- Deterministic rule 2 now matches on `given_name + family_name + dob + phone_number + gender` (was without `dob`/`gender`).
- Probabilistic rule uses `dob` instead of `city`.
- Added `indexGoldenRecord` / `indexInteraction` trigram indexes to the `dob` field (`csvCol: 4`) so the new `match(dob,3)` rule can run.
- Formatting only: `comparisonLevels` collapsed to one line; `u` values rewritten in scientific notation (`0.0000465` → `4.65e-5`, same numbers).
- `keycloak/realms/import.sh`: Keycloak no longer has a host port, so the realm import runs `curl` from a throwaway `curlimages/curl` container on the `frontend` network.
  *Why:* the config is aligned with our requirements and the identity-mediator project, which supplies dob/gender and not city.

### `9f3c3359` fix: ignore unknown fields (iss) in the Keycloak login payload
`JeMPI_API_KC/.../OAuthCodeRequestPayload.java`: added `@JsonIgnoreProperties(ignoreUnknown = true)`.
*Why:* Keycloak 22+ adds `iss` (RFC 9207) to the login redirect and the UI forwards every query parameter, so the API rejected the login request with an unknown-property error. This is the only Java source change.

### `53543aff` fix: script for low pc
Script fixes so the stack can be created and removed cleanly on the low-spec (8 GB / 50 GB) shared host:
- `d-stack-rm.sh`: `docker stack rm` failure no longer aborts the caller (the shared `frontend` network legitimately stays while Caddy / identity-mediator are attached).
- `d-stack-wait-removed.sh`: container match is scoped to `<stack>_<service>.` so `api` no longer matches other stacks such as `hapi-db`.

## Things to know before deploying
- Keycloak runs in `start-dev` mode with `admin/admin` bootstrap credentials: **demo only**. Switch to `start` with a hostname and real credentials before any production use.
- Ratel is off to save RAM. EM Scala (M/U recalculation) is off and removed from the build; it needs to be revisited **after proper data analysis**, then re-enabled with its replica count and RAM limit.
- The current `m`/`u` values in the link config are the upstream defaults and have not been re-estimated for our data.
- The edge Caddy and identity-mediator stacks are **not** in this repo; the low stack expects them to join the `frontend` network.
- Only the "low" stack and common scripts were changed; the "high" (multi-node) stack was touched only for `NODE1_IP`.
