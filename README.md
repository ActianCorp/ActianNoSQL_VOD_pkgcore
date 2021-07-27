# pkgcore

This script was build to be used specifically for VOD, once the database process crashes generating a core file. It is intended to collect the core file and the dynamic libraries linked correctly in two compressed tar files. These tar files can be used later when debugging a core file in a machine where the core wasn't originated.


This is an example showing how to use the pkgcore script for any core file. It MUST be called in the machine where the core file was generated.

Usage:

    ./pkgcore.sh <case# or OutputFilename> <Corefile> <PID of process | Path to Executable>

Example:

bash-4.1$ ./pkgcore.sh cleanbe_28283 core_cleanbe_28283.28283  `oscp -r`/bin/cleanbe

Packaging Linux Coredump for remote debugging.
  pkgcore.sh version 2021.07.27 11:00 PDT
----------------------------------------------
Third argument appears to be Executable = /work/aperrell/build/aperrell_VOD_8.0.2/rhel6.5_gpp44_64bit-dbg/versant_root/bin/cleanbe

Using corefile: /work/aperrell/build/aperrell_VOD_8.0.2/rhel6.5_gpp44_64bit-dbg/db/core_cleanbe_28283.28283 


Server Crash for database:  -no

Creating temporary work directory: /tmp/2019-May-9-15-08-08-28836
Using ldd of /work/aperrell/build/aperrell_VOD_8.0.2/rhel6.5_gpp44_64bit-dbg/versant_root/bin/cleanbe for Libraries
Using /work/aperrell/build/aperrell_VOD_8.0.2/rhel6.5_gpp44_64bit-dbg/versant_root/bin/cleanbe as the executable

Found executable file: /work/aperrell/build/aperrell_VOD_8.0.2/rhel6.5_gpp44_64bit-dbg/versant_root/bin/cleanbe

Using /usr/bin/gdb for complete list of Libraries
Adding libthread_db.so.1 matching libpthread.so.0 to enable POSIX thread debugging

Packaging and Compressing Core File...
-rw-r--r-- aperrell/ftp 168488712 2019-05-09 14:52 core_cleanbe_28283.28283

Packaging and Compressing Executable, Libraries and Ancillary Files...
-rwxr-xr-x aperrell/ftp 43559867 2018-10-24 11:59 cleanbe

drwxr-xr-x aperrell/ftp        0 2019-05-09 15:08 libs/

drwxr-xr-x aperrell/ftp        0 2019-05-09 15:08 libs/etc/

-rw-r--r-- root/root       76104 2019-04-17 16:11 libs/etc/ld.so.cache

drwxr-xr-x aperrell/ftp        0 2019-05-09 15:08 libs/usr/

drwxr-xr-x aperrell/ftp        0 2019-05-09 15:08 libs/usr/lib64/

-rwxr-xr-x root/root      989840 2013-07-19 06:02 libs/usr/lib64/libstdc++.so.6

drwxr-xr-x aperrell/ftp        0 2019-05-09 15:08 libs/lib64/

-rwxr-xr-x root/root       34008 2013-11-05 18:00 libs/lib64/libthread_db.so.1

-rwxr-xr-x root/root       31992 2013-10-23 00:06 libs/lib64/libnss_sss.so.2

-rwxr-xr-x root/root     1926800 2013-11-05 18:00 libs/lib64/libc.so.6

-rwxr-xr-x root/root      156928 2013-11-05 18:00 libs/lib64/ld-linux-x86-64.so.2

-rwxr-xr-x root/root       93320 2013-07-19 06:02 libs/lib64/libgcc_s.so.1

-rwxr-xr-x root/root      599384 2013-11-05 18:00 libs/lib64/libm.so.6

-rwxr-xr-x root/root       22536 2013-11-05 18:00 libs/lib64/libdl.so.2

-rwxr-xr-x root/root      145896 2013-11-05 18:00 libs/lib64/libpthread.so.0

-rwxr-xr-x root/root       65928 2013-11-05 18:00 libs/lib64/libnss_files.so.2

drwxr-xr-x aperrell/ftp        0 2019-05-09 15:08 extras/

-rw-r--r-- aperrell/ftp      115 2019-05-09 15:08 extras/uname.txt

-rw-r--r-- aperrell/ftp        0 2019-05-09 15:08 extras/uname.errors

-rw-r--r-- aperrell/ftp      105 2019-05-09 15:08 .gdbinit

-rwxr-xr-x aperrell/ftp       18 2019-05-09 15:08 opencore

-rw-r--r-- aperrell/ftp       72 2019-05-09 15:08 error.log

drwxr-xr-x aperrell/ftp        0 2019-05-09 15:08 info/

-rw-r--r-- aperrell/ftp      244 2019-05-09 15:08 info/file.txt

lrwxrwxrwx aperrell/ftp      0 2019-05-09 15:08 corefile -> core_cleanbe_28283.28283

lrwxrwxrwx aperrell/ftp      0 2019-05-09 15:08 executable -> cleanbe

Cleaning up

Please upload the following two files to the Case Files for your support case:

-rw-r--r-- 1 aperrell ftp 26015876 May  9 15:08 cleanbe_28283_corefiles.tar.gz

-rw-r--r-- 1 aperrell ftp 20699117 May  9 15:08 cleanbe_28283_libraries.tar.gz

bash-4.1$ 

