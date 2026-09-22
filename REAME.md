*This project has been created as part of the 42 curriculum by jmondela*

# Inception

## Description

Inception is a system administration project that consists of setting up a small
infrastructure of multiple Docker containers, each running a single service, and
orchestrating them together with Docker Compose. The stack is composed of three
custom-built images — no pre-built service images from Docker Hub are used for the
core services:

- **NGINX** — acts as the sole entrypoint into the infrastructure, terminating
  TLS (self-signed certificate, TLSv1.2/TLSv1.3 only) and reverse-proxying dynamic
  requests to PHP-FPM.
- **WordPress + PHP-FPM** — the application layer, installed and configured via
  WP-CLI on first startup (site, admin account, and a secondary author account are
  created automatically).
- **MariaDB** — the persistence layer for WordPress, with database/user creation
  handled automatically on first startup.

All three containers run on a dedicated, isolated Docker network (`inception`) and
communicate with each other by service name — only NGINX exposes a port to the host.
Data is persisted independently of container lifecycle through a mix of a named
Docker volume (database) and host bind mounts (WordPress files, NGINX logs), so
containers can be stopped, removed, and recreated without losing state. Startup logic
in each service is idempotent: re-running the stack does not recreate the database or
reinstall WordPress if they already exist.

## Instructions

Full usage documentation is split into two guides:

- **[`USER_DOC.md`](./USER_DOC.md)** — for anyone running or administering the
  stack: starting/stopping it, reaching the site and the WordPress admin panel,
  managing credentials, and basic health checks.
- **[`DEV_DOC.md`](./DEV_DOC.md)** — for anyone building or modifying the project:
  prerequisites, initial setup, `Makefile` targets, the underlying `docker-compose`
  commands, and how data persistence is wired up.

Quick start, from the repository root:

```bash
make          # builds and starts the full stack
```

Then visit the configured domain (see `USER_DOC.md` for the `/etc/hosts` /
`USERNAME` details) in a browser.

To stop the stack:

```bash
make down     # stop and remove containers, keep persisted data
make fclean   # full teardown: containers, images, volumes, and bind-mounted data
```

## Resources

Documentation and references used while building this project:

- [Docker documentation](https://docs.docker.com/)
- [Docker Compose file reference](https://docs.docker.com/compose/compose-file/)
- [NGINX documentation](https://nginx.org/en/docs/)
- [MariaDB Knowledge Base](https://mariadb.com/kb/en/)
- [WP-CLI documentation](https://wp-cli.org/)
- [WordPress Developer documentation](https://developer.wordpress.org/)
- 42's official Inception subject PDF

### How AI was used

An AI assistant (Claude) was used in a **supporting, non-authoring** capacity during
this project, specifically for:

- **Drafting project documentation** — the initial structure and wording of
  `USER_DOC.md` and `DEV_DOC.md` were generated with AI assistance based on the
  project's actual `docker-compose.yml`, `Dockerfile`s, config files, and
  `Makefile`, then reviewed and corrected against the real project files (including
  catching and fixing a couple of inconsistencies between the `Makefile` and the
  compose file in the process).
- **Debugging assistance** — explaining Docker/NGINX error messages encountered
  while modifying service configuration (e.g. a `port is already allocated` error
  when rebinding NGINX to a new host port, and an NGINX startup crash traced back to
  Debian's stock default site config conflicting with this project's own
  `conf.d` configuration) and suggesting fixes, which were then applied and verified
  manually.
  Aditionaly it helped trying to connect my VM to the host, even though i ended upp using an acce machine instead.
- **Conceptual explanations** — clarifying Docker/Compose concepts (networks,
  images vs. containers, volumes vs. bind mounts, `ssl_protocols`, etc.) during
  development.

The AI assistant did not autonomously write the project's Dockerfiles, service
configuration files, or entrypoint scripts; it was used as a reference and debugging
aid alongside official documentation. All AI-suggested changes were reviewed,
tested, and understood before being applied to the codebase.