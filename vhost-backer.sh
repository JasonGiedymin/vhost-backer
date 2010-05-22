#!/bin/bash
#
# ----------------------------------------------------------------------------
#                                License
# ----------------------------------------------------------------------------
#   vhost-backer is a lightweight vhost and wordpress backup script.
#   Copyright (C) 2010  Jason Giedymin
#
#   This program is free software: you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation, either version 3 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# ----------------------------------------------------------------------------
#                             Description
# ----------------------------------------------------------------------------
# 
#             File: vhost-backer.sh
#
# Application Name: vhost-backer
#
#           Author: Jason Giedymin, jason dot giedymin -{a, t}- g mail dotcom
#
#       Script URL: http://amuxbit.com
#
#       Ping Backs: Writing about vhost-backer? Send me an email and let me
#                   know.
#
#          Version: v0.9.1 - Initial Cleanup.
#
#    License Notes: If you find yourself using using, modifying, selling
#                   this script please give proper dedication to your users
#                   that this script was created and maintained by me.  It's
#                   only right, and provides me and others motivation,
#                   contributes to the general stability and life of this
#                   project, and serves as a basepoint.
#
#      Description: vhost-backer is a lightweight vhost and wordpress backup
#                   script. This script is best used for storing long term
#                   snapshots of large webserver site implementations.
#                   Think datawarehouse, when dealing with these backups.
#                   The script has the ability to read WordPress config files
#                   and will back those databases up along with the core
#                   files.  This script is lagging behind our own deployment
#                   at amuxbit, and it is the hope that in time the FOSS
#                   version will be up to date.  Some goals for making this
#                   project FOSS was to enhance stability _and_ readability.
#                   No doubt, there are many different implementations to
#                   backing up data and wordpress, this is just one.
#                   Enjoy.
#
#        EC2 Notes: If your running on EC2 you may have issues with a live and
#                   heavy trafficked site. Future updates will be better
#                   suited for EC2 duty. Stay tuned!
#
#             ToDo: backup backout,
#                   expanded function documentation,
#                   EC2 compatability,
#                   simple user mode,
#                   encryption keys
#                   switchable modes,
#                   interactive mode,
#                   accept command line switches
#
# This script works under the following recommended vhost structure (sample):
# / (root)
# |-var
#    |-www
#       |-vhosts
#           |-htdocs (things like your WordPress install, etc...
#           |-admin (a special admin site perhaps)
#           |-logs (holds your logs)
#           |-keys (where your might store your SSL keys)
#           |-backup (a place to store your backup files)
#               |-htdocs.tar.bz2 (a backup file)
#               |-admin.tar.bz2 (a backup file)
#               |-scripts.tar.bz2 (a backup file)
#           |-scripts (maybe you have special scripts JUST for this vhost)
#
#
# ----------------------------------------------------------------------------
#                             Start of Code
# ----------------------------------------------------------------------------
#
#
#--------------------------Important Settings---------------------------------
#
#-------------------------------Constants-------------------------------------
#                       <-- Do not edit these -->
TRUE=1;
FALSE=0;
VHOST_MODE=0;
SIMPLE_HOST_MODE=1;
DATE="$(date +%Y%m%d-%H:%M:%S)";

#-----------------------------Common Settings---------------------------------
#                  <-- You _will want_ to edit these -->
#
# Debug, 1=true, 0=false.  You may also use the constants above.
# Default: DEBUG=$FALSE (is equivalent to) DEBUG=0
# NOTE!!!  Debug mode can be dangerous, it will show your password on screen
#          in clear text!
DEBUG=0;

# Sets the application mode to simple single host, or enhanced vhost mode.
# Default: APP_MODE=$VHOST_MODE (is equivalent to) APP_MODE=0
# Use 1 for Simple Host Mode
# Use 0 for Vhost mode
APP_MODE=0;

# Wordpress Database Backup
# DO_BACKUP_DB, 1=true, 0=false.  You may also use the constants above.
# Default: DO_BACKUP_DB=$TRUE (is equivalent to) DO_BACKUP_DB=1
# Use 1 for Yes, do backup the database
# Use 0 for No, don't backup the database
DO_BACKUP_DB=1;

# Owner of the files
# Default: OWNER=root
OWNER="root";

# Privleges for owner files
# Default: OWNER_PRIVS=600
OWNER_PRIVS=0600;

# Bzip compression level 0-9.
# Default: BZIP_COMP_LEVEL=9
BZIP_COMP_LEVEL=9;

# Wordpress config file name
# Default: WORDPRESS_CFG="wp-config.php"
WORDPRESS_CFG="wp-config.php";

# Logs really should be handled by rotation, and by your management app.
# I will introduce a basic log rotation utility at a later date.
# Default: LOG_ROOT=
# LOG_ROOT=

