#!/bin/bash

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

    ###  do not use install. see http://github.com/aasgit/lede-buildwrapper instead !!!  ###
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
