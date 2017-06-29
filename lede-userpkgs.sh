#!/bin/bash

############################################################################################################
#                                                                                                          #
#      This script is Free Software, it's licensed under the GPLv2 and has ABSOLUTELY NO WARRANTY          #
#                                                                                                          #
############################################################################################################
#                                                                                                          #
#      Please see the README file for information, LICENSE, Version History and TODO                       #
#                                                                                                          #
############################################################################################################
#                                                                                                          #
#      Name:              lede-userpkgs.sh                                                                 #
#      Version:           0.1.0                                                                            #
#      Date:              Thu, Jun 20 2017                                                                 #
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

SCRIPTN="${0##*/}"                                             # name of this script
LISTPATH="/tmp"                                                # the path where to save the lists
PKGLIST="$LISTPATH/${SCRIPTN%.*}.pkgs.list"                    # default package list
BCKLIST="$LISTPATH/${SCRIPTN%.*}.bck.$(date +%F-%H%M%S).list"  # the backup list copy with date and time
NOLIST=false                                                   # if true: print to screen instead of file
DRYRUN=false                                                   # options for dry run. not there yet

############################

## FUNCTINOS 

## usage commands
usage() {
cat <<USAGE

Usage: $SCRIPTN [options...] command

Available commands:
    help                print this help
    readme              print a verbose version of this help
    update              update the package database (do this at least once. see 'readme' command)
    getlist             create a list of currently manually installed packages to file
    bcklist             backup [the specified] list of packages. do NOT use options here!
    install             read the package list from file and install them
    cleanup             force removal of files created by the script

Options:
    -n                  print getlist to screen instead of writing to file
    -d                  dryn run. possibly for a future version

USAGE
}

readme() {
cat <<README
'$SCRIPTN' can be used:

     -- before sysupgrade: to get a list of currently user manually installed packages.
     -- after  sysupgrade: to reinstall those packages that are not part of the new firmware image.

IMPORTANT: in both cases, run 'update' at least once (before and after sysupgrade!!!)

    $SCRIPTN update

To create a list of the currently installed packages, before the firmware upgrade, execute:

    $SCRIPTN [-n] getlist
    
If you specify the option -n with 'getlist', 'getlist' will print to screen instead of writig to a file

To backup an existing list of packages, just because "why not!?!?":

    $SCRIPTN bcklist

To remove all file list created by the script, run:

    $SCRIPTN cleanup

To reinstall all packages that were not part of the firmware image, after the firmware upgrade, execute:

    $SCRIPTN install

IMPORTANT: run $SCRIPTN update at least once (before and after sysupgrade!!!)

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

## getlist
listget() {
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

getlist() {
if [ $NOLIST == true ]; then
        echo
        echo "Here's the packages that were installed manually. This doesn't write to $PKGLIST:" 
        echo
        listget
        echo
        echo "NOTE: NO list was actually saved or created. Make sure to run: $SCRIPTN getlist"
        echo
    else
        echo
        echo "Saving the package list of the current manually installed packages to $PKGLIST"
        echo
        listget >> "$PKGLIST"
        echo "Done"
        echo
fi
}

############################

## backup
bcklist() {
    if [ -f $PKGLIST ]; then
        if [ -s $PKGLIST ]; then
            echo
            echo "copying the existing '$PKGLIST' to '$BCKLIST'"
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

cleanup() {
# let's get rid of the old packages lists (including backups!!!)
    echo
    echo "Do you want to remove these files (READ THE FILE NAMES)?"
    echo
    rm -i $LISTPATH/*.list
}

############################

install() {
    echo "not implemented yet!!!";
    exit 99
}

############################

## MAIN ##

## parse command line options.....
while getopts "nd" OPTS; do
    case $OPTS in
        n) NOLIST=true;;
        d) DRYRUN=true;;
        *) usage; exit 0;;
    esac
done
shift $(($OPTIND - 1))

## ...and set the command:
while true; do
    case "$1" in
        help) usage; exit 0;;
        readme) usage; readme; exit 0;; 
        update) opkg update; exit 0;;
        getlist) getlist; exit 0;;
        bcklist) bcklist; exit 0;;
        cleanup) cleanup; exit 0;;
        install) install; exit 0;;
        imfeelinglucky) NOLIST=false; DRYRUN=false; update; getlist; install; exit 1000;;
        *) echo; echo "invalid command!!!"; usage; exit 4;;
    esac
done

