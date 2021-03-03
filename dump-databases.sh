#!/bin/bash
CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
config=config-default.ini
name=$(date +"%Y-%m-%d-%H%M%S")
while :; do
    case $1 in
        -c|--config)
            if [ "$2" ]; then
                config=$2
                shift
            else
               die 'ERROR: "--config" requires a non-empty option argument.'
            fi
             ;;
        --config=?*)
            config=${1#*=}
            ;;
        --config=)
            die 'ERROR: "--config" requires a non-empty option argument.'
            ;;
        -n|--name)
            if [ "$2" ]; then
                name=$2
                shift
            else
               die 'ERROR: "--config" requires a non-empty option argument.'
            fi  
             ;;  
        --name=?*)
            name=${1#*=}
            ;;  
        --name=)
            die 'ERROR: "--config" requires a non-empty option argument.'
            ;;
        --)              # End of all options.
            shift
            break
            ;;
        -?*)
            die 'ERROR: Unknown option "$1"'
            ;;
        *)               # Default case: No more options, so break out of the loop.
            break
    esac

    shift
done
if [ -z $config ]; then
    echo Error: You must use --config arguement
    exit 1
fi
source "$CURRENT_DIR/$config"

V_LIST_DATABASES="${VESTA_DIR}/bin/v-list-databases"
V_LIST_USERS="${VESTA_DIR}/bin/v-list-users"

# This script dump all databases to the user's database borg repo

echo "$(date +'%F %T') #################### DUMP MYSQL DATABASES TO CORRESPONDING USER BORG REPO ####################"
# Get user list
while read USER ; do
  USER_REPO=$REPO_DB_DIR/$USER
#  if [ ! -z $REMOTE_HOST ]; then
#    USER_REPO="$REMOTE_HOST:$USER_REPO"
#  fi
  # Check if repo was initialized, if its not we perform borg init
#  if [ $REPO_REMOTE == "TRUE" ]; then
#    if ! ssh -i /root/.ssh/id_rsa_test $REPO_HOST "$USER_REPO/data"; then
#      USER_REPO="$REPO_HOST:$USER_REPO"
#      echo "-- No repo found. Initializing new borg repository $USER_REPO"
#      borg init $OPTIONS_INIT $USER_REPO
#    fi
#  else
#    if ! [ -d "$USER_REPO/data" ]; then
#      echo "-- No repo found. Initializing new borg repository $USER_REPO"
#      borg init $OPTIONS_INIT $USER_REPO
#    fi
#  fi
  borg init $OPTIONS_INIT $USER_REPO
  # Get MySQL databases
  while read DATABASE ; do
    ARCHIVE="$DATABASE-$name"
    echo "-- Creating new backup archive $USER_REPO::$ARCHIVE"
    mysqldump $DATABASE --opt --routines --skip-comments | borg create $OPTIONS_CREATE $USER_REPO::$ARCHIVE -
    borg prune $OPTIONS_PRUNE $USER_REPO --prefix ${DATABASE}'-'
    let DB_COUNT++
  done < <($V_LIST_DATABASES $USER | grep -w mysql | cut -d " " -f1)
  # Get PostgreSQL databases
  while read DATABASE ; do
    ARCHIVE="$DATABASE-$name"
    echo "-- Creating new backup archive $USER_REPO::$ARCHIVE"
    $CURRENT_DIR/inc/pg-pgdump.sh $DATABASE | borg create $OPTIONS_CREATE $USER_REPO::$ARCHIVE -
    borg prune $OPTIONS_PRUNE $USER_REPO --prefix ${DATABASE}'-'
    let DB_COUNT++
  done < <($V_LIST_DATABASES $USER | grep -w pgsql | cut -d " " -f1)

  echo "-- Cleaning old backup archives"
done < <($V_LIST_USERS | cut -d " " -f1 | awk '{if(NR>2)print}')

echo "$(date +'%F %T') ########## $DB_COUNT DATABASES SAVED ##########"
echo
