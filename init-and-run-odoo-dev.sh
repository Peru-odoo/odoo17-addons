#!/bin/bash
set -e

# Configuration for syncing from production
PROD_SERVER="opw-prod"
PROD_DB="opw"
PROD_DB_USER="odoo"
PROD_FILESTORE_PATH="/opt/odoo/.local/share/Odoo/filestore"
TEMP_DB_BACKUP="/tmp/$PROD_DB-$(date +%F).sql"

# Configuration for Odoo development environment
if [ -z "$2" ] || [ "$2" = "local" ]; then
    ODOO_BIN="../../Odoo/odoo17-base/odoo-bin"
    ODOO_CONFIG_FILE="../odoo17.local.cfg"
elif [ "$2" = "testing" ]; then
    ODOO_BIN="../odoo/odoo-bin"
    ODOO_CONFIG_FILE="/etc/odoo.conf"
else
    echo "Invalid environment. Please specify 'local' or 'test'."
    exit 1
fi
INIT_FILE="init-done.flag"

DB_CREDENTIALS=$(python3 get_odoo_config_values.py "$ODOO_CONFIG_FILE")

ODOO_DB_SERVER=$(echo "$DB_CREDENTIALS" | jq -r '.db_host')
#DB_PORT=$(echo "$DB_CREDENTIALS" | jq -r '.db_port')
ODOO_DB=$(echo "$DB_CREDENTIALS" | jq -r '.db_name')
ODOO_USER=$(echo "$DB_CREDENTIALS" | jq -r '.db_user')
ODOO_PASSWORD=$(echo "$DB_CREDENTIALS" | jq -r '.db_password')
ODOO_FILESTORE_PATH=$(echo "$DB_CREDENTIALS" | jq -r '.data_dir')
export PGPASSWORD="$ODOO_PASSWORD"

ODOO_RUN="$ODOO_BIN -c $ODOO_CONFIG_FILE"
ODOO_SHELL="$ODOO_BIN shell -c $ODOO_CONFIG_FILE"

restart_postgres() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        brew services restart postgresql@16
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        sudo systemctl restart postgresql
    else
        echo "Unsupported operating system."
        exit 1
    fi
}

sync_from_prod() {
    echo "Starting backup of production database..."
    # shellcheck disable=SC2029
    ssh $PROD_SERVER "cd /tmp && sudo -u $PROD_DB_USER pg_dump $PROD_DB" > "$TEMP_DB_BACKUP"


    echo "Production database backup completed. Starting rsync of filestore..."
    mkdir -p "$ODOO_FILESTORE_PATH"
    rsync -avz --delete "$PROD_SERVER:$PROD_FILESTORE_PATH" "$ODOO_FILESTORE_PATH"

    echo "Filestore sync completed. Restoring database on development environment..."
      restart_postgres
    wait_for_db
    dropdb --if-exists  -h "$ODOO_DB_SERVER" -U "$ODOO_USER" "$ODOO_DB"
    createdb -h "$ODOO_DB_SERVER" -U "$ODOO_USER" "$ODOO_DB"
    psql -h "$ODOO_DB_SERVER" -U "$ODOO_USER" "$ODOO_DB" < "$TEMP_DB_BACKUP"

    echo "Database restore completed."

    $ODOO_RUN --stop-after-init -u product_connect
    $ODOO_SHELL --no-http <<EOF
from passlib.context import CryptContext
from odoo import api, SUPERUSER_ID
from odoo.tools import config

# Initialize the environment for script execution
db_registry = odoo.modules.registry.Registry(odoo.tools.config['db_name'])
with db_registry.cursor() as cr:
    db_registry = odoo.modules.registry.Registry.new(odoo.tools.config['db_name'])
    with db_registry.cursor() as cr:
        env = api.Environment(cr, SUPERUSER_ID, {})
        # Neutralize email sending
        env['ir.mail_server'].search([]).write({'active': False})
        env['ir.config_parameter'].sudo().set_param('mail.catchall.domain', False)
        env['ir.config_parameter'].sudo().set_param('mail.catchall.alias', False)
        env['ir.config_parameter'].sudo().set_param('mail.bounce.alias', False)
        # Deactivate scheduled actions
        env['ir.cron'].search([]).write({'active': False})
        cr.commit()
EOF

    echo "Database neutralization completed."
    rm "$TEMP_DB_BACKUP"
}


wait_for_db() {
    until pg_isready -h "$ODOO_DB_SERVER" -U "$ODOO_USER"; do
        sleep 1
    done
}

wait_for_db

init_dev_env() {
  if [ ! -f "$INIT_FILE" ]; then
      restart_postgres
      wait_for_db
      dropdb -U odoo odoo
      createdb -U odoo odoo
      sudo rm -rf ../filestore

      $ODOO_RUN --stop-after-init -i product_connect
      $ODOO_SHELL --no-http <<EOF
from passlib.context import CryptContext
from odoo import api, SUPERUSER_ID
from odoo.tools import config

db_registry = odoo.modules.registry.Registry(odoo.tools.config['db_name'])
with db_registry.cursor() as cr:
    env = api.Environment(cr, SUPERUSER_ID, {})
    env['ir.config_parameter'].sudo().set_param('shopify.api_token', config.get('shopify_api_token'))
    env['ir.config_parameter'].sudo().set_param('shopify.shop_url', config.get('shopify_shop_url'))
    admin_user = config.get('default_admin_user')
    admin_password = config.get('default_admin_passwd')

    if admin_password:
        pwd_context = CryptContext(schemes=["pbkdf2_sha512"], deprecated="auto")
        admin_password_hashed = pwd_context.hash(admin_password)
        cr.execute("UPDATE res_users SET password=%s WHERE login='admin'", (admin_password_hashed,))

    if admin_user:
        cr.execute("UPDATE res_users SET login=%s WHERE login='admin'", (admin_user,))

    cr.commit()
EOF
      touch "$INIT_FILE"
  fi
}


start_odoo() {
    if [ $# -eq 0 ]; then
        echo "Starting Odoo in normal mode..."
        eval exec "$ODOO_RUN"
    else
        echo "Executing command: $ODOO_RUN" "$@"
        eval exec "$ODOO_RUN" "$@"
    fi
}

start_odoo_debug() {
    if [ $# -eq 0 ]; then
        echo "Starting Odoo in debug mode..."
        exec "$ODOO_RUN" --dev=all
    else
        echo "Starting Odoo in debug mode with additional arguments: $ODOO_RUN" "$@"
        exec "$ODOO_RUN" "$@" --dev=all
    fi
}

case "$1" in
    sync-prod)
        sync_from_prod
        ;;
    init)
        init_dev_env
        ;;
    debug)
        start_odoo_debug "${@:2}"
        ;;
    *)
        start_odoo "$@"
        ;;
esac

echo "Completed."