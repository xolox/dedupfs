#!/bin/bash

TIMESTAMP="`date +%s`"
ROOTDIR="/tmp/dedupfs-tests-$TIMESTAMP"
MOUNTPOINT="$ROOTDIR/mountpoint"
METASTORE="$ROOTDIR/metastore.sqlite3"
DATASTORE="$ROOTDIR/datastore.db"
WAITTIME=2
TESTNO=1

# Initialization. {{{1

FAIL () {
  FAIL_INTERNAL "$@"
  CLEANUP
  exit 1
}

MESSAGE () {
  tput bold
  echo "$@" >&2
  tput sgr0
}

FAIL_INTERNAL () {
  echo -ne '\033[31m' >&2
  MESSAGE "$@"
  echo -ne '\033[0m' >&2
}

CLEANUP () {

  sleep $WAITTIME

  if ! fusermount -u "$MOUNTPOINT"; then
    FAIL_INTERNAL "$0:$LINENO: Failed to unmount the mount point?!"
  fi

  sleep $WAITTIME

  if ! rm -R "$ROOTDIR"; then
    FAIL_INTERNAL "$0:$LINENO: Failed to delete temporary directory!"
  fi

}

# Create the root and mount directories.
mkdir -p "$MOUNTPOINT"
if [ ! -d "$MOUNTPOINT" ]; then
  FAIL "$0:$LINENO: Failed to create mount directory $MOUNTPOINT!"
  exit 1
fi

# Mount the file system using the two temporary databases.
OPTS="--verify-writes --compress=lzo --metastore=$METASTORE --datastore=$DATASTORE"
if [ "$1" = "-d" ]; then
  python dedupfs.py -fvv $OPTS "$MOUNTPOINT" &
else
  python dedupfs.py $OPTS "$MOUNTPOINT"
fi

# Wait a while before accessing the mount point, to
# make sure the file system has been fully initialized.
sleep $WAITTIME

# Test hard link counts with mkdir(), rmdir() and rename(). {{{1

CHECK_NLINK () {
  NLINK=`ls -ld "$1" | awk '{print $2}'`
  [ $NLINK -eq $2 ] || FAIL "$0:$3: Expected link count of $1 to be $2, got $NLINK!"
}

FEEDBACK () {
  MESSAGE "Running test $1"
}

# Check link count of file system root. {{{2

FEEDBACK $TESTNO
TESTNO=$[$TESTNO + 1]
CHECK_NLINK "$MOUNTPOINT" 2 $LINENO

# Check link count of newly created file. {{{2

FEEDBACK $TESTNO
TESTNO=$[$TESTNO + 1]
FILE="$MOUNTPOINT/file_nlink_test"
touch "$FILE"
CHECK_NLINK "$FILE" 1 $LINENO
CHECK_NLINK "$MOUNTPOINT" 2 $LINENO

# Check link count of hard link to existing file. {{{2

FEEDBACK $TESTNO
TESTNO=$[$TESTNO + 1]

LINK="$MOUNTPOINT/link_to_file"
link "$FILE" "$LINK"
CHECK_NLINK "$FILE" 2 $LINENO
CHECK_NLINK "$LINK" 2 $LINENO
CHECK_NLINK "$MOUNTPOINT" 2 $LINENO
unlink "$LINK"
CHECK_NLINK "$FILE" 2 $LINENO
CHECK_NLINK "$MOUNTPOINT" 2 $LINENO

# Check link count of newly created subdirectory. {{{2

FEEDBACK $TESTNO
TESTNO=$[$TESTNO + 1]

SUBDIR="$MOUNTPOINT/dir1"
mkdir "$SUBDIR"
if [ ! -d "$SUBDIR" ]; then
  FAIL "$0:$LINENO: Failed to create subdirectory $SUBDIR!"
fi

CHECK_NLINK "$SUBDIR" 2 $LINENO

# Check that nlink of root is incremented by one (because of subdirectory created above). {{{2

FEEDBACK $TESTNO
TESTNO=$[$TESTNO + 1]

CHECK_NLINK "$MOUNTPOINT" 3 $LINENO

# Check that non-empty directories cannot be removed with rmdir(). {{{2

FEEDBACK $TESTNO
TESTNO=$[$TESTNO + 1]

SUBFILE="$SUBDIR/file"
touch "$SUBFILE"
if rmdir "$SUBDIR" 2>/dev/null; then
  FAIL "$0:$LINENO: rmdir() didn't fail when deleting a non-empty directory!"
elif ! rm -R "$SUBDIR"; then
  FAIL "$0:$LINENO: Failed to recursively delete directory?!"
fi

# Check that link count of root is decremented by one (because of subdirectory deleted above). {{{2

FEEDBACK $TESTNO
TESTNO=$[$TESTNO + 1]

CHECK_NLINK "$MOUNTPOINT" 2 $LINENO

# Check that link counts are updated when directories are renamed. {{{2

FEEDBACK $TESTNO
TESTNO=$[$TESTNO + 1]

ORIGDIR="$MOUNTPOINT/original-directory"
REPLDIR="$MOUNTPOINT/replacement-directory"
mkdir  -p "$ORIGDIR/subdir" "$REPLDIR/subdir"
for DIRNAME in "$ORIGDIR" "$REPLDIR"; do CHECK_NLINK "$DIRNAME" 3 $LINENO; done
mv -T "$ORIGDIR/subdir" "$REPLDIR/subdir"
CHECK_NLINK "$ORIGDIR" 2 $LINENO
CHECK_NLINK "$REPLDIR" 3 $LINENO

# Write random binary data to file system and verify that it reads back unchanged. {{{1

TESTDATA="$ROOTDIR/testdata"

WRITE_TESTNO=0
while [ $WRITE_TESTNO -le 5 ]; do
  FEEDBACK $TESTNO
  TESTNO=$[$TESTNO + 1]

  NBYTES=$[$RANDOM % (1024 * 512)]
  head -c $NBYTES /dev/urandom > "$TESTDATA"
  WRITE_FILE="$MOUNTPOINT/$RANDOM"
  cp -a "$TESTDATA" "$WRITE_FILE"
  sleep $WAITTIME
  if ! cmp -s "$TESTDATA" "$WRITE_FILE"; then
    FAIL "Failed to verify $WRITE_FILE of $NBYTES bytes!"
    echo "Differences:"
    ls -l "$TESTDATA" "$WRITE_FILE"
    cmp -lb "$TESTDATA" "$WRITE_FILE"
    break
  fi

  rm "$WRITE_FILE" "$TESTDATA"
  WRITE_TESTNO=$[$WRITE_TESTNO + 1]
done

# Cleanup. {{{1

CLEANUP
MESSAGE "All tests passed!"

# vim: ts=2 sw=2 et
