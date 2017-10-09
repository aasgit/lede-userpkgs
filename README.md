# DESCRIPTION

This script makes it easy(-er) to generate a list of packages from a clean installation of LEDE, after which you have installed and configured a number of extra packages and functionalities. For example:

    * install LEDE from factory img
    * install and configure a number of packages
    * use this script to create an opkg list of 'extra' packages and files (from previous point)
    * use the list with https://github.com/aasgit/lede-buildwrapper to create your own factory img

## DISCLAIMER

This script has not been tested throughly yet and, anyway, its functionality might break pretty easily because of differences between LEDE versions. i.e: packages get renamed, dependencies resolution and things alike. It is meant as both personal use and an itch to scratch. You are better of learning how to create your own 'sysupgrade.bin' image for your router. Read about it [here.](https://lede-project.org/docs/user-guide/imagebuilder)

## VERSION AND TODO

See HISTORY for info on version history and TODO.

## LICENSE

This script is Free Software, it's licensed under the GPLv2 and has ABSOLUTELY NO WARRANTY. You can find and read the complete version of the GPLv2 [here.](https://www.gnu.org/licenses/old-licenses/gpl-2.0.en.html) A LICENSE file containing a verbatim copy of the GPLv2 is included in this package.

