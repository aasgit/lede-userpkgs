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
#      Version:           0.2.3                                                                            #
#      Date:              Sat, Jul 01 2017                                                                 #
#      Author:            Callea Gaetano Andrea (aka cga)                                                  #
#      Contributors:                                                                                       #
#      Language:          BASH                                                                             #
#      Location:          https://github.com/aasgit/lede-userpkgs                                          #
#                                                                                                          #
############################################################################################################

############################

# the script has to be run as root (or with sudo), let's make sure of that:
if [ $EUID != 0 ]; then
    echo
    echo "You must run this script with root powers (sudo is fine too)."
    echo
    exit 1
fi

############################

##### GLOBAL VARIABLES #####
SCRIPTN="${0##*/}"                                          # name of this script
SCRPATH="/tmp/tmp"                                          # the path where to save the lists
PKGLIST="$SCRPATH/opkg.pkgs.list.txt"                       # default package list
INSTLST="$PKGLIST"                                          # the list to install packages from
BCKLIST="$SCRPATH/opkg.pkgs.backup.$(date +%F-%H%M%S).txt"  # the backup list copy with date and time
INSTLOG="$SCRPATH/opkg.pkgs.logs.$(date +%F-%H%M%S).txt"    # log file for the install process. just in case
TEMPLST="$SCRPATH/opkg.pkgs.temp.txt"                       # temp dependencies list for --install-packages
DEPSLST="$SCRPATH/opkg.pkgs.deps.txt"                       # final dependencies list for --install-packages
CFGBCKF="backup-$(cat /proc/sys/kernel/hostname)"           # config files backup file name
NOLIST=false                                                # if true: print to screen instead of write file
DRYRUN=false                                                # options for dry run

############################

###### FUNCTIONS #####
# help command
usage() {
cat <<USAGE

Usage: $SCRIPTN [options...] command

    -h | --help               print this help and exit

    -u | --update             wrapper to update the package database with opkg update
                              (do this at least once, before and after sysupgrade)

backup commands:

    -g | --gen-list           create a list of currently manually installed packages
    -p | --print-list         perform a dry-run of --gen-list and print list to screen
    -b | --backup-list        backup a copy of the list of packages created with --gen-list
    -c | --backup-config      wrapper to backup configuration files with 'sysupgrade'
    -e | --erase-files        interactively remove files that were created with the script

install/restore commands:

    -i | --install-packages   install all packages that were not part of the firmware image,
                              after the firmware upgrade, from a (previously saved) list

    -r | --restore-config     interactive wrapper to restore configuration files
                              from a (previously saved) archive with 'sysupgrade'

Options:
    -d | --dry-run            perform a dry run of --install-packages or --restore-config

    -l | --list               manually specify a different list of pacakges, including path
                              e.g: $SCRIPTN [--dry-run] --list <listfile> --install-packages

USAGE
}

############################

# gen-list command
listset() {
    ## first: let's get the epoc time of busybox as a time reference
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
        # if true: print to screen instead of writing to a file
        echo
        echo "Here's a list of the packages that were installed manually. This doesn't write to $PKGLIST:"
        # let's give the user some time to read the above message
        sleep 3
        echo
        listset
        # let the user know about it, just to avoid confusion and/or mistakes
        echo
        echo "NOTE: NO list was actually saved or created. Make sure to run: $SCRIPTN --gen-list"
        echo
    else
        # else: create the actual packages list and notify the user where it was saved
        echo
        echo "Saving the package list of the current manually installed packages to $PKGLIST"
        echo
        listset >> "$PKGLIST"
        echo "Done"
        echo
fi
}

############################

# backup-config command
bckcfg() {
    # backup the configuration files, same as:
    # - https://lede-project.org/docs/howto/backingup
    # - https://wiki.openwrt.org/doc/howto/generic.backup#backup_openwrt_configuration
    sysupgrade --create-backup "$SCRPATH/$CFGBCKF-$(date +%F-%H%M%S).tar.gz"
}

# backup-list command
bcklist() {
    # if PKGLIST exists:
    if [ -f $PKGLIST ]; then
        # ...and it's not emtpy:
        if [ -s $PKGLIST ]; then
            # backup the package list and notify the user where it was saved
            echo
            cp $PKGLIST $BCKLIST
            echo "Copied the existing '$PKGLIST' to '$BCKLIST'"
            echo
            exit 0
        # ...IF it IS emtpy:
        else
            # let the user know about it, just to avoid confusion and/or mistakes
            echo
            echo "The file '$PKGLIST' is empty! Nothing to backup here..."
            echo
            exit 2
        fi
    # if it DOESN'T exist:
    else
        # let the user know about it, just to avoid confusion and/or mistakes
        echo
        echo "The file '$PKGLIST' doesn't exist! Nothing to backup here..."
        echo
        exit 3
    fi
}

############################

# erase-files command
erase() {
# let's get rid of the old files (packages lists, logs and backups!!!)
    # are any list files found? true | false
    if ls $SCRPATH/opkg.pkgs.*.txt >/dev/null 2>&1 ; then
        local aretherefiles=0
    else
        local aretherefiles=1
    fi

    # are any backup files found? true | false
    if ls $SCRPATH/$CFGBCKF-*.tar.gz >/dev/null 2>&1 ; then
        local aretherebackups=0
    else
        local aretherebackups=1
    fi

    # if files or backups are found...
    if [ "$aretherefiles" == 0 ] || [ "$aretherebackups" == 0 ] ; then
        # let the user decide whether to remove them:
        echo
        echo "Do you want to remove these files?"
        echo
        if [ "$aretherefiles" == 0 ] ; then
            rm -i $SCRPATH/opkg.*.txt
        fi
        if [ "$aretherebackups" == 0 ] ; then
            rm -i $SCRPATH/$CFGBCKF-*.tar.gz
        fi
        echo
    # if no files were found, let's just exit
    else
        echo "No files to delete. Bye..."
        echo
        exit 4
    fi
}

