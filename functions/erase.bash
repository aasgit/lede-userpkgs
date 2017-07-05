#!/bin/bash

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

