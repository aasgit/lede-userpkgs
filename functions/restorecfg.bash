#!/bin/bash

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