############################

# this is not actually needed or used.
# there is not check-dependencies command
# just making a point.
checkdeps() {
    ### not necessary in this script, but leaving it here for now....
    echo
    echo "'checkdeps' is not needed. deps as in mforkel script is pointless here."
    echo "we already have an '$INSTLST' that is made of manually installed pacakges!!!!!!!!"
    echo "nevertheless, this script includes an improved version, just in case..."
    echo
    # let's remove any stale list first
    rm -f "$TEMPLST" >/dev/null 2>&1
    # let's check the dependencies of packages in $INSTLST and create a dependencies list too
    while IFS= read -r PACKAGE; do
        opkg status "$PACKAGE" | awk '/Depends/ {for (i=2;i<=NF;i++) print $i}' | sed 's/,//g' >> "$TEMPLST"
        cat "$TEMPLST" | sort -u >> "$DEPSLST"
        rm -f "$TEMPLST" >/dev/null 2>&1
    done < "$INSTLST"
}

############################

# install-packages command
install() {
    # if true...
    if [ $INSTLST ]; then
        # ...and if INSTLST exists:
        if [ -f $INSTLST ]; then
            # ...and if INSTLST is not empty:
            if [ -s $INSTLST ]; then
                echo
                echo "Installing packages from list '$INSTLST' : this may take a while..."
                # let's give the user some time to read the above message
                sleep 3
                echo
                # if dryrun: print to screen instead of istalling
                if $DRYRUN; then
                    while IFS= read -r PACKAGE; do
                        echo opkg install "$PACKAGE"
                    done < "$INSTLST"
                    # let the user know about it, just to avoid confusion and/or mistakes
                    echo
                    echo "NOTE: THIS WAS A DRY-RUN..... NO packages were actually installed."
                    echo
                    echo "Make sure to run: $SCRIPTN --install-packages"
                # if not dryrun, let's actually install the packages
                else
                    while IFS= read -r PACKAGE; do
                        opkg install "$PACKAGE" | tee -a "$INSTLOG"
                    done < "$INSTLST"
                    echo
                    # notify the user and provide a log file
                    echo "Done! You may want to restore configurations now..."
                    echo
                    echo "A log of --install-packages is available: '$INSTLOG'"
                    echo
                fi
                echo
                exit 0
            # ...IF it IS emtpy:
            else
                # let the user know about it, just to avoid confusion and/or mistakes
                echo
                echo "The file '$INSTLST' is empty!!! Can't install from this..."
                echo
                exit 5
            fi
        # if it DOESN'T exist:
        else
            # let the user know about it, just to avoid confusion and/or mistakes
            echo
            echo "The packages list file '$INSTLST' doesn't exist!!! Did you forget to create or save one?"
            echo
            exit 6
        fi
    # (it should never get to this point... but as a safety net.
    # if true... ...and it's a command (grep -)
    elif [ $INSTLST ] && grep -q '^-' $INSTLST ; then
            # let the user know about he cannot use commands as arguments...
            echo
            echo "You must specify a valid list argument to -l --list, '$INSTLST' is not a valid argument..."
    # (it should never get to this point... but as a safety net.
    # if false
    else
        # let the user know about it
        echo
        echo "You must specify an install list argument to -l --list"
        echo
        exit 99
    fi
}

############################

# restore-config command
cfgrestore() {
    # are any backup files found? true | false
    if ls $SCRPATH/$CFGBCKF-*.tar.gz >/dev/null 2>&1 ; then
        local aretherebackups=0
    else
        local aretherebackups=1
    fi

    # if backups files are found...
    if [ "$aretherebackups" == 0 ] ; then
        unset BCKFILES
        local BCKFILES=($(ls $SCRPATH/$CFGBCKF-*.tar.gz))
        # prompt the user to select from available backup files
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
            # let's give the user some time to read the above message
            sleep 3
            echo
            sysupgrade --list-backup $BACKUP_FILE
            # notify the user of a dryrun, just to make sure and avoid mistakes or confusion
            echo
            echo "THIS WAS A DRY-RUN....."
            echo
        else
            # if this is NOT a dryrun, let's ask for confirmation once more
            read -p "Are you 100% positive about restoring from '$BACKUP_FILE'? [y/N]  "
            # YES? then restore the backup files... (echo only for now. safe for test)
            if [[ $REPLY = [yY] ]] ; then
                echo
                echo sysupgrade --restore-backup $BACKUP_FILE
                echo
            else
            # NO? let's exit and notify the user
                echo
                echo "Good choice, make sure about '$BACKUP_FILE' first..."
                echo
                exit 88
            fi
        fi
    # if NO backups files are found...
    else
        # let the user know, to avoid mistakes and confusion
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
        -u|--update) opkg update; exit 0;;
        -g|--gen-list) setlist; exit 0;;
        -p|--print-list) NOLIST=true; setlist; exit 0;;
        -b|--backup-list) bcklist; exit 0;;
        -c|--backup-config) bckcfg; exit 0;;
        -e|--erase-files) erase; exit 0;;
        -l|--list) shift; INSTLST="$1"; shift;;
        -i|--install-packages) install; exit 0;;
        -r|--restore-config) cfgrestore; exit 0;;
        -d|--dry-run) DRYRUN=true; shift;;
        *) echo; echo "$SCRIPTN: unknown command '$1'"; usage; exit 127;;
    esac
done

