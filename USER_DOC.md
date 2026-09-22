# User Documentation

This guide covers day-to-day usage of the stack: starting/stopping it, reaching the
website and the WordPress admin panel, managing credentials, and quick health checks.
It assumes the project is already built and configured on a machine with Docker and
Docker Compose installed (see `DEV_DOC.md` for setup).

The stack is made of three containers on a shared Docker network (`inception`):

| Service    | Role                              | Exposed port |
|------------|-----------------------------------|--------------|
| `nginx`    | Reverse proxy / TLS termination   | 443 (HTTPS)  |
| `wordpress`| WordPress + PHP-FPM               | 9000 (internal) |
| `mariadb`  | Database                          | 3306         |

Only `nginx` is meant to be reached from outside the host; `wordpress` and `mariadb`
talk to each other over the internal `inception` network.

## 1. Starting the stack

From the project's root directory (where the `Makefile` lives):

```bash
make
```

This single command handles everything needed for a first run: it creates the host
directories the containers need, adds the site's domain to `/etc/hosts` (you may be
prompted for your password), and builds and starts all three containers in the
background. The first run may take a few minutes (MariaDB initializes its data
directory, WordPress downloads WP-CLI and WordPress core, Nginx generates a
self-signed certificate).

Check that all three containers are up and healthy:

```bash
docker-compose -f srcs/docker-compose.yml ps
```

You should see `mariadb`, `wordpress`, and `nginx` listed as `running`.

## 2. Stopping the stack

To stop the containers without deleting data:

```bash
make stop
```

To stop **and remove** the containers (persisted data is kept):

```bash
make down
```

To restart everything:

```bash
make up
```

> Each service has `restart: on-failure` set, so a container that crashes will
> automatically retry a limited number of times without you needing to intervene.

## 3. Accessing the website

The site is served over HTTPS only, using the domain configured by the `USERNAME`
value (from `.env`, or overridden with `make up USERNAME=yourlogin`) — commonly a
`<login>.42.fr` style domain, e.g. `jmondela.42.fr`.

You don't need to edit `/etc/hosts` yourself — running `make`/`make up` already adds
the entry for you. If you ever need to check or add it manually:

```bash
grep 42.fr /etc/hosts
```

Then open in a browser:

```
https://jmondela.42.fr
```

**You will see a browser security warning.** This is expected: Nginx uses a
self-signed TLS certificate generated at container startup, not one from a public
Certificate Authority. Click "Advanced" → "Proceed anyway" (wording varies by
browser).

## 4. Accessing the WordPress admin panel

The admin dashboard is at:

```
https://jmondela.42.fr/wp-admin
```

Log in with the administrator account defined in `.env`:
- Username: value of `WP_ADMIN`
- Password: value of `WP_ADMIN_PASSWORD`

A second, non-admin "author" account is also created automatically on first setup,
using `WP_USER` / `WP_USER_PASSWORD`, for day-to-day content publishing without
full admin rights.

## 5. Managing credentials

All credentials live in the `.env` file at the project root and are injected into the
containers at startup — they are **not** hardcoded in any Dockerfile or config file.
Typical variables you'll find/manage there:

| Variable | Purpose |
|---|---|
| `MYSQL_ROOT_PASSWORD` | MariaDB root password |
| `MYSQL_DATABASE` | WordPress database name |
| `MYSQL_USER` / `MYSQL_PASSWORD` | Database user WordPress connects with |
| `WP_TITLE` | Site title |
| `WP_ADMIN` / `WP_ADMIN_PASSWORD` / `WP_ADMIN_EMAIL` | WordPress administrator account |
| `WP_USER` / `WP_USER_PASSWORD` / `WP_USER_EMAIL` | Secondary WordPress user |
| `USERNAME` (or `USER`) | Login used to build the `*.42.fr` domain and TLS cert |

**Important:**
- `.env` should **never** be committed to version control — treat it like a password
  file.
- Changing a password in `.env` after the stack has already been initialized will
  **not** retroactively change it inside WordPress or MariaDB — those accounts are
  only created once, the first time the containers start against an empty data
  directory. To rotate credentials afterward, change them through the WordPress admin
  panel (Users → your profile) or with `wp user update` / MariaDB's `SET PASSWORD`,
  and update `.env` to match so future rebuilds stay consistent.
- To fully reset and re-apply new credentials from `.env`, run `make fclean` followed
  by `make` (see "Data persistence" and "Makefile usage" in `DEV_DOC.md`) — this
  deletes the site and database content, so back up anything important first.

## 6. Basic health checks

**Are the containers running?**
```bash
docker-compose -f srcs/docker-compose.yml ps
```

**View logs (useful when something isn't loading):**
```bash
make logs
docker-compose -f srcs/docker-compose.yml logs -f nginx
docker-compose -f srcs/docker-compose.yml logs -f wordpress
docker-compose -f srcs/docker-compose.yml logs -f mariadb
```

**Confirm Nginx is answering:**
```bash
curl -kI https://jmondela.42.fr
```
`-k` ignores the self-signed certificate warning; you should get an `HTTP/1.1 200`
or `301/302` response.

**Confirm the database is reachable from inside its container:**
```bash
docker exec -it mariadb mysqladmin -uroot -p ping
```
(enter `MYSQL_ROOT_PASSWORD` when prompted — should reply `mysqld is alive`)

**Check WordPress can talk to the database:**
```bash
docker exec -it wordpress wp core is-installed --allow-root
```
No output / exit code `0` means WordPress is correctly installed and connected.

If any of these fail, check the corresponding service's logs first — most startup
issues are either a missing/incorrect `.env` variable or the database not yet being
ready (the containers already wait for MariaDB to respond before configuring
WordPress, so this should self-resolve within a minute or so of `up`).
