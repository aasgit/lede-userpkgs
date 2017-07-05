#!/bin/bash

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

