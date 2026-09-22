# Developer Documentation

Technical reference for setting up, building, and working on this stack. It covers
prerequisites, initial setup, Makefile usage, the underlying `docker compose`
commands, and how data persistence is wired up.

## 1. Project structure

The `Makefile` points at `src/docker-compose.yml`, so the compose file and
everything it references (build contexts, `.env`) live under a `src/` subfolder:

```
.
├── Makefile
└── src/
    ├── docker-compose.yml
    ├── .env
    ├── data/
    │   ├── wordpress/
    │   └── ngnix/logs/
    └── requirements/
        ├── mariadb/
        │   ├── Dockerfile
        │   ├── conf/my.cnf
        │   └── tools/script.sh
        ├── wordpress/
        │   ├── Dockerfile
        │   ├── conf/www.conf
        │   └── tools/script.sh
        └── nginx/
            ├── Dockerfile
            ├── conf/nginx.conf
            └── tools/script.sh
```

Each service is built from its own minimal `debian:bookworm-slim` base image — there
are no pre-built DB/CMS/webserver images used, everything is built from the
`Dockerfile`s under `requirements/`.

> **Check this against your actual folder name.** The `Makefile`'s `fclean` target
> refers to images/volumes as `srcs_mariadb`, `srcs_wordpress`, `srcs_nginx` (with an
> "s"), while `COMPOSE_FILE` points at `src/docker-compose.yml` (no "s"). Docker
> Compose names images/volumes after the directory the compose file lives in, so
> these two need to agree with your real folder name (`src/` or `srcs/`) or `up`/
> `fclean` will be looking in different places.

> Note: the bind mount path is `./data/jmondelangnix/logs` (typo for "nginx" carried over
> from the compose file) — keep this in mind if you're creating the directory
> manually or scripting setup.

## 2. Prerequisites

- Docker Engine.
- The **standalone `docker-compose` binary** (v1/v2 CLI installed as `docker-compose`
  with a hyphen) — the `Makefile` calls `docker-compose -f ...` directly, not the
  newer `docker compose` plugin syntax. Make sure `docker-compose` is on your `PATH`.
- `make`.
- `sudo` access — `update-hosts` writes to `/etc/hosts` and `fclean` removes host
  directories via `sudo rm -rf`.
- A Linux host (or Docker Desktop equivalent) — MariaDB's data directory is
  initialized with `mysql_install_db` under a Linux user (`mysql`), and file
  ownership handling assumes a Linux-style filesystem.
- Enough free disk space for three images plus persisted WordPress files and the
  MariaDB data volume.

## 3. Initial setup

1. **Clone the repository** and `cd` into it (the directory containing the
   `Makefile`).

