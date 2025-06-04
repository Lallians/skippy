#!/bin/bash

MAX_ATTEMPTS=3
ATTEMPT=0
LOCK_FILE="/usr/local/bin/.ps_installed.lock"

# Check if lock file exists to prevent reinstallation.
if [ ! -f "$LOCK_FILE" ]; then
  
  echo 'PS-INSTALL: Starting installation'

  # We ping the db container and if it does not respond, we stop here.
  while ! ping -c1 "$DB_SERVER" >/dev/null 2>&1; do
    ATTEMPT=$((ATTEMPT + 1))
    if [ "$ATTEMPT" -ge "$MAX_ATTEMPTS" ]; then
      echo 'PS-INSTALL: DB is unavailable.'
      exit 1
    fi
    sleep 2
  done

  # Container is online, we perform sql request to check mysql is ready too
  ATTEMPT=0
  until RESULT=$(mysql -h "$DB_SERVER" -u "$DB_USER" -p"$DB_PASSWD" -e "SELECT 1;" "$DB_NAME" 2>/dev/null) && [[ "$RESULT" == *"1"* ]]; do
    ATTEMPT=$((ATTEMPT + 1))
    echo $RESULT
    echo "PS-INSTALL: SQL query attempt $ATTEMPT/$MAX_ATTEMPTS failed..."
    if [ "$ATTEMPT" -ge "$MAX_ATTEMPTS" ]; then
      echo "PS-INSTALL: MySQL did not respond correctly after $MAX_ATTEMPTS attempts."
      exit 1
    fi
    sleep 5 # Give some time...
  done

  # Container is ready, we install PS
  # we run in subshell because index_cli.php exits and prevents script fron continuing
  (php install/index_cli.php  \
    --language=fr \
    --domain=$APP_DOMAIN \
    --db_server=$DB_SERVER  \
    --db_name=$DB_NAME \
    --db_user=$DB_USER  \
    --db_password=$DB_PASSWD  \
    --prefix=$DB_PREFIX \
    --email=$BO_ADMIN_USER \
    --password=$BO_ADMIN_PASSWD \
    --db_clear=0 \
    --ssl=1 \
    --name=$APP_NAME) || echo "PS-INSTALL: install_cli done"
  
  
  # And we create the lock file to prevent any reinstallation
  touch "$LOCK_FILE"

  # Lastly, we rename the admin folder and remove the installation folder
  mv admin $APP_ADMIN_DIR
  rm -rf install

fi

echo 'Starting webserver'

exec apache2-foreground
