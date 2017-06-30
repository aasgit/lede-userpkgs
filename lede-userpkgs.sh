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
#      Version:           0.2.0                                                                            #
#      Date:              Fri, Jun 30 2017                                                                 #
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
SCRPATH="/tmp"                                             # the path where to save the lists
PKGLIST="$SCRPATH/opkg.pkgs.list"                          # default package list
BCKLIST="$SCRPATH/opkg.pkgs.$(date +%F-%H%M%S).list"       # the backup list copy with date and time
INSTLST="$PKGLIST"                                          # the list to install packages from
NOLIST=false                                                # if true: print to screen instead of file
DRYRUN=false                                                # options for dry run. not there yet
GENASH=false                                                # generate a script of what 'install' would do

############################

## FUNCTINOS

## usage commands
usage() {
cat <<USAGE

Usage: $SCRIPTN [options...] command

Available commands:
    -h   --help          print this help
    -r   --readme        print a verbose version of this help
    -u   --update        update the package database (do this at least once. see 'readme' command)
    -g   --gen-list      create a list of currently manually installed packages to file
    -p   --print-list    print a list to screen instead of writing to file
    -b   --backup-list   backup a copy of the list of packages
    -c   --backup-config backup configuration files with 'sysupgrade'
    -e   --erase         remove the list files created by the script
    -i   --install       read the package list from file and install them

Options (see 'readme' command):
    -l   --list          to use with 'install': manually specifiy a list
    -s   --gen-script    to use with 'install': output a script
    -d   --dry-run       to use with 'install': perform a dry run

USAGE
}

readme() {
cat <<README
'$SCRIPTN' can be used:

    -- before sysupgrade: to create a list of currently user manually installed packages.
    -- after  sysupgrade: to reinstall those packages that are not part of the new firmware image.

IMPORTANT: in both cases, run an update at least once (before and after sysupgrade!!!)

To reinstall all packages that were not part of the firmware image, after the firmware upgrade, use the -i or --install command.

To manually specify a [saved] list of pacakges, including path, without this option defaults to '$INSTLST':

    $SCRIPTN [-l|--list] listname install

To perform a dry-run of install, it will print on screen instead of executing:

    $SCRIPTN [-d|--dry-run] install

To create a script file of what install would do, to examine and execute later:

    $SCRIPTN [-s|--gen-script] install

IMPORTANT: run an update at least once (before and after sysupgrade!!!)

README
}

############################

## update list of available packages
update() {
    echo
    echo "Updating the package list...."
    opkg update 2>&1 >/dev/null
    echo
    echo "Done!"
}

############################

## setlist
listset() {
    ## first: let's get the epoc time of busybox as a date reference
    FLASHTM=$(opkg status busybox | awk '/Installed-Time/ {print $2}')
    ## second: let's get the list of all currently installed packages
    LSTINST=$(opkg list-installed | awk '{print $1}')
    ## now let's use those to determine the user installed packages list
    for i in $LSTINST; do
        if [ "$(opkg status $i | awk '/Installed-Time:/ {print $2}')" != "$FLASHTM" ]; then
            echo $i
        fi
    done
}

setlist() {
if [ $NOLIST == true ]; then
        echo
        echo "Here's the packages that were installed manually. This doesn't write to $PKGLIST:"
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
### https://lede-project.org/docs/howto/backingup
### https://wiki.openwrt.org/doc/howto/generic.backup#backup_openwrt_configuration
bckcfg() {
    sysupgrade --create-backup "$SCRPATH/backup-$(cat /proc/sys/kernel/hostname)-$(date +%F-%H%M%S).tar.gz"
}

## backup an existinf packages list previously created
bcklist() {
    NOLIST=false # let reset this to false. just in case.
    DRYRUN=false # let reset this to false. just in case.
    GENASH=false # let reset this to false. just in case.

    if [ -f $PKGLIST ]; then
        if [ -s $PKGLIST ]; then
            echo
            echo "Copied the existing '$PKGLIST' to '$BCKLIST'"
            cp $PKGLIST $BCKLIST
            echo
            exit 0
        else
            echo
            echo "the file '$PKGLIST' is empty! nothing to backup here..."
            echo
            exit 2
        fi
    else
        echo
        echo "the file '$PKGLIST' doesn't exist! nothing to backup here..."
        echo
        exit 3
    fi
}

############################

erase() {
# let's get rid of the old packages lists (including backups!!!)
    if ls $SCRPATH/opkg.*.list 2>&1 >/dev/null; then
        echo
        echo "Do you want to remove these files (READ THE FILE NAMES)?"
        echo
        rm -i $SCRPATH/opkg.*.list
        rm -i $SCRPATH/backup-$(cat /proc/sys/kernel/hostname)-*.tar.gz
        echo
    else
        echo "No files to delete. Bye..."
        exit 4
    fi
}

############################

install() {
    if [ $INSTLST ]; then
        if [ -f $INSTLST ]; then
            if [ -s $INSTLST ]; then
                echo "install routine"
                exit 0
            else
                echo
                echo "the file '$INSTLST' is empty!!! Can't install from this..."
                echo
                exit 5
            fi
        else
            echo
            echo "The packages list file '$INSTLST' doesn't exist!!! Did you forget to create one or save it?"
            echo
            exit 6
        fi
        echo "not implemented yet!!!"
        exit 99
    else
        echo "You must specify an install list argument to -l --list"
        exit 99
    fi
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
        -e|--erase) erase; exit 0;;
        -i|--install) install; exit 0;;
        -l|--list) shift; INSTLST="$1"; shift;;
        -s|--gen-script) GENASH=true; shift;;
        -d|--dry-run) DRYRUN=true; shift;;
        *) echo; echo "$SCRIPTN: unknown command '$1'"; usage; exit 127;;
    esac
done

