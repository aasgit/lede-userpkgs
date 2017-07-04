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
#      Version:           0.2.4.3                                                                          #
#      Date:              Tue, Jul 04 2017                                                                 #
#      Author:            Callea Gaetano Andrea (aka cga)                                                  #
#      Contributors:                                                                                       #
#      Language:          BASH                                                                             #
#      Location:          https://github.com/aasgit/lede-userpkgs                                          #
#                                                                                                          #
############################################################################################################

############################

##### GLOBAL VARIABLES #####
SCRIPTN="${0##*/}"                                          # name of this script
SCRPATH="/tmp/tmp"                                          # the path where to save the lists
TMPLIST="$SCRPATH/opkg.pkgs.ltmp.txt"                       # default package list
PKGLIST="$SCRPATH/opkg.pkgs.list.txt"                       # default package list
INSTLST="$PKGLIST"                                          # the list to install packages from
BCKLIST="$SCRPATH/opkg.pkgs.backup.$(date +%F-%H%M%S).txt"  # the backup list copy with date and time
INSTLOG="$SCRPATH/opkg.pkgs.logs.$(date +%F-%H%M%S).txt"    # log file for the install process. just in case
TEMPLST="$SCRPATH/opkg.pkgs.dtmp.txt"                       # temp dependencies list for --install-packages
DEPSLST="$SCRPATH/opkg.pkgs.deps.txt"                       # final dependencies list for --install-packages
CFGBCKF="backup-$(cat /proc/sys/kernel/hostname)"           # config files backup file name
NOLIST=false                                                # if true: print to screen instead of write file
DRYRUN=false                                                # options for dry run

############################

# this script only works with bash. apologies.
if ! which bash >/dev/null 2>&1 || [ -z "$BASH" ]; then
cat <<BASHMSG

    This script requires the bash shell. It does NOT work with ash. Apologies.
    Hopefully the functionalities provided by this script, will be implemented
    in 'sysupgrade' and 'LuCi' by LEDE and/or OpenWRT sooner rather than later.
    Feel free to rewrite the script for ash or reuse the ideas to implement them!

BASHMSG

    exit 1
fi

# the script has to be run as root (or with sudo), let's make sure of that:
if [ $EUID != 0 ]; then
    echo -e "\nYou must run this script with root powers (sudo is fine too).\n"
    exit 2
fi

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
    FLASHTIME=$(opkg status busybox | awk '/Installed-Time/ {print $2}')
    ## second: let's get the list of all currently installed packages
    LISTINSTALLED=$(opkg list-installed | awk '{print $1}')

    # let's remove any stale list first
    rm -f "$TMPLIST" >/dev/null 2>&1

    ## now let's use those to determine the packages that were installed AFTER flashtime
    for PACKAGE in $LISTINSTALLED; do
        if [ "$(opkg status $PACKAGE | awk '/Installed-Time/ {print $2}')" != "$FLASHTIME" ]; then
            echo $PACKAGE >> "$TMPLIST"
        fi
    done

    ## now let's use those to determine the user installed packages list (status is really handy here!)
    while IFS= read -r PACKAGE; do
        if opkg status $PACKAGE | grep -q user; then
            echo $PACKAGE
        fi
    done < "$TMPLIST"
}

