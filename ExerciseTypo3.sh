#!/bin/bash
#
# Exercise TYPO3 v 0.0.1
# Call ExerciseTypo3.rb for each git revision
#
# Copyright ⓒ 2014, Michiel Roos <michiel@maxserv.nl>
#
# Distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
# without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
# PARTICULAR PURPOSE. See the GNU General Public License for more details:
# http://www.gnu.org/licenses/gpl.txt


	# Basic setup
now=`date "+%Y-%m-%d_%H-%M"`
benchMarkDirectory=`pwd`
adminUser=admin
adminPassword=supersecret
getDatabaseCredentialsFromLocalconf=true
revision=
logDir="/tmp/"
logFile="${logDir}Typo3Benchmark_run_${now}.log"


  # Usage message
function usage () {
	cat << EOF
usage: `basename $0` options

TYPO3 exercise script.

OPTIONS:
   -s   Full path to TYPO3 site root directory containing a typo3_src folder.
   -u   The base url of the website to exercise.
   -l   The TYPO3 backend username. If omitted; 'admin' is used.
   -p   The TYPO3 backend password. If omitted; 'supersecret' is used.
   -r   The git revision to start from. If omitted; the latest revision is used.
EOF
}


  # Get options
while getopts ':s:u:l:p:r:' flag
do
	case $flag in
		s)
			siteRoot="$OPTARG"
			;;
		u)
			url="$OPTARG"
			;;
		l)
			adminUser="$OPTARG"
			;;
		p)
			adminPassword="$OPTARG"
			;;
		r)
			revision="$OPTARG"
			;;
		\?)
			echo "Invalid option: -$OPTARG" >&2
			usage;
			exit 1
			;;
		:)
			echo "Option -$OPTARG requires an argument." >&2
			usage;
			exit 1
			;;
	esac
done


if [ -z "$url" ] || [ -z "$siteRoot" ]
then
	usage
	exit 1
fi


sourceDirectory="${siteRoot}/typo3_src"
if [ ! -d $siteRoot ] || [ ! -d $sourceDirectory ]
then
	cat << EOF
Failed to find typo3_src directory:
siteRoot:   $siteRoot
sourceDir:  $sourceDirectory
EOF
	usage
	exit 1
fi
cliScript="${siteRoot}/typo3/cli_dispatch.phpsh"
localconf="${siteRoot}/typo3conf/localconf.php"


	# Find database credentials
database=`grep "typo_db " $localconf | tr -d "\$\'\;"`
database=${database#typo_db = }
databaseHost=`grep "typo_db_host " $localconf | tr -d "\$\'\;"`
databaseHost=${databaseHost#typo_db_host = }
databaseUser=`grep "typo_db_username " $localconf | tr -d "\$\'\;"`
databaseUser=${databaseUser#typo_db_username = }
databasePassword=`grep "typo_db_password " $localconf | tr -d "\$\'\;"`
databasePassword=${databasePassword#typo_db_password = }
if [[ -z $database ]] || [[ -z $databaseHost ]] || [[ -z $databaseUser ]] || [[ -z $databasePassword ]]
then
	cat << EOF
Failed to find all needed database credentials:
database: $database
    host: $databaseHost
    user: $databaseUser
password: $databasePassword
EOF
	exit 1
else
	cat << EOF
Working on the following database:
database: $database
    host: $databaseHost
    user: $databaseUser
EOF
fi


	# Clear caches
function clearCaches () {
	echo "Clearing typo3conf/temp_*" | tee -a $logFile
	rm ${siteRoot}/typo3conf/temp_*
	echo "Clearing typotemp/*" | tee -a $logFile
	rm -rf ${siteRoot}/typo3temp/*
}


	# Ensure the _cli_lowlevel user exists. Can be used to auto-update database using the tableupdater extension.
function createCliUsers () {
	echo "Creating _cli_lowlevel backend user" | tee -a $logFile
	mysql -h $databaseHost -u $databaseUser -p$databasePassword -D $database -e " \
			REPLACE INTO be_users \
			SET \
				username = '_cli_lowlevel', \
				password = 'b49f7cfd50d0fkjhwekhrkj4hk345hb53598752e2ea103';"
}


  # Flush cache tables
function flushCacheTables () {
	echo "Flushing cache tables" | tee -a $logFile
	mysql -h $databaseHost -u $databaseUser -p$databasePassword -D $database --skip-column-names -e " \
			SELECT DISTINCT TABLE_NAME \
			FROM INFORMATION_SCHEMA.COLUMNS \
			WHERE ( \
				TABLE_NAME LIKE '%cache%' \
				OR TABLE_NAME LIKE 'cf_%' \
			) \
			AND TABLE_SCHEMA = '${database}';" | while read tableName; do
		# echo "truncate table ${database}.${tableName}"
		mysql -h $databaseHost -u $databaseUser -p$databasePassword -e "truncate table ${database}.${tableName}" > /dev/null 2>&1
	done
}


	# Display a spinner for long running operations
function spinner() {
	local pid=$1
	local delay=0.25
	local spinnerCharacter
	while [ $(ps -eo pid | grep $pid) ]
	do
		for spinnerCharacter in \| / - \\
		do
			printf ' [%c]\b\b\b\b' $spinnerCharacter
			sleep $delay
		done
	done
	printf '\b\b\b\b'
	echo
}


	# Exercise!
function exercise() {
	local initialRevision=false
	local revisionMessage
	local status
	while [ $initialRevision == false ]; do
		pushd $sourceDirectory > /dev/null 2>&1
		currentRevision=`git rev-parse HEAD`
		popd > /dev/null 2>&1
		echo | tee -a $logFile
		echo "Exercising revision ${currentRevision}" | tee -a $logFile
		echo $revisionMessage | tee -a $logFile
		git show -s --format=%ci | tee -a $logFile
		clearCaches
		flushCacheTables
		echo "Running benchmark tests" | tee -a $logFile
		ruby ExerciseTypo3.rb -v v -- ${currentRevision} ${url} ${adminPassword}
		status=$?
		if [ $status -ne 0 ]; then
			cat << EOF
Failure detected when benchmarking. Please fix the scripts to prevent TYPO3
breakage for this revision so we can properly benchmark it.

revision: ${currentRevision}
 logfile: ${logFile}

Come back soon!
EOF
			exit
		fi
		pushd $sourceDirectory > /dev/null 2>&1
		revisionMessage=$(git reset --hard HEAD~1)
		if echo $revisionMessage | grep -i "Initial revision"; then
			initialRevision=true
		fi
		popd > /dev/null 2>&1
	done
}


pushd $sourceDirectory > /dev/null 2>&1
if [ -z "$revision" ]; then
	echo "Fetching head" | tee -a $logFile
	git pull 2>&1 | tee -a $logFile
else
	echo "Checking out revision: ${revision}" | tee -a $logFile
	git checkout ${revision} 2>&1 | tee -a $logFile
fi
popd > /dev/null 2>&1
createCliUsers
exercise