# Backup directory name (not fully qualified)
# Default: BACKUP_LOC=backup
BACKUP_LOC="backup";

# Location of mysqldump utility
MYSQLDUMP_BIN="$(which mysqldump)";

# Get chown location
CHOWN="$(which chown)";

# Get chmod location
CHMOD="$(which chmod)";

#----------------------Simple Host Mode Settings------------------------------
# Simple Host Mode was never part of this app, but is here simply because
# so many WordPress users only need this level of file backups.

# Fully qualified location of your site's root
SIMPLE_SITE_LOC="/var/www/vhosts/mysite1.com";

# Directory name of the location of where your doc root is
SIMPLE_HTTPDOC_LOC="htdocs";

# Fully qualified location of where your WordPress install is
# Some people have WordPress installed in the doc root:
# SIMPLE_WORDPRESS_LOC=/var/www/vhosts/mysite2.com/htdocs
#
# Some people have WordPress installed in a subdirectory:
# SIMPLE_WORDPRESS_LOC=/var/www/vhosts/mysite2.com/htdocs/wordpress
SIMPLE_WORDPRESS_LOC="/var/www/vhosts/mysite1.com/htdocs";

#-------------------------VHost Mode Settings---------------------------------
# Fully qualified path to vhosts
# Default: VHOST_LOC=/var/www/vhosts
VHOST_LOC="/var/www/vhosts";

# Names of your sites or vhosts sub directories
# Default: VHOSTS=( mysite1.com mysite2.com )
VHOSTS=( mysite1.com mysite2.com );

# Names of the subfolders or sub-sites
# Note: some people have admin sites off-root, and off-port. For instance
#       someone might have an admin site's root pointing to httpsdocs
#       and have that accessible via port :2010.  Some people also like to
#       have subdomain roots pointed to sub directories like 'team', all
#       under the main vhost.  Consider using this structure.
# Default: VHOSTS_SITES=( htdocs httpsdocs team )
VHOSTS_SITES=( htdocs httpsdocs team );

#-----------------------------Functions---------------------------------------

# Very basic logging.
function logIt() {
    local logDate=`date +%Y/%m/%d-%H:%M:%S`;

    case "$1" in
        debug)
                [[ $DEBUG -eq $TRUE ]] && echo "DEBUG [$logDate]: $2"
                ;;
        warn)
                [[ $DEBUG -eq $TRUE ]] && echo "WARN  [$logDate]: $2"
                ;;
        error)
                echo "ERROR  [$logDate]: $2"
                ;;
        info)
                echo "INFO  [$logDate]: $2";
                ;;
        *)
                echo "$2";
                ;;
    esac;
}

# Claim ownership and set privs of files
function claimFile() {
    local fileName=$1;

    #touch $fileName
    chown $OWNER $fileName
    chmod $OWNER_PRIVS $fileName
}

# Get a specific wordpress property
# Slight overkill, but it helps since we have debugging and value checks here.
function getCFGValue() {
    local propertyKey=$1;
    local cfgFile=$2;

    logIt debug "Looking for [$propertyKey].";

    cfgReturnValue="$(grep $propertyKey $cfgFile | awk -F "'*'" '{print $4}')";

    if [ -z $cfgReturnValue ]; then
        logIt error "Cannot find [$propertyKey] in [$cfgFile], stopping database backup, exiting...";
        exit 1;
    fi;
}

# Backup wordpress if wordpress config file is found, otherwise do nothing.
function backupWordPressDB() {
    wordpressLocation=$1;
    backupLocation=$2/$DATE;

    if [ -f $wordpressLocation/$WORDPRESS_CFG ]; then
        logIt info "Found wordpress at [$wordpressLocation/$WORDPRESS_CFG].";
        logIt info "Trying to backup WordPress database using [$WORDPRESS_CFG]...";

        getCFGValue "DB_USER" $wordpressLocation/$WORDPRESS_CFG;
        local dbUser=$cfgReturnValue;

        getCFGValue "DB_PASSWORD" $wordpressLocation/$WORDPRESS_CFG;
        local dbPass=$cfgReturnValue;

        getCFGValue "DB_HOST" $wordpressLocation/$WORDPRESS_CFG;
        local dbHost=$cfgReturnValue;

        getCFGValue "DB_NAME" $wordpressLocation/$WORDPRESS_CFG;
        local dbName=$cfgReturnValue;

        logIt debug "Running mysqldump [$MYSQLDUMP_BIN -u $dbUser -h $dbHost --password=$dbPass $dbName > $backupLocation/backup_db.sql]...";

        $MYSQLDUMP_BIN -u $dbUser -h $dbHost --password=$dbPass $dbName > $backupLocation/backup_db.sql

        if [ 0 -ne $? ]; then
            logIt error "$MYSQLDUMP_BIN error, read output or logs.";
            exit 1;
        else
            cd $backupLocation

            [[ $DEBUG -eq $TRUE ]] && tar -cvjf backup_db.sql.tar.bz2 backup_db.sql
            [[ $DEBUG -eq $FALSE ]] && tar -cjf backup_db.sql.tar.bz2 backup_db.sql

            claimFile $backupLocation/backup_db.sql.tar.bz2
            rm $backupLocation/backup_db.sql
        fi
    else
        logIt debug "Wordpress not found."
    fi;
}

