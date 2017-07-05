#!/bin/bash

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

