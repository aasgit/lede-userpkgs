#!/bin/bash

############################################################################################################
#                                                                                                          #
#      This script is Free Software, it's licensed under the GPLv2 and has ABSOLUTELY NO WARRANTY          #
#                                                                                                          #
############################################################################################################
#                                                                                                          #
#      Please see the LICENSE; and the README file for information, Version History and TODO               #
#                                                                                                          #
############################################################################################################
#                                                                                                          #
#      Name:              lede-userpkgs.sh                                                                 #
#      Version:           0.2.2                                                                            #
#      Date:              Sat, Jul 01 2017                                                                 #
#      Author:            Callea Gaetano Andrea (aka cga)                                                  #
#      Contributors:                                                                                       #
#      Language:          BASH                                                                             #
#      Location:          https://github.com/aasgit/lede-userpkgs                                          #
#                                                                                                          #
############################################################################################################

############################

## the script has to be run as root (or with sudo), let's make sure of that:
if [ $EUID != 0 ]; then
    echo
    echo "You must run this script with root powers (sudo is fine too)."
    echo
    exit 1
fi

############################

## GLOBAL VARIABLES

SCRIPTN="${0##*/}"                                          # name of this script
SCRPATH="/tmp/tmp"                                          # the path where to save the lists
PKGLIST="$SCRPATH/opkg.pkgs.list.txt"                       # default package list
INSTLST="$PKGLIST"                                          # the list to install packages from
BCKLIST="$SCRPATH/opkg.pkgs.backup.$(date +%F-%H%M%S).txt"  # the backup list copy with date and time
INSTLOG="$SCRPATH/opkg.pkgs.logs.$(date +%F-%H%M%S).txt"    # log file for the install process. just in case
TEMPLST="$SCRPATH/opkg.pkgs.temp.txt"                       # dependencies list for --install
DEPSLST="$SCRPATH/opkg.pkgs.deps.txt"                       # dependencies list for --install
NOLIST=false                                                # if true: print to screen instead of file
DRYRUN=false                                                # options for dry run

############################

## FUNCTIONS

## usage commands
usage() {
cat <<USAGE

Usage: $SCRIPTN [options...] command

Available commands:
    -h | --help                    print this help and exit
    -r | --readme                  print a verbose version of this help and exit
    -u | --update                  update the opkg package database (do this at least once. see '--readme')
    -g | --gen-list                create a list of currently manually installed packages to file
    -p | --print-list              print a list to screen instead of writing to file
    -b | --backup-list             backup a copy of the list of packages
    -c | --backup-config           backup configuration files with 'sysupgrade'
    -e | --erase-files             interactively remove backup and list files created by the script
    -i | --install                 read the package list from file and install them
    -x | --restore-config          restore configuration files with 'sysupgrade'

Options (see 'readme' command):
    -d | --dry-run                 perform a dry run of --install or --restore-config
    -l | --list                    to use with 'install': manually specifiy a list file

USAGE
}

readme() {
cat <<README
'$SCRIPTN' can be used:

    -- before sysupgrade: to create a list of currently user manually installed packages.
    -- before sysupgrade: to create a backup of configuration files with 'sysupgrade'.
    -- after  sysupgrade: to reinstall the packages that were manually installed by the user.
    -- after  sysupgrade: to restore previously created configuration files with 'sysupgrade'.

IMPORTANT: in both cases, run an update at least once (before and after sysupgrade!!!)

To reinstall all packages that were not part of the firmware image, after the firmware upgrade, use the -i or --install command.

    $SCRIPTN --install

To perform a dry-run of install, it will print on screen instead of executing:

    $SCRIPTN --dry-run --install

To manually specify a different [previously saved] list of pacakges, including path, without this option defaults to '$INSTLST':

    $SCRIPTN --dry-run --list <listfile> --install

To interactively restore previously created configuration files backup from an archive, user -x or --restore-config command.

    $SCRIPTN --dry-run --restore-config

IMPORTANT: run an update at least once (before and after sysupgrade!!!)

README
}

############################

## setlist
listset() {
    ## first: let's get the epoc time of busybox as a date reference
    FLASHTM=$(opkg status busybox | awk '/Installed-Time/ {print $2}')
    ## second: let's get the list of all currently installed packages
    LSTINST=$(opkg list-installed | awk '{print $1}')
    ## now let's use those to determine the user installed packages list
    for PACKAGE in $LSTINST; do
        if [ "$(opkg status $PACKAGE | awk '/Installed-Time:/ {print $2}')" != "$FLASHTM" ]; then
            echo $PACKAGE
        fi
    done
}

setlist() {
if [ $NOLIST == true ]; then
        echo
        echo "Here's a list of the packages that were installed manually. This doesn't write to $PKGLIST:"
        sleep 3
        echo
        listset
        echo
        echo "NOTE: NO list was actually saved or created. Make sure to run: $SCRIPTN --gen-list"
        echo
    else
        echo
        echo "Saving the package list of the current manually installed packages to $PKGLIST"
        echo
        listset >> "$PKGLIST"
        echo "Done"
        echo
fi
}

############################

## backup configuration files, same as:
# - https://lede-project.org/docs/howto/backingup
# - https://wiki.openwrt.org/doc/howto/generic.backup#backup_openwrt_configuration
bckcfg() {
    sysupgrade --create-backup "$SCRPATH/backup-$(cat /proc/sys/kernel/hostname)-$(date +%F-%H%M%S).tar.gz"
}

## backup an existing packages list previously created
bcklist() {
    if [ -f $PKGLIST ]; then
        if [ -s $PKGLIST ]; then
            echo
            cp $PKGLIST $BCKLIST
            echo "Copied the existing '$PKGLIST' to '$BCKLIST'"
            echo
            exit 0
        else
            echo
            echo "The file '$PKGLIST' is empty! Nothing to backup here..."
            echo
            exit 2
        fi
    else
        echo
        echo "The file '$PKGLIST' doesn't exist! Nothing to backup here..."
        echo
        exit 3
    fi
}

