The Python script dedupfs.py implements a file system in user-space using FUSE.
It's called DedupFS because the file system's primary feature is deduplication,
which enables it to store virtually unlimited copies of files because data is
only stored once.

In addition to deduplication the file system also supports transparent
compression using any of the compression methods lzo, zlib and bz2.

These two properties make the file system ideal for backups: The author
currently stores about 250GB worth of backups in an 8GB SQLite database!

The design of DedupFS was inspired by Venti and ZFS.

 USAGE
=======

To use this script on Ubuntu (where it was developed) try the following:

    sudo apt-get install python-fuse
    git clone git://github.com/xolox/dedupfs.git
    mkdir mount_point
    python dedupfs/dedupfs.py --database=~/.dedupfs.sqlite3 mount_point
    # Now copy some files to mount_point/ and observe that the size of the
    # database doesn't grow much when you copy duplicate files again :-)

 STATUS
========

Development on DedupFS began as a proof-of-concept to find out how much disk
space the author could free by employing deduplication to store his daily
backups. Since then it's become more or less usable as a way to archive old
backups, i.e. for secondary storage deduplication. It's not recommended to use
the file system for primary storage though, simply because the file system is
too slow.

 DEPENDENCIES
==============

This script requires the Python FUSE binding in addition to several Python
standard libraries like `sqlite3`, `hashlib` and `cStringIO`.

 CONTACT
=========

If you have questions, bug reports, suggestions, etc. the author can be
contacted at <peter@peterodding.com>. The latest version of DedupFS is
available at <http://peterodding.com/code/dedupfs> and <http://github.com/xolox/dedupfs>.

 LICENSE
=========

DedupFS is licensed under the MIT license.
Copyright 2010 Peter Odding <peter@peterodding.com>.
