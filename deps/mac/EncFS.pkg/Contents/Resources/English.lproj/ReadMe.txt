INTRODUCTION
============

This package will provide support for EncFS (1.3.2-1) for Mac OS X.  If you are using MacPorts/DarwinPorts do not use this package just install the encfs port (sudo port install encfs).

EncFS provides an encrypted filesystem in user-space. It runs without any special permissions and uses the FUSE library and kernel module to provide the filesystem interface. You can find links to source and binary releases below. EncFS is open source software, licensed under the GPL.As with most encrypted filesystems, Encfs is meant to provide security against off-line attacks; ie your notebook or backups fall into the wrong hands, etc. The way Encfs works is different from the “loopback” encrypted filesystem support built into the kernel because it works on files at a time, not an entire block device. This is a big advantage in some ways, but does not come without a cost. 

Mac OS X INSTALLATION
=====================
	
Make sure you have the MacFUSE Core package installed from this disk image or http://code.google.com/p/macfuse/

Running /usr/local/bin/uninstall-EncFs will remove EncFS.

Mac OS X GUI-TOOLS INSTALLATION
=====================
Install the EncFS-Plugin package to add support to MacFusion.

Mac OS X USAGE
==============

All utilities are installed into /usr/local/bin and /usr/local/lib. 

If /usr/local/bin is not in your path please add it to your .bash_profile.
export PATH=/opt/local/bin:/usr/local/sbin:$PATH

For more information on Encfs please visit http://arg0.net/wiki/encfs.
For Mac OS X information see http://chuckknowsbest.com/ikrypt.

Backups
==============

Always have backups of your data.

The control file contains the filesystem parameters, in addition to encrypted key data which is different for every filesystem.. You need both the password and this control file in order to access the data. If you loose either one, there isn’t anything I can do to help. Your password should be considered important data. If you’re not sure you can remember it, then back it up (in a secure manner – either in a password keychain program, or in a secure location).

Change Log
==============
Version 2.0.0
Universal Binary and MacFuse 1.1.1 compatible

Version 1.0.0
This is the first version to support Leopard.