2. **Create the `.env` file** inside `src/` (next to `docker-compose.yml`, since
   `env_file: .env` in the compose file resolves relative to that file's location).
   It's read by every service and must define at least:

   ```dotenv
   # MariaDB
   MYSQL_ROOT_PASSWORD=changeme
   MYSQL_DATABASE=wordpress
   MYSQL_USER=wp_user
   MYSQL_PASSWORD=changeme

   # WordPress
   WP_TITLE=My Site
   WP_ADMIN=admin
   WP_ADMIN_PASSWORD=changeme
   WP_ADMIN_EMAIL=admin@example.com
   WP_USER=author
   WP_USER_EMAIL=author@example.com
   WP_USER_PASSWORD=changeme

   # Domain / TLS CN used by nginx and wordpress' script.sh
   USERNAME=yourlogin
   ```

   `.env` should be `.gitignore`d — it's the single source of secrets for local/dev
   deployment.

   > Set `USERNAME` here to match what you'll pass to `make` (see below) — the
   > `Makefile`'s own `USERNAME` variable only controls the `/etc/hosts` entry and
   > defaults to `jmondela` if not overridden; the containers themselves read
   > `USERNAME` from `.env`. Keep both in sync.

3. **Run `make`** (or `make up`). Unlike a plain `docker compose up`, this Makefile
   handles the host-side setup for you first:

   ```bash
   make
   ```

   This runs, in order:
   - `create-volumes` — creates `${HOME}/data/jmondelamariadb` and `src/data/jmondelawordpress` on
     the host so bind mounts have somewhere to land.
   - `update-hosts` — adds `127.0.0.1  <USERNAME>.42.fr` to `/etc/hosts` if it isn't
     already there (prompts for `sudo`).
   - `docker-compose -f src/docker-compose.yml up --build -d` — builds all three
     images and starts the stack in the background.

   No manual `mkdir` or `/etc/hosts` editing is needed — that's the point of `up`'s
   dependencies. To override the login used for the hostname without touching
   `.env`:
   ```bash
   make up USERNAME=yourlogin
   ```

## 4. Makefile usage

The project's `Makefile` is the primary interface — use these targets rather than
calling `docker-compose` by hand for anything routine:

| Target | What it does |
|---|---|
| `make` / `make all` | Alias for `up`. |
| `make up` | `create-volumes` + `update-hosts`, then `docker-compose -f src/docker-compose.yml up --build -d`. Builds and starts everything, creating host directories and the `/etc/hosts` entry first. |
| `make down` | `docker-compose -f src/docker-compose.yml down --remove-orphans`. Stops and removes containers + network (also cleans up any orphaned containers from renamed/removed services). |
| `make stop` | `docker-compose ... stop`. Stops containers without removing them. |
| `make logs` | `docker-compose ... logs`. One-shot log dump for all services (not `-f`/follow — see the raw command below if you want to tail). |
| `make clean` | Runs `down`, then `docker container prune --force` (removes any other stopped containers on the host, not just this project's). |
| `make fclean` | Runs `clean`, then **destroys persisted data**: `sudo rm -rf` on the MariaDB and WordPress host directories, `docker volume rm` on the named volumes, and `docker image rm` on all three built images plus the shared `debian:bookworm-slim` base. Use this for a genuinely clean slate. |
| `make re` | `fclean` followed by `all` — full rebuild from nothing. |
| `make create-volumes` | (internal, called by `up`) creates `${HOME}/data/jmondelamariadb` and `src/data/jmondelawordpress` on the host. |
| `make update-hosts` | (internal, called by `up`) appends `127.0.0.1  <USERNAME>.42.fr` to `/etc/hosts` if missing. |

`USERNAME` can be overridden on any invocation, e.g. `make up USERNAME=jdoe`.

`make fclean` / `make re` are destructive to your WordPress content and database —
see the caveat in §1 about the `src`/`srcs` and volume-naming mismatch before relying
on `fclean` in a script or CI, since a failing `docker volume rm` will abort the
target partway through (containers/images already removed, but the `sudo rm -rf`
line before it will still have run).

## 5. Working directly with `docker-compose`

Useful when you need finer control than the `Makefile` exposes (e.g. targeting a
single service, following logs live). All commands below assume you're running them
from the project root and referencing the compose file explicitly, matching what the
`Makefile` does:

```bash
docker-compose -f src/docker-compose.yml <command>
```

**Build/rebuild images** (needed after editing any `Dockerfile`, `conf/*`, or
`tools/script.sh`):
```bash
docker-compose -f src/docker-compose.yml build              # all services
docker-compose -f src/docker-compose.yml build wordpress    # single service
```

**Start / stop:**
```bash
docker-compose -f src/docker-compose.yml up -d              # start (no rebuild)
docker-compose -f src/docker-compose.yml up --build -d      # force rebuild before starting — same as `make up`
docker-compose -f src/docker-compose.yml stop               # stop containers, keep them — same as `make stop`
docker-compose -f src/docker-compose.yml down --remove-orphans   # same as `make down`
```

**Inspect running state:**
```bash
docker-compose -f src/docker-compose.yml ps
docker-compose -f src/docker-compose.yml logs -f [service]   # -f to follow, unlike `make logs`
```

**Shell into a running container:**
```bash
docker exec -it wordpress sh
docker exec -it mariadb sh
docker exec -it nginx sh
```

**Restart a single service after a config-only change** (e.g. edited `nginx.conf`
and rebuilt the image):
```bash
docker-compose -f src/docker-compose.yml up -d --no-deps --build nginx
```

**Full teardown including volumes** (drops the database — bind-mounted `./data/jmondela...`
content is untouched unless you delete it yourself, which is what `make fclean`'s
`sudo rm -rf` step is for):
```bash
docker-compose -f src/docker-compose.yml down -v
```

## 6. Data persistence

Persistence is split between a named Docker volume and host bind mounts, declared in
`docker-compose.yml`:

| Path in container | Type | Host location | Contains |
|---|---|---|---|
| `/var/lib/mysql` (mariadb) | named volume `mariadb` | Docker-managed by default (see note below) | Database files |
| `/var/www/html` (wordpress) | bind mount | `src/data/jmondelawordpress` | WordPress core, themes, plugins, uploads |
| `/var/www/html` (nginx) | bind mount | `src/data/jmondelawordpress` (same as above) | Nginx reads/serves the same files WordPress writes |
| `/var/log/nginx` (nginx) | bind mount | `src/data/jmondelangnix/logs` | Access/error logs |

Key implications:

- **WordPress and Nginx share the same bind-mounted directory** (`src/data/jmondelawordpress`)
  so Nginx can serve static assets and hand `.php` requests off to PHP-FPM
  (`wordpress:9000`) via `fastcgi_pass`, without needing its own copy of the files.
- The `Makefile`'s `create-volumes` target pre-creates `${HOME}/data/jmondelamariadb` on the
  host, which lines up with the **commented-out** `driver_opts` block in
  `docker-compose.yml` that would bind the `mariadb` volume to that exact path. As
  shipped, that block is commented out, so the `mariadb` volume is currently a
  standard Docker-managed volume (its data actually lives under Docker's own storage,
  not `${HOME}/data/jmondelamariadb`) — the host directory the `Makefile` creates is unused
  until you uncomment that block. If you want the DB to persist somewhere host-visible
  (e.g. for backups), uncomment `driver_opts` in `docker-compose.yml` to match what
  `create-volumes` already prepares.
- **Idempotent first-run logic**: both `mariadb`'s and `wordpress`'s `tools/script.sh`
  entrypoints check whether their respective data already exists
  (`/var/lib/mysql/${MYSQL_DATABASE}` and `/var/www/html/wp-config.php`) before
  running setup. This means `docker compose up` on subsequent runs is a no-op for
  initialization and just starts the services — data isn't recreated or overwritten
  on every restart.
- **To fully reset state** (e.g. testing setup from scratch), use `make fclean` (see
  §4) or manually:
  ```bash
  docker-compose -f src/docker-compose.yml down -v
  sudo rm -rf ${HOME}/data/jmondelamariadb src/data/jmondelawordpress
  make up
  ```
- Nginx's self-signed TLS certificate (`/etc/ssl/certs/nginx_certificate.crt`) is
  generated once inside the container's own filesystem (not persisted via a volume),
  so it regenerates automatically whenever the `nginx` container is recreated.

## 7. Notes on the build/entrypoint chain

- Each service's `Dockerfile` uses `ENTRYPOINT ["/usr/local/bin/script.sh"]` (or
  `["script.sh"]` for wordpress) with `CMD` supplying the actual foreground process
  (`mysqld_safe`, `php-fpm8.2 -F`, `nginx -g daemon off;`). The entrypoint script runs
  first-time setup, then `exec`s into that `CMD`, so the container's main process
  ends up being the actual server (PID 1), which is what keeps `restart: on-failure`
  and log streaming behaving correctly.
- `wordpress`'s entrypoint blocks on `mysqladmin ping --host=mariadb` before
  proceeding, so `depends_on: [mariadb]` in the compose file only guarantees
  *container start order*, not that MariaDB is ready to accept connections — the
  actual readiness wait is handled in the script, and `nginx` similarly depends on
  `wordpress` only for start ordering, not application readiness.
