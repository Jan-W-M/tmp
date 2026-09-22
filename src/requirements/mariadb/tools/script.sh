
#!/bin/sh

DATABASE_DIR="/var/lib/mysql/${MYSQL_DATABASE}"

if [ ! -d "$DATABASE_DIR" ]; then
    # Temporary bootstrap instance, not PID 1 yet (script.sh still is) —
    # fine to use mysqld_safe here since it's not the long-running process.
    /usr/bin/mysqld_safe --datadir=/var/lib/mysql &

    until mysqladmin ping 2> /dev/null; do
        sleep 2
    done

    mysql -u root <<EOF
        CREATE DATABASE IF NOT EXISTS ${MYSQL_DATABASE};

        ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';

        DELETE FROM mysql.user WHERE user='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
        DELETE FROM mysql.user WHERE user='';

        CREATE USER '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
        GRANT ALL PRIVILEGES ON ${MYSQL_DATABASE}.* TO '${MYSQL_USER}'@'%';

        FLUSH PRIVILEGES;
EOF

    if [ $? -ne 0 ]; then
        echo "Error: MySQL commands failed." >&2
        exit 1
    fi

    # Clean shutdown of the bootstrap instance, now authenticated with the
    # new root password. Waits for mysqld_safe's child to actually exit
    # before continuing, so we don't exec the real server into a socket
    # that's still in use.
    mysqladmin -u root -p"${MYSQL_ROOT_PASSWORD}" shutdown

    while mysqladmin ping 2> /dev/null; do
        sleep 1
    done
fi

# Real, long-running server: becomes PID 1 via exec, so it receives
# SIGTERM directly from Docker and shuts down cleanly (no mysqld_safe
# wrapper in the way).
exec "$@"