#!/bin/bash
#########
#
# Collect and package libraries used by Application 
# and other libraries needed to read a corefile 
# on a system other than the one that generated it.
#
# Latest Copy should always be located at: 
# /net/bur-home1.east/global/export/home1/43/ra138236/bin/pkgcore.sh
#
# Usage:
#
#   pkgcore {case# or package file} {corefile} [processid|Executable]
#   Note: processid & Executabe will only be used on Solaris 7 and 
#         earlier versions of Solaris, it will be ignored on Solaris 8	
#         and later versions 
#
# Output:
#
#	casenumber_libraries.tar.gz
#	casenumber_corefile.tar.gz
#
# Limitations
#
# Some of the referenced libraries can be accessed via more than one link/path
# the path/link used but this script may differ from the one that gdb will want
# to use locally, especially if the libraries are found using an executable versus
# the corefile or PID, adding the additional links when unpacking the data may be required
#
# When checking for previous output files it only checks for gzipped versions
#
# Note when Editing
#
# Please place more static and system wide information into the ${UNIQUEBASE}/extras directory
# and more dynamic and corefile related information into the ${UNIQUEBASE}/info directory
# this will allow multiple core files to be processed and only the  casenumber_corefile.tar.*
# file to be sent to Versant as the libraries and executeable are not likely to change between 
# two crashes, etc..
#
# Variables used within the script
#
# $LINUXVERSION integer which is the Linux kernel version (or the number after the second  decimal point in uname -r )
# $CASENUMBER used to uniquely package the data and hopefully to keep all the corefile data straight
# $COREFILE absolute path to the corefile being processed
# $EXEFILE absolute path to the executable file 
# $THIRDARG determination if $3 is a PID or Executable ( will be "PID" or "EXE" respectively )
# 
# 
#
#
#
# Change Log
#
# 2005-May-12: initial creation
# 2005-May-16: Finished up work to allow use on Solaris 7 and possibly earlier versions of Solaris
# 2005-May-17: created and saved a simple opencore script to be included in core archive
# 2005-May-26: Fixed bug where script would crash if Case# contained '/' which is not valid within a filename
# 2005-Jul-07: Discovered case where UNIQUEBASE contained a space which broke script
# 2005-Jul-08: Fixed issue, date was space padding output, removed spaces
# 2005-Nov-05: added logic to allow it to function on Solaris X86.  This is not simple because where as on
#		sparc the pmap lists the executable as being the first file mapped into the address space, this
#		is not the case on x86, I am guessing that the executable is always mapped in between the stack
#		and heap and it is the ONLY file mapped into this space, if this  is not true the script will fail
# 2005-Nov-06: Also found a problem if the executable does not exist in the same location it did when the corefile
#		was created and it's not in PATH ... mostly fixed...see limitations
# 2006-Apr-29: Previous to Solaris 10, /lib and /usr/lib were symbolicly linked together, this changed in Solaris 10.
#		Since they are different in Solaris 10 and could possibly be different the script should be altered to 
#		grab any _db libraries from the /lib as well as /usr/lib directory. Fixed by also grabbing debugging
#		libraries from the /lib directory.
# 2008-Aug-28: (Joe Sottile) Converted for RHEL4 from Solaris version so I can debug customer RHEL coredumps!!!!!
# 2013.04.11: (Joe Sottile) Converted for RHEL5 to get full library list and ignore vdso pseudo-library
# 2013.04.24: (Joe Sottile) Changed .gdbinit and opencore to fix chicken-before-egg problem. Now everything loads
#                           properly.
# 2013.04.29: (Joe Sottile) Changed .gdbinit to set a search path for libthread_db.so.1 and modified gdb parser
#                           to work with GDB 7.6 as well as GDB 7.0. Added code for gdb 7.0 to use found libpthread
#                           and get the libthread_db from that directory. Allow PATH to override location of gdb.
#                           Make a concerted effort to enable POSIX thread debugging. Compress while tarring for
#							corefiles. Added update date and script output header message identifying UPDATEDATE
# 2014.08.28: (Joe Sottile) Added copy of this script to the extras directory.
# 2015.06.02: (Joe Sottile) For server (cleanbe/obe) crashes, get LOGFILE and systrace dump into extras 
# 2015.06.03: (Joe Sottile) Also copy saved systrace and vbb binary files to extras for database crashes
# 2019.01.23: (Joe Sottile) Use start directory; Add support for VOD 9 server (vserver) process; find OSCP;
#                           find GDB; find GZIP; Use START with script origin if path does not begin with /;
#                           Still not sure why customer has problems with ls -l or gzip -9; Change reporting message
#                           at end to reference adding files to Actian Support Case.
# 2019.01.29: (Joe Sottile) Added more explicit path to some files. Added whole gdb stack dump to info
#                           Allow Linux 7 (kernel 3.10). Moved core-specific stuff from extras to info, per original
#                           documented intent. Did a lot of explicit path additions for utilities.
# 2019.03.27: (Joe Sottile): Fix issue with undefined ${cwd} and rework to use `pwd` for START. Fix some syntax issues
#                            involving empty else blocks (comment only)
# 2021.07.27: (Joe Sottile): Change final message to refer to uploading files to support case instead of emailing
#                            files to an obsolete email address (support@versant.com)
#
#####
#

