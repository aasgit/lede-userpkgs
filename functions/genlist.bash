#!/bin/bash

# gen-list command
listset() {
    ## first: let's get the epoc time of busybox as a time reference
    FLASHTIME=$(opkg status busybox | awk '/Installed-Time/ {print $2}')
    ## second: let's get the list of all currently installed packages
    LISTINSTALLED=$(opkg list-installed | awk '{print $1}')

    # let's remove any stale list first (just in case)
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

    # let's remove the TMPLIST, we don't need it anymore
    rm -f "$TMPLIST" >/dev/null 2>&1
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
                    rm -f "$PKGLIST" >/dev/null 2>&1
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


