# DESCRIPTION

This script makes it easy to generate a list of packages from a clean installation of LEDE, after which you have installed and configured a number of extra packages and functionalities. For example:

1. [install](https://lede-project.org/docs/guide-quick-start/start) LEDE [from factory](https://lede-project.org/docs/guide-quick-start/factory_installation) img
2. [install and configure](https://lede-project.org/docs/start) a number of packages you deem necessary for your router
3. use this very script to create an opkg list of 'extra' packages and their configuration files (from previous point)
4. use the opkg list and the configuration files with [lede buildwrapper](https://github.com/aasgit/lede-buildwrapper) to create your own factory img

# DISCLAIMER

This script has not been tested throughly yet and, anyway, its functionality might break pretty easily because of differences between LEDE versions. i.e: packages get renamed, dependencies resolution and things alike. It is meant as both personal use and an itch to scratch. You are better of learning how to create your own 'sysupgrade.bin' image for your router. Read about it [here.](https://lede-project.org/docs/user-guide/imagebuilder)

# LICENSE

This script is Free Software, it's licensed under the GPLv2 and has ABSOLUTELY NO WARRANTY. You can find and read the complete version of the GPLv2 [here.](https://www.gnu.org/licenses/old-licenses/gpl-2.0.en.html) A LICENSE file containing a verbatim copy of the GPLv2 is included in this package.