# ADDED UPDATE DATE STRING!!!
UPDATEDATE="2021.07.27 10:25 PST"

# Show program header identifying current date
/bin/echo "Packaging Linux Coredump for remote debugging."
/bin/echo "  pkgcore.sh version ${UPDATEDATE}"
/bin/echo "----------------------------------------------"

# Save starting point so we know where $0 is executed from in case we have cd'd
START=`pwd`/
if /usr/bin/test \( "${START}" = "//" \)
    then
		# Remove duplicate directory separator in case we are executed at root directory
	    START=/
	fi

UNIQUEBASE=`/bin/date +"/tmp/%Y-%B-%e-%H-%M-%S-$$" | /bin/sed -e 's/ //g'`
release=`/bin/uname -r`
PATH=$PATH:/usr/bin

if /usr/bin/test  \( $# -ne 3 \)
  then
	/bin/echo
	/bin/echo "Usage: $0 <case# or OutputFilename> <Corefile> <PID of process | Path to Executable>"
	/bin/echo
	/bin/echo "Note: PID or Executable is required"
	/bin/echo
	exit 1;
fi

# Check OS major version only know how to work within version 2.6.9 and 2.6.16 (Linux 6)
# Also allow 3.10 (Linux 7)
# Also allow 4.18 (Linux 8)
if /usr/bin/test  \( `/bin/echo $release | /bin/cut -d. -f1-2` \!= "2.6" -a `/bin/echo $release | /bin/cut -d. -f1-2` \!= "3.10" -a `/bin/echo $release | /bin/cut -d. -f1-2` \!= "4.18"\)
   then
	/bin/echo "Which version of Linux OS are you using (RHEL 6 and 7 supported)?"
	/bin/uname -a
	if /usr/bin/test -r /etc/redhat-release
	then
	    /bin/cat /etc/redhat-release
	fi
fi

LINUXVERSION=`/bin/echo $release | /bin/cut -d. -f3 `

	if /usr/bin/test \( $# -lt 3 \)
  	  then
          /bin/echo "[PID] or Executable is required"
	      exit 1
	fi
	# Test for type of Third Argument now to avoid duplicate testing later
	if /usr/bin/kill -0 $3 2>/dev/null 
	   then
		    /bin/echo "Third argument appears to be a PID = $3"
		    THIRDARG="PID"
	   else
		if /usr/bin/test \! -x $3
		  then
			/bin/echo
			/bin/echo "Third argument does not seem to be a PID or Executable"
			/bin/echo "Please check $3 and try again"
			/bin/echo
			exit 1;
		  else
			if /usr/bin/file $3 | /bin/grep 'ELF.*-bit.*executable' 2>&1 >/dev/null
			  then
				/bin/echo "Third argument appears to be Executable = $3"
				THIRDARG="EXE"
			  else
				/bin/echo
				/bin/echo "Is $3 a link or start script? Please check!"
				/bin/echo "Binary Executable needed as argument"
				/bin/echo
				exit 1;
			fi
		fi
	fi

# Need to check for and sanitize the CASENUMBER to ensure that there are no characters which would cause problems 
# being in a filename NEED to check for the following characters and change them as follows
#  '/' => '-' 

if /bin/echo $1 | /bin/grep "[/]" 2>&1 >/dev/null
  then
	/bin/echo
	/bin/echo "CASENUMBER contains characters which are not valid within a filename ... fixing"
	/bin/echo "Changing \"$1\" "
	CASENUMBER=`/bin/echo $1 | /bin/sed -e "s|/|-|g" `
	/bin/echo "to \"$CASENUMBER\" "
  else
	CASENUMBER=$1
fi

# Checking for existence of output files
if /usr/bin/test \( -s "${CASENUMBER}_libraries.tar.gz" \) -o \
		\( -s "${CASENUMBER}_corefile.tar.gz" \)
  then
	/bin/echo
	/bin/echo "${CASENUMBER}_libraries.tar.gz or ${CASENUMBER}_corefile.tar.gz"
	/bin/echo "exists in the current directory, please remove or rename and try again."
	/bin/echo
	exit 1
fi

# verify that corefile exists and is readable
if /usr/bin/test `/bin/echo $2 | /bin/cut -c -1` = "/" 
  then
	COREFILE=$2
  else
	COREFILE=${START}$2
fi

if /usr/bin/test \! \( -f $COREFILE  -a  -r $COREFILE \)
  then
	/bin/echo
	/bin/echo "${COREFILE} is not readable, please check filename and permissions"
	/bin/echo "and try again..."
	/bin/ls -ald ${COREFILE}
	/bin/echo
	exit 1
fi

/bin/echo
/bin/echo "Using corefile: $COREFILE "
/bin/echo

DATABASE=`/usr/bin/file $COREFILE | /bin/egrep -e "from 'cleanbe " -e "from 'obe " -e "from 'vserver " | /bin/awk -F\' ' { print $2 } ' | /bin/awk ' { print $NF } '`
TIMEMARK=` /bin/ls -l --time-style=+%Y%m%dT%H%M%S $COREFILE | awk ' { print $6 } '`
if /usr/bin/test \( -n "${DATABASE}" \)
    then
	/bin/echo
	/bin/echo "Server Crash for database: " $DATABASE
	/bin/echo
fi

/bin/echo "Creating temporary work directory: ${UNIQUEBASE}"
/bin/mkdir ${UNIQUEBASE}
/bin/mkdir ${UNIQUEBASE}/info
/bin/mkdir ${UNIQUEBASE}/extras

if /usr/bin/test \! \( -d "${UNIQUEBASE}" -a -w "${UNIQUEBASE}" \)
   then
	/bin/echo
	/bin/echo "Problem creating my work directory, please check/fix..."
	/bin/ls -ald ${UNIQUEBASE}
	/bin/echo
	exit 1
fi

# 2019.01.23 Only attempt OSCP stuff if oscp is found
# 0) set path to OSCP to blank
OSCP=
# 1) Try to find oscp in VERSANT_ROOT
if /usr/bin/test \( -n "{$VERSANT_ROOT}" -a -d ${VERSANT_ROOT}/bin -a -x ${VERSANT_ROOT}/bin -a -x ${VERSANT_ROOT}/bin/oscp \)
    then
		OSCP=${VERSANT_ROOT}/bin/oscp
	else
# 2) Try to find oscp in path
        OSCP=`/usr/bin/which oscp 2>/dev/null` #silently
	fi

# Copy LOGFILE and dump systrace from database directory to info
if /usr/bin/test \( -n "${DATABASE}" -a -n "${OSCP}" -a -d `${OSCP} -d`/${DATABASE} -a -x `${OSCP} -d`/${DATABASE} -a -r `${OSCP} -d`/${DATABASE} \)
    then
        if /usr/bin/test \( -r `${OSCP} -d`/${DATABASE}/LOGFILE \)
        then
            /bin/cp -pf `${OSCP} -d`/${DATABASE}/LOGFILE ${UNIQUEBASE}/info >/dev/null 2>&1
        fi
	MACHINE=`uname -n`
	if /usr/bin/test \( -r `${OSCP} -d`/${DATABASE}/${DATABASE}_${MACHINE}_*_${TIMEMARK}.vbb \)
	then
	    /bin/cp -pf `${OSCP} -d`/${DATABASE}/${DATABASE}_${MACHINE}_*_${TIMEMARK}.vbb ${UNIQUEBASE}/info >/dev/null 2>&1
	fi
	if /usr/bin/test \( -r `${OSCP} -d`/${DATABASE}/${DATABASE}_${MACHINE}_*_${TIMEMARK}.systrace \)
	then
	    /bin/cp -pf `${OSCP} -d`/${DATABASE}/${DATABASE}_${MACHINE}_*_${TIMEMARK}.systrace ${UNIQUEBASE}/info >/dev/null 2>&1
	fi
    `${OSCP} -r`/bin/dbtool -trace -database ${DATABASE} -view >${UNIQUEBASE}/info/systrace.out 2>/dev/null
fi

##########################################
####                                  ####
#### Build list of libraries which    ####
#### will be collected with core file ####
####                                  ####
##########################################

# Creating library request list

/bin/ls -1 /etc/ld.so.cache /etc/ld.so.preload 2>&1 | /bin/grep -v "No such file or directory" > ${UNIQUEBASE}/request.list

# Gather libraries used by the Application that created the corefile
# On all Linux it can be taken from a copy of the running
# process or by referencing the executable itself (running process is better)

	# check if the Argument is a process
	if /usr/bin/test $THIRDARG = "PID"
	   then
		/bin/echo "Using PID of $3 for Libraries"
		/usr/bin/ldd /proc/$3/exe | /bin/grep -v linux-vdso.so | /bin/grep '=>' | /bin/cut -d\> -f2 | \
			/bin/awk '{ print $1 }' >>  ${UNIQUEBASE}/request.list
 		/usr/bin/ldd /proc/$3/exe | /bin/grep -v linux-vdso.so | /bin/grep -v find | /bin/grep -v '=>' | \
			/bin/awk '{ print $1 }' >> ${UNIQUEBASE}/request.list
	   else
		/bin/echo "Using ldd of $3 for Libraries"
		/usr/bin/ldd $3 | /bin/grep -v linux-vdso.so | /bin/grep '=>' | /bin/cut -d\> -f2 | \
			/bin/awk '{ print $1 }' >>  ${UNIQUEBASE}/request.list
 		/usr/bin/ldd $3 | /bin/grep -v linux-vdso.so | /bin/grep -v find | /bin/grep -v '=>' | \
			/bin/awk '{ print $1 }' >> ${UNIQUEBASE}/request.list
		THIRDARG="EXE"
	fi


# Find the Executable either from the corefile for Solaris 8
# or newer versions of Solaris otherwise use PID or Executable itself

	if /usr/bin/test $THIRDARG = "PID"
	   then
		/bin/echo "Using PID of $3 to find executable"

		EXEFILE=`/bin/ls -la /proc/$3/exe | /bin/cut -d\> -f2`
 	  else 
		/bin/echo "Using $3 as the executable"
		if /usr/bin/test \( `/bin/echo $3 | /bin/cut -c -1` = "/" \)
		   then
			EXEFILE=$3
		   else
			EXEFILE=${START}$3
		fi
	fi




if /usr/bin/test \! -x "$EXEFILE"
  then
	/bin/echo "Problem with determined executable:\"${EXEFILE}\" checking details\n\n"
	if /usr/bin/test \! -e "$EXEFILE"
	  then
		/bin/echo "Warning: executable file could not be found via normal processing"
		/bin/echo "will search PATH then file systems looking for it...\n"
		/bin/echo "If this is NOT the same system that generated the corefile Control-C now"
		/bin/sleep 5
		TARGET=`/usr/bin/file ${COREFILE}  | /bin/cut -d\' -f2`
		/bin/echo "\n\nSearching for executable with name of \"$TARGET\"\n"
		EXEFILE=`/usr/bin/which ${TARGET}`
		if /bin/echo ${EXEFILE} | /bin/grep "^no ${TARGET}" 2>&1 >/dev/null
		  then
			/bin/echo "${TARGET} was not found in PATH... searching file systems...\n"
			/bin/echo "This may take some time (possibly 30+ minutes)\n"
			bin/echo "Warning: Problem locating Executable file... check info/exe-search.txt\n" >> ${UNIQUEBASE}/error.log
			EXEFILE=`/bin/find / -type f -name ${TARGET} -print 2>/dev/null | /bin/tee ${UNIQUEBASE}/info/exe-search.txt`
			if /usr/bin/test \( "x${EXEFILE}x" = "xx" \)
			  then
				/bin/echo "Warning....FAILURE... could not locate ${TARGET}\n"
				/bin/echo "Aborting.....\n"
				exit 1;
			  else
				/bin/echo "Found following executable(s)\n"
				/bin/cat ${UNIQUEBASE}/info/exe-search.txt
				/bin/echo "\n\nGuessing and Using First one\n"
				EXEFILE=`echo ${EXEFILE} | xargs -n 1 | head -1`
			fi
		fi

	  else
		/bin/echo "File exists so using it....\n"
	fi
fi


/bin/echo
/bin/echo "Found executable file: $EXEFILE"
/bin/echo

bcore=`/bin/basename "$COREFILE"`
bexe=`/bin/basename "$EXEFILE"`

SAVEDIR=`/bin/pwd`
cd ${UNIQUEBASE}
/bin/ln -s $COREFILE $bcore
/bin/ln -s $EXEFILE $bexe
/bin/ln -s $bcore corefile
/bin/ln -s $bexe  executable

# Get the latest GDB from the path if they have one
GDB=/usr/bin/gdb
if /usr/bin/test \( -n "`/usr/bin/which gdb 2>/dev/null`" -a `/usr/bin/which gdb 2>/dev/null` \!= "$GDB" \)
    then
        if /usr/bin/test -x `/usr/bin/which gdb 2>/dev/null`
            then
				# found gdb elsewhere and it is executable
                GDB=`/usr/bin/which gdb`
			else
        		if /usr/bin/test -x `/usr/bin/which gdb 2>/dev/null`
        		    then
					    # Presume GDB at /usr/bin/gdb
						GDB=/usr/bin/gdb
					else
					    GDB=
        		    fi
            fi
	else
        if /usr/bin/test -x `/usr/bin/which gdb 2>/dev/null`
            then
			    # Presume GDB at /usr/bin/gdb
				GDB=/usr/bin/gdb
			else
			    GDB=
            fi
    fi
    
# Verify that we have a GDB
if /usr/bin/test \( -n "${GDB}" -a -x $GDB \)
    then
        # Use gdb to generate the complete list of libraries loaded into the corefile
        # RHEL now has gdb in /usr/bin/gdb
        /bin/echo "Using $GDB for complete list of Libraries"
        /bin/echo "info sharedlibrary" >cmdfile
        /bin/echo "quit" >>cmdfile
        $GDB -q -e $EXEFILE -c corefile -x cmdfile 2>&1 \
                | /bin/grep -v "^#" \
                | /bin/grep "\.so" \
                | /bin/sed 's/\.\.\.done//g' \
                | /bin/sed 's/\.\.\.//g' \
                | /bin/sed 's/Loaded symbols for //g' \
                | /bin/sed 's/Reading symbols from //g' \
                | /bin/sed 's/Symbol file not found for //g' \
                | /bin/sed 's/(no debugging symbols found)\.//g' \
                | /bin/sed 's/^\[*\]$//g' \
                | /bin/sed 's/^Core was generated by*$//g' \
                | /bin/sed 's/warning: .dynamic section for \"//g' \
                | /bin/sed 's/\" is not at the expected address//g' \
                | /bin/sed 's/: No such file or directory.//g' \
                | /bin/sed 's/ (wrong library or version mismatch?)//g' \
                | /bin/sed 's/Using host libthread_db library \"//g' \
                | /bin/sed 's/\.$//g' \
                | /bin/sed 's/\"$//g' \
                | /bin/sed 's/  / /g' \
                | /bin/sed 's/^0x[0-9A-Fa-f]* //g' \
                | /bin/sed 's/^0x[0-9A-Fa-f]* //g' \
                | /bin/sed 's/^Yes //g' \
                | /bin/sed 's/^No //g' \
                | /bin/sed 's/[\(\*\)]//g' \
                | /bin/sed 's/[ ]//g' \
                | /bin/sort -u \
                >> ${UNIQUEBASE}/request.list

		# 2019.01.29: Also try to get a full stack dump, in case this somehow does not load properly
        /bin/echo "Using $GDB for full stack dump of corefile"
        /bin/echo "thread apply all where full" >cmdfile
        /bin/echo "quit" >>cmdfile
        $GDB -q -e $EXEFILE -c corefile -x cmdfile 2>&1 >> ${UNIQUEBASE}/info/stackdump
    fi
        
# For gdb 7.0 or NO GDB, manually add libthread_db.so.1; gdb 7.6 gets it from parsed messages
if /bin/grep libthread_db.so.1 ${UNIQUEBASE}/request.list 2>&1 >/dev/null 
    then
        /bin/echo "POSIX thread debugging enabled"
    else
        if /bin/grep libpthread.so.0 ${UNIQUEBASE}/request.list 2>&1 >/dev/null
            then
                /bin/echo "Adding libthread_db.so.1 matching libpthread.so.0 to enable POSIX thread debugging"
                /bin/grep libpthread.so.0 request.list | sed 's/pthread.so.0/thread_db.so.1/g' >>${UNIQUEBASE}/request.list
            else
                /bin/echo "No libpthread.so.0 or libthread_db.so.1 in library list."
                /bin/echo "Adding system libpthread.so.0 and libthread_db.so.1 to enable POSIX thread debugging"
                /bin/ls -1 /lib/libpthread.so.0 /lib/libthread_db.so.1 >>${UNIQUEBASE}/request.list
                /bin/ls -1 /lib64/libpthread.so.0 /lib64/libthread_db.so.1 >>${UNIQUEBASE}/request.list
            fi
    fi
        
/bin/mv -f ${UNIQUEBASE}/request.list ${UNIQUEBASE}/request.tmp
/bin/sort -u ${UNIQUEBASE}/request.tmp >${UNIQUEBASE}/request.list
/bin/rm -f ${UNIQUEBASE}/request.tmp cmdfile

/bin/mkdir ${UNIQUEBASE}/libs ; cd ${UNIQUEBASE}/libs

# gather Application libraries and create dbxrc file
# Command syntax has changed -- solib-absolute-prefix not solib-absolute-path
# Also, because .gdbinit is processed after commandline files, change opencore to launch gdb with ONLY
# executable filename, and put the core-file command in .gdbinit after set solib-absolute-prefix
# so opencore can still be used to launch cores.
/bin/echo "set libthread-db-search-path ./libs/lib64:./libs/lib" >${UNIQUEBASE}/.gdbinit
/bin/echo "set solib-absolute-prefix ./libs" >>${UNIQUEBASE}/.gdbinit
/bin/echo "core-file corefile" >>${UNIQUEBASE}/.gdbinit

for LIB in `/bin/cut -c 2- ${UNIQUEBASE}/request.list`
  do
	( /bin/mkdir -p `/usr/bin/dirname $LIB` ; cd `/usr/bin/dirname $LIB` ; /bin/ln -s /$LIB `/bin/basename $LIB` )
  done

# Create opencore script to launch gdb in quiet mode
echo "gdb -q executable" > ${UNIQUEBASE}/opencore
chmod 755 ${UNIQUEBASE}/opencore


#################################################
####                                         ####
####  GATHER INFORMATION ABOUT THE COREFILE  ####
####                                         ####
#################################################

/bin/date >> ${UNIQUEBASE}/error.log

/bin/echo "attempting to get file info from corefile" >>  ${UNIQUEBASE}/error.log
/usr/bin/file $COREFILE > ${UNIQUEBASE}/info/file.txt 2>>${UNIQUEBASE}/error.log

#################################################
####                                         ####
####   GATHER INFORMATION ABOUT THE SYSTEM   ####
####                                         ####
#################################################

/bin/uname -a > ${UNIQUEBASE}/extras/uname.txt 2>${UNIQUEBASE}/extras/uname.errors

# Copy self to extras
	#prepend START if $0 does not begin with /
	if /usr/bin/test `echo $0 | /bin/cut -b1 2>/dev/null` \!= "/"
	    then
	        /bin/cp -p ${START}$0 ${UNIQUEBASE}/extras >/dev/null 2>&1
		else
	        /bin/cp -p $0 ${UNIQUEBASE}/extras >/dev/null 2>&1
		fi

############################################
####                                    ####
####   Create the tar file for upload   ####
####                                    ####
############################################

cd  ${UNIQUEBASE}

# Create the two tar files which hold everything
# using the 'h' option in order to follow symbolic links 

# Grab the actual physical corefile 
/bin/echo
/bin/echo "Packaging and Compressing Core File..."
tar zcvvhf $SAVEDIR/${CASENUMBER}_corefiles.tar.gz $bcore 

# Grab physical copies of all the executable & libraries and anything in or linked to from extras directory
/bin/echo
/bin/echo "Packaging and Compressing Executable, Libraries and Ancillary Files..."
tar cvvhf $SAVEDIR/${CASENUMBER}_libraries.tar $bexe libs extras .gdbinit opencore *.log info

# These two are symlinks and have to be saved as such, not as physical files
tar rvvf $SAVEDIR/${CASENUMBER}_libraries.tar corefile executable 

cd $SAVEDIR

#2019.01.23: Make sure we know where gzip is
GZIP=/bin/gzip
if /usr/bin/test \( -n "`/usr/bin/which gzip 2>/dev/null`" -a `/usr/bin/which gzip 2>/dev/null` \!= "$GZIP" \)
    then
        if /usr/bin/test -x `/usr/bin/which gzip 2>/dev/null`
            then
				# found gzip elsewhere and it is executable
                GZIP=`/usr/bin/which gzip 2>/dev/null`
			else
        		if /usr/bin/test -x `/usr/bin/which gzip 2>/dev/null`
        		    then
					    # Presume GZIP at /bin/gzip
						GZIP=/bin/gzip
					else
					    GZIP=
        		    fi
            fi
	else
        if /usr/bin/test -x `/usr/bin/which gzip 2>/dev/null`
            then
			    # Presume GZIP at /bin/gzip
				GZIP=/bin/gzip
			else
			    GZIP=
            fi
    fi

if /usr/bin/test \( -n "{$GZIP}" -a -x ${GZIP} \)
  then
    # Ignore compression errors
	${GZIP} -9 ${CASENUMBER}_libraries.tar >/dev/null 2>&1
  else
    # Fall back on compress and hope that it is there. Ignore errors
	/usr/bin/compress ${CASENUMBER}_libraries.tar >/dev/null 2>&1
fi

/bin/echo
/bin/echo Cleaning up
/bin/rm -rf ${UNIQUEBASE}/* ${UNIQUEBASE}/.gdbinit
/bin/rmdir  ${UNIQUEBASE}

/bin/echo
/bin/echo "Please Upload the following two files to the Case Files for your Actian Support Case:"
/bin/ls -l ${CASENUMBER}_* 2>/dev/null


