#!/bin/bash
set -e

cd /home/frappe/bench

: "${RFP_DOMAIN_NAME:=frontend}"
: "${RFP_DB_PORT:=3306}"

# --- Wait for MariaDB --------------------------------------------------------
if [ -n "$RFP_DB_HOST" ]; then
    echo "-> Waiting for MariaDB at ${RFP_DB_HOST}:${RFP_DB_PORT}"
    for i in $(seq 1 90); do
        if mysqladmin ping -h"$RFP_DB_HOST" -P"$RFP_DB_PORT" -uroot -p"$RFP_DB_ROOT_PASSWORD" --silent >/dev/null 2>&1; then
            echo "-> MariaDB is ready"
            break
        fi
        if [ "$i" -eq 90 ]; then
            echo "ERROR: MariaDB at ${RFP_DB_HOST}:${RFP_DB_PORT} not reachable after 180s"
            exit 1
        fi
        sleep 2
    done
fi

# --- Ensure common_site_config.json exists -----------------------------------
COMMON_CONFIG="/home/frappe/bench/sites/common_site_config.json"
if [ ! -s "$COMMON_CONFIG" ]; then
    echo "-> Creating empty common_site_config.json"
    echo "{}" > "$COMMON_CONFIG"
    chown frappe:frappe "$COMMON_CONFIG"
fi

# --- Write DB / Redis settings into common_site_config -----------------------
echo "-> Writing connection settings into common_site_config.json"
su frappe -c "cd /home/frappe/bench && \
    bench set-config -g db_host '${RFP_DB_HOST}' && \
    bench set-config -gp db_port '${RFP_DB_PORT}' && \
    bench set-config -g redis_cache '${RFP_REDIS_CACHE_URL}' && \
    bench set-config -g redis_queue '${RFP_REDIS_QUEUE_URL}' && \
    bench set-config -g redis_socketio '${RFP_REDIS_SOCKETIO_URL}' && \
    bench set-config -gp use_dns_multitenant 0"

# --- Bootstrap site on first run (idempotent) --------------------------------
SITE_PATH="/home/frappe/bench/sites/${RFP_DOMAIN_NAME}"
if [ ! -d "$SITE_PATH" ]; then
    echo "-> Creating new site ${RFP_DOMAIN_NAME} (this may take 3-5 minutes)"
    su frappe -c "cd /home/frappe/bench && \
        bench new-site '${RFP_DOMAIN_NAME}' \
            --admin-password '${RFP_SITE_ADMIN_PASSWORD}' \
            --no-mariadb-socket \
            --db-root-password '${RFP_DB_ROOT_PASSWORD}' \
            --install-app erpnext"
    su frappe -c "cd /home/frappe/bench && bench use '${RFP_DOMAIN_NAME}'"
    su frappe -c "cd /home/frappe/bench && bench --site '${RFP_DOMAIN_NAME}' enable-scheduler" || true
    echo "-> Site ${RFP_DOMAIN_NAME} created and scheduler enabled"
else
    echo "-> Site ${RFP_DOMAIN_NAME} already exists — skipping bootstrap"
    # Make sure default site is set on subsequent boots (volume may be fresh)
    su frappe -c "cd /home/frappe/bench && bench use '${RFP_DOMAIN_NAME}'" || true
fi

# --- Clear cache (best-effort) -----------------------------------------------
echo "-> Clearing cache"
su frappe -c "cd /home/frappe/bench && bench execute frappe.cache_manager.clear_global_cache" || true

# --- Template nginx and supervisor configs -----------------------------------
echo "-> Rendering nginx config"
envsubst '$RFP_DOMAIN_NAME' < /home/frappe/temp_nginx.conf > /etc/nginx/conf.d/default.conf

echo "-> Rendering supervisor config"
envsubst '$PATH,$HOME,$NVM_DIR,$NODE_VERSION' < /home/frappe/temp_supervisor.conf > /home/frappe/supervisor.conf

echo "-> Starting nginx"
nginx

echo "-> Starting supervisor"
exec /usr/bin/supervisord -c /home/frappe/supervisor.conf