# Compresses a vhost site.
function backupCompressThis() {
        local currentVhost=$1;
        local site=$2;
        local backupLocation=$3/$DATE;

        if [ ! -d $backupLocation ]; then
            mkdir -p $backupLocation
            claimFile $backupLocation
        fi

        logIt info "Backing up [$currentVhost/$site] to [$backupLocation/$site.tar.bz2], be patient...";
        cd $currentVhost

        [[ $DEBUG -eq $TRUE ]] && tar -cvjf $site.tar.bz2 $site
        [[ $DEBUG -eq $FALSE ]] && tar -cjf $site.tar.bz2 $site

        claimFile $currentVhost/$site.tar.bz2
        mv $currentVhost/$site.tar.bz2 $backupLocation
}

# Backup the subdirs.
function backupSites() {
    local currentVhost=$1;

    for site in ${VHOSTS_SITES[*]}
    do

        findThis $currentVhost/$site skip
        if [ $TRUE -eq $? ]; then
            backupCompressThis $currentVhost $site $currentVhost/$BACKUP_LOC;

            if [ $DO_BACKUP_DB -eq $TRUE ]; then
                backupWordPressDB $currentVhost/$site $currentVhost/$BACKUP_LOC;
            fi
        fi;
    done;
}

function findThis() {
    local fileToFind=$1;
    local action=$2;

    if [ ! -e $fileToFind ]; then
        case "$action" in
            skip)
                logIt warn "Cannot find [$fileToFind], skipping...";
                return $FALSE;
                ;;
            exit)
                logIt error "Cannot find [$fileToFind], exiting...";
                exit 1;
                ;;
            *)
                logIt error "Invalid Usage of findThis()";
                exit 1;
                ;;
        esac
    fi;

    return $TRUE;
}

# Start simple host backup
# Try not to create too many functions, keep it extremely simple
# as this script is REALLY meant for Vhosts, but we're nice.
function simple_backup() {
    logIt info "Starting in Simple Host mode...";

    findThis $SIMPLE_SITE_LOC exit;
    findThis $SIMPLE_SITE_LOC/$SIMPLE_HTTPDOC_LOC exit;

    backupCompressThis $SIMPLE_SITE_LOC $SIMPLE_HTTPDOC_LOC $SIMPLE_SITE_LOC/$BACKUP_LOC;

    if [ $DO_BACKUP_DB -eq $TRUE ]; then
        findThis $SIMPLE_WORDPRESS_LOC exit;
        backupWordPressDB $SIMPLE_WORDPRESS_LOC $SIMPLE_SITE_LOC/$BACKUP_LOC;
    fi
}

# Loop though the vhosts.
function vhost_backup() {
    logIt info "Starting in VHOST mode...";

    findThis $VHOST_LOC exit;

    for vhost in ${VHOSTS[*]}
    do
        findThis $VHOST_LOC/$vhost skip
        [[ $TRUE -eq $? ]] && backupSites $VHOST_LOC/$vhost;
    done;
}

function checkDependencies() {
    if [ $DO_BACKUP_DB -eq $TRUE ]; then
        logIt debug "Checking for mysqldump dependency...";

        findThis $MYSQLDUMP_BIN exit;
    fi;
}

# Check for root/sudo privs.
function sudoCheck() {
    if [ $UID != 0 ]; then
        logIt error "Must have root or sudo permissions to execute.";
        exit 1;
    fi;
}

# License blurb
function licenseInfo() {
    echo;
    echo;
    echo;
    echo "vhost-backer  Copyright (C) 2010  Jason Giedymin"
    echo "This program comes with ABSOLUTELY NO WARRANTY'."
    echo "This is free software, and you are welcome to redistribute it";
    echo "under certain conditions";
    echo;
    echo;
    echo;
}

# A message or two and then we start to kick things off.
function start() {
    licenseInfo;

    sudoCheck;

    logIt info "Started backup process at [$DATE]";

    [[ $APP_MODE -eq $VHOST_MODE ]] && vhost_backup;
    [[ $APP_MODE -eq $SIMPLE_HOST_MODE ]] && simple_backup;

    logIt info "To restore, use: mysql -u #username# -p #database# < #dump_file#"
    logIt info "Finished.";
}

#--------------------------------Main-----------------------------------------
start;
