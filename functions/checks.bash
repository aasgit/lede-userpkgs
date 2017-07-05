#!/bin/bash

###### CHECKS #####
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

#checkcommands() {
#}