setlist() {
if [ $NOLIST == true ]; then
        # if true: print to screen instead of writing to a file
        echo -e "\nHere's a list of the packages that were installed manually. This doesn't write to $PKGLIST:\n"
        # let's give the user some time to read the above message
        sleep 3
        listset
        # let the user know about it, just to avoid confusion and/or mistakes
        echo -e "\nNOTE: NO list was actually saved or created. Make sure to run: $SCRIPTN --gen-list\n"
    else
        # else: create the actual packages list and notify the user where it was saved....
        if [ -f "$PKGLIST" ]; then
            # ...should a list already exist, let the user decide if to create a backup copy, overwrite it or not
            echo
            read -p "The file '$PKGLIST' already exists, do you want to overwrite it? [y/N/b]  "
            case $REPLY in
                [Yy])
                    echo -e "\nSaving the package list of the current manually installed packages to $PKGLIST"
                    rm -f "$PKGLIST" >/dev/null >2&1
                    listset >> "$PKGLIST"
                    echo -e "\nDone\n"
                    exit 3
                    ;;
                [Bb])
                    bcklist
                    exit 4
                    ;;
                *)
                    echo -e "\n'$PKGLIST' was left intact, remember to create a (new) list (should you need a new one)\n"
                    exit 5
                    ;;
            esac
        else
            # if no existing package list file is found, create a new one
            echo -e "\nSaving the package list of the current manually installed packages to $PKGLIST"
            listset >> "$PKGLIST"
            echo -e "\nDone\n"
            exit 6
        fi
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
            echo -e "\nCopied the existing '$PKGLIST' to '$BCKLIST'\n"
        # ...IF it IS emtpy:
        else
            # let the user know about it, just to avoid confusion and/or mistakes
            echo -e "\nThe file '$PKGLIST' is empty! Nothing to backup here...\n"
            exit 7
        fi
    # if it DOESN'T exist:
    else
        # let the user know about it, just to avoid confusion and/or mistakes
        echo -e "\nThe file '$PKGLIST' doesn't exist! Nothing to backup here...\n"
        exit 8
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
        echo -e "\nDo you want to remove these files?\n"
        if [ "$aretherefiles" == 0 ] ; then
            rm -i $SCRPATH/opkg.*.txt
        fi
        if [ "$aretherebackups" == 0 ] ; then
            rm -i $SCRPATH/$CFGBCKF-*.tar.gz
        fi
        echo
    # if no files were found, let's just exit
    else
        echo -e "\nNo files to delete. Bye...\n"
        exit 9
    fi
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
                echo -e "\nInstalling packages from list '$INSTLST' : this may take a while...\n"
                # let's give the user some time to read the above message
                sleep 3
                # if dryrun: print to screen instead of istalling
                if $DRYRUN; then
                    while IFS= read -r PACKAGE; do
                        echo opkg install "$PACKAGE"
                    done < "$INSTLST"
                    # let the user know about it, just to avoid confusion and/or mistakes
                    echo -e "\nNOTE: THIS WAS A DRY-RUN..... NO packages were actually installed.\n"
                    echo -e "Make sure to run: $SCRIPTN --install-packages\n"
                # if not dryrun, let's actually install the packages
                else
                    while IFS= read -r PACKAGE; do
                        opkg install "$PACKAGE" | tee -a "$INSTLOG"
                    done < "$INSTLST"
                    # notify the user and provide a log file
                    echo -e "\nDone! You may want to restore configurations now...\n"
                    echo -e "A log of --install-packages is available: '$INSTLOG'\n"
                fi
            # ...IF it IS emtpy:
            else
                # let the user know about it, just to avoid confusion and/or mistakes
                echo -e "\nThe file '$INSTLST' is empty!!! Can't install from this...\n"
                exit 10
            fi
        # if it DOESN'T exist:
        else
            # let the user know about it, just to avoid confusion and/or mistakes
            echo -e "\nThe packages list file '$INSTLST' doesn't exist!!! Did you forget to create or save one?\n"
            exit 11
        fi
    #... IF FALSE (which should never happen unless $INSTLST=PKGLIST was deleted global variables...)
    else
        echo -e "\nThis is bad.... did you change the value for variable '\$INSTLST' to 'NULL'?\n"
        exit 12
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
        echo -e "\nThese are the available backup files available for you:\n"
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
            echo -e "\nThis is a DRY RUN: here's a list of the files in '$BACKUP_FILE':\n"
            # let's give the user some time to read the above message
            sleep 3
            sysupgrade --list-backup $BACKUP_FILE
            # notify the user of a dryrun, just to make sure and avoid mistakes or confusion
            echo -e "\nTHIS WAS A DRY-RUN.....\n"
        else
            # if this is NOT a dryrun, let's ask for confirmation once more
            read -p "Are you 100% positive about restoring from '$BACKUP_FILE'? [y/N]  ECHO FOR NOW...:  "
            # YES? then restore the backup files... (echo only for now. safe for test)
            if [[ $REPLY = [yY] ]] ; then
                echo -e "\nsysupgrade --restore-backup $BACKUP_FILE\n"
            else
            # NO? let's exit and notify the user
                echo -e "\nGood choice, make sure about '$BACKUP_FILE' first...\n"
                exit 13
            fi
        fi
    # if NO backups files are found...
    else
        # let the user know, to avoid mistakes and confusion
        echo -e "\nNo backup files to restore from were found in $SCRPATH !!!!\n"
        exit 14
    fi
}


############################

###### CHECKS #####
checkdeps() {
# not necessary in this script, but leaving it here anyway...
cat <<CHECKDEPS

    'checkdeps' is not needed. deps as in mforkel script is pointless here.
    '$INSTLST' is made of manually installed pacakges only already!
    Nevertheless, this script includes an improved version, just in case...

CHECKDEPS

    # let's remove any stale list first
    rm -f "$TEMPLST" >/dev/null 2>&1
    # let's check the dependencies of packages in $INSTLST and create a dependencies list too
    while IFS= read -r PACKAGE; do
        opkg status "$PACKAGE" | awk '/Depends/ {for (i=2; i<=NF; i++) print $i}' | sed 's/,//g' >> "$TEMPLST"
        cat "$TEMPLST" | sort -u >> "$DEPSLST"
        rm -f "$TEMPLST" >/dev/null 2>&1
    done < "$INSTLST"
    echo -e "\nA dependecies list is available at '$DEPSLST' for you to check.\n"
}

### let's make absolutely sure that the Options are run with the right Commands
# check for a valid command (to use with the following options checks)
# remember to add any new Commands to this case as well!!
checkvalidcmd() {
    case "$1" in
        -h|--help)
                true;;
        -u|--update)
                true;;
        -g|--gen-list)
                true;;
        -p|--print-list)
                true;;
        -b|--backup-list)
                true;;
        -c|--backup-config)
                true;;
        -e|--erase-files)
                true;;
        -i|--install-packages)
                true;;
        -r|--restore-config)
                true;;
        *)
                echo -e "\n$SCRIPTN: unknown command '$1' \n"
                exit 15
                ;;
    esac
}