############################

erase() {
# let's get rid of the old packages lists (including backups!!!)
    if ls $SCRPATH/opkg.pkgs.*.txt >/dev/null 2>&1 ; then
        local aretherefiles=0
    else
        local aretherefiles=1
    fi

    if ls $SCRPATH/backup-$(cat /proc/sys/kernel/hostname)-*.tar.gz >/dev/null 2>&1 ; then
        local aretherebackups=0
    else
        local aretherebackups=1
    fi

    if [ "$aretherefiles" == 0 ] || [ "$aretherebackups" == 0 ] ; then
        echo
        echo "Do you want to remove these files?"
        echo
        if [ "$aretherefiles" == 0 ] ; then
            rm -i $SCRPATH/opkg.*.txt
        fi
        if [ "$aretherebackups" == 0 ] ; then
            rm -i $SCRPATH/backup-$(cat /proc/sys/kernel/hostname)-*.tar.gz
        fi
        echo
    else
        echo "No files to delete. Bye..."
        exit 4
    fi
}

############################

checkdeps() {
# let's check the dependencies of packages in $INSTLST and create a dependencies list too
    ### not necessary in this script, but leaving it here for now....
    echo
    echo "'checkdeps' is not needed. deps as in mforkel script is pointless here."
    echo "we already have an '$INSTLST' that is made of new pacakges only!!!!!!!!"
    echo "nevertheless, this script includes an improved version, just in case..."
    echo
    while IFS= read -r PACKAGE; do
        opkg status "$PACKAGE" | awk '/Depends/ {for (i=2;i<=NF;i++) print $i}' | sed 's/,//g' >> "$TEMPLST"
        cat "$TEMPLST" | sort -u >> "$DEPSLST"
        rm -f "$TEMPLST" >/dev/null 2>&1
    done < "$INSTLST"
}

############################

install() {
    if [ $INSTLST ]; then
        if [ -f $INSTLST ]; then
            if [ -s $INSTLST ]; then
                echo
                echo "Installing packages from list '$INSTLST' : this may take a while..."
                echo
                if $DRYRUN; then
                    while IFS= read -r PACKAGE; do
                        echo opkg install "$PACKAGE"
                    done < "$INSTLST"
                    echo
                    echo "THIS WAS A DRY-RUN....."
                else
                    while IFS= read -r PACKAGE; do
                        opkg install "$PACKAGE" | tee -a "$INSTLOG"
                    done < "$INSTLST"
                    echo
                    echo "Done! You may want to restore configurations now..."
                    echo
                    echo "A log of --install is available: '$INSTLOG'"
                    echo
                fi
                echo
                exit 0
            else
                echo
                echo "The file '$INSTLST' is empty!!! Can't install from this..."
                echo
                exit 5
            fi
        else
            echo
            echo "The packages list file '$INSTLST' doesn't exist!!! Did you forget to create or save one?"
            echo
            exit 6
        fi
    else
        echo
        echo "You must specify an install list argument to -l --list"
        echo
        exit 99
    fi
}

############################

cfgrestore() {
    if ls $SCRPATH/backup-$(cat /proc/sys/kernel/hostname)-*.tar.gz >/dev/null 2>&1 ; then
        local aretherebackups=0
    else
        local aretherebackups=1
    fi

    if [ "$aretherebackups" == 0 ] ; then
        unset BCKFILES
        local BCKFILES=($(ls $SCRPATH/backup-$(cat /proc/sys/kernel/hostname)-*.tar.gz))
        echo
        echo "These are the available backup files available for you:"
        echo
        OLDPS3=$PS3
        COLUMNS=10
        PS3=$'\nChoose the backup file to restore from by typing the corresponding number: '
        select BACKUP_FILE in "${BCKFILES[@]}" ; do
            if [[ $BACKUP_FILE ]] ; then
                break
            fi
        done
        COLUMNS=
        PS3=$OLDPS3

        echo
        if $DRYRUN; then
            echo "This is a DRY RUN: here's a list of the files in '$BACKUP_FILE':"
            sleep 3
            echo
            sysupgrade --list-backup $BACKUP_FILE
            echo
        else
            read -p "Are you 100% positive about restoring from '$BACKUP_FILE'? [y/N]"
            if [[ $REPLY = [yY] ]] ; then
                echo
                echo sysupgrade --restore-backup $BACKUP_FILE
            else
                echo
                echo "Good choice, make sure about '$BACKUP_FILE' first..."
                echo
                exit 88
            fi
        fi
    else
        echo
        echo "No backup files to restore from were found in $SCRPATH !!!!"
        echo
        exit 99
    fi
    exit 100
}

############################

## MAIN ##

## parse command line options and commands:
while true; do
    case "$1" in
        -h|--help|'') usage; exit 0;;
        -r|--readme) usage; readme; exit 0;;
        -u|--update) opkg update; exit 0;;
        -g|--gen-list) setlist; exit 0;;
        -p|--print-list) NOLIST=true; setlist; exit 0;;
        -b|--backup-list) bcklist; exit 0;;
        -c|--backup-config) bckcfg; exit 0;;
        -e|--erase-files) erase; exit 0;;
        -i|--install) install; exit 0;;
        -l|--list) shift; INSTLST="$1"; shift;;
        -x|--restore-config) cfgrestore; exit 0;;
        -d|--dry-run) DRYRUN=true; shift;;
        *) echo; echo "$SCRIPTN: unknown command '$1'"; usage; exit 127;;
    esac
done

