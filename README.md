# DESCRIPTION

The purpose of this script is to obviate a functionality currently missing on LEDE/OpenWRT backup/restore procedure. Read about installing and upgrading [here.](https://lede-project.org/docs/guide-quick-start/start)

This script makes it easy(-er) to reinstall packages after a sysupgrade, at least until the features offered here, wil be integrated in official tools. With this script (until proven unecessary by official tools), you can:

    * before sysupgrade: create a list of currently manually installed packages.
    * before sysupgrade: create a backup of configuration files with 'sysupgrade'.
    * after  sysupgrade: reinstall the packages that were manually installed by the user.
    * after  sysupgrade: restore previously created configuration files with 'sysupgrade'.

See HISTORY for info on version history and TODO.

## LICENSE

This script is Free Software, it's licensed under the GPLv2 and has ABSOLUTELY NO WARRANTY
You can find and read the complete version of the GPLv2 [here.](https://www.gnu.org/licenses/old-licenses/gpl-2.0.en.html)

A LICENSE file containing a verbatim copy of the GPLv2 is included in this package.

## FAQ

* Q:  Does it actually work??
* A:  The logic of the script is pretty solid and everything, but the actual restore/reinstall, has been tested. I'll test the 'after sysupgrade' once I'll actually do 'sysupgrade' myself.

* Q:  Where did you get the process??
* A:  This script was inspired by [this thread](https://forum.openwrt.org/viewtopic.php?id=42739) (some ideas were taken from mkforkel script). The 'getlist' functionality is based on this [snippet.](https://gist.github.com/devkid/8d4c2a5ab62e690772f3d9de5ad2d978)

* Q:  Can I trust this script?
* A:  This script has not been tested in the real world just yet, and it comes with absolutely no warranty.

* Q:  Why do I have to run this script as root?
* A:  Because updating the packages requires root privileges. Note: you could also use a user with 'sudo' powers.

* Q:  Can I help somehow??
* A:  Yes indeed. Help (especially test and feedback) and ideas are welcome =)

* Q:  Great!! Can I contact you??
* A:  For any suggestions and contributions contact cga @ callea (._dot_.) gaetano (_.dot_.) andrea (._at_.) gmail (._dot_.) com

* Q:  Can I reuse the script to make my own??
* A:  Hey this is Free Software!! you can do whatever the licence I chose allows you to. AS LONG AS YOU RESPECT THE LICENCE ITSELF of course ;)

* Q:  Can I reuse the idea to make an application??
* A:  Hopefully these features will be provided by LEDE/OpenWRT ('sysupgrade' or 'LuCi') at some point.