# we now check if the right Command is run with --dry-run
checkdryopt() {
    # if the user specifies a dry run, let's make sure that he runs it with [--list] --install-packages or --restore-config
    if $DRYRUN; then
        local dryrunecho="\ne.g: $SCRIPTN --dry-run [--list <listfile>] --install-packages\ne.g: $SCRIPTN --dry-run --restore-config"
        case "$1" in
            -l|--list)
                    true
                    checklistopt
                    ;;
            -i|--install-packages)
                    true
                    ;;
            -r|--restore-config)
                    true
                    ;;
            -d|--dry-run)
                    echo -e "\nyou can specify --dry-run only once.....\n$dryrunecho\n"
                    exit 16
                    ;;
            '')
                    echo -e "\n--dry-run needs an argument:\n$dryrunecho\n"
                    exit 17
                    ;;
            *)
                    echo
                    checkvalidcmd $1
                    echo -e "--dry-run cannot be run with command '$1'\n$dryrunecho\n"
                    exit 18
                    ;;
        esac
    fi
}

# if the user specifies a listfile with --list, let's make sure of a few things first (before passing it to --install)
# this is a bit messy but it seems to be trapping every case and to be working.
# refactoring at some point. for now I am kind of happy about this, even though it's convoluted.
# perhaps a better skilled coder would help.
checklistopt() {
    local listecho="\ne.g: $SCRIPTN [--dry-run] --list <listfile> --install-packages"
    # if the list is not the default and the string is not empty
    if [ "$INSTLST" != "$PKGLIST" ] && [ -n "$INSTLST" ]; then
        #...if it is a directory, error
        if [ -d "$INSTLST" ]; then
            echo -e "\n'$INSTLST' is a directory.\n$listecho\n"
            exit 19
        #...if the file doesn't exist, error
        elif [ ! -e "$INSTLST" ]; then
            echo -e "\nthe file '$INSTLST' doesn't exist.\n$listecho\n"
            exit 20
        fi
        # if --list has an additional argument...
        if [ "$1" ] && [ "$2" ]; then
            # let's make sure it is the proper one
            case "$2" in
                # ...it cannot be --list again
                -l|--list)
                        echo -e "\nyou can specify --list only once.....\n$listecho\n"
                        exit 21;;
                # ...it cannot be --dry-run
                -d|--dry-run)
                        echo -e "\n--dry-run must precede the --list command\n\n$listecho\n"
                        exit 22;;
                # --install-packages is OK
                -i|--install-packages)
                        true;;
                # everything else is checked to be a valid command or error
                *)
                        echo
                        echo
                        checkvalidcmd $2
                        echo -e "--list cannot be run with command '$2':\n$listecho\n"
                        exit 23;;
            esac
        # ... if --list is the only argument....
        elif [ "$1" ]; then
            #...and it's not a file nor a directory...
            if [ ! -f "$INSTLST" ] && [ ! -d "$INSTLST" ]; then
                case "$1" in
                    # ...it cannot be --list again
                    -l|--list)
                        echo -e "\nyou can specify --list only once.....\n$listecho\n"
                        exit 24;;
                    # ...it cannot be --dry-run
                    -d|--dry-run)
                        echo -e "\n--dry-run must precede the --list command\n$listecho\n"
                        exit 25;;
                    # ...it cannot be --install-packages without a valid listfile
                    -i|--install-packages)
                        echo -e "\n--install-packages must follow --list with a valid list file\n$listecho\n"
                        exit 26;;
                    #...it cannot be a not allowed command or an invalid command
                    -*)
                        echo
                        checkvalidcmd $1
                        echo -e "\n--list cannot be run with command '$1':\n$listecho\n"
                        exit 27;;
                    #...THIS should never happen. Just trapping a possible exception
                    *)
                        echo -e "\nEXCEPTION 999\n"
                        exit 999;;
                esac
            #...if it is a file and no --install-packages was specified, then error
            elif [ -f "$INSTLST" ] && [ "$1" != "--install-packages" ]; then
                echo -e "\nYou only have specified a file '$INSTLST'\nYou must use this with --install-packages!\n$listecho\n"
                exit 28
            fi
        fi
    # if the string is emtpy, then we make sure it fails
    elif [ -z $"$INSTLST" ]; then
        echo -e "\n--list requires an argument and it must be a valid list file:\n$listecho\n"
        exit 29
    fi
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
        -i|--install-packages) install; exit 0;;
        -r|--restore-config) cfgrestore; exit 0;;
        -d|--dry-run) DRYRUN=true; shift; checkdryopt "$1";;
        -l|--list) shift; INSTLST="$1"; checklistopt "$1" "$2"; shift;;
        *) echo; echo "$SCRIPTN: unknown command '$1'"; echo; exit 127;;
    esac
done

