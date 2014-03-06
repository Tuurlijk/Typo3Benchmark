#!/bin/bash
#
# Excercise TYPO3 v 0.0.1
# Call ExcerciseTypo3.rb for each git revision
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

TYPO3 excercise script.

OPTIONS:
   -s   Full path to TYPO3 site root directory containing a typo3_src folder.
   -u   The base url of the website to excercise.
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


	# Cache tables to flush after preparation
flushCacheTables=(
	cache_extensions
	cache_hash
	cache_imagesizes
	cache_md5params
	cache_pages
	cache_pagesection
	cache_treelist
	cache_typo3temp_log
	cachingframework_cache_hash
	cachingframework_cache_hash_tags
	cachingframework_cache_pages
	cachingframework_cache_pages_tags
	cachingframework_cache_pagesection
	cachingframework_cache_pagesection_tags
	cf_cache_hash
	cf_cache_hash_tags
	cf_cache_pages
	cf_cache_pages_tags
	cf_cache_pagesection
	cf_cache_pagesection_tags
	cf_workspaces_cache
	cf_workspaces_cache_tags
	sys_workspace_cache
	sys_workspace_cache_tags
	tx_devlog
	tx_dreknowledgebase_relations_cached
	tx_extbase_cache_object
	tx_extbase_cache_object_tags
	tx_extbase_cache_reflection
	tx_extbase_cache_reflection_tags
	tx_ncstaticfilecache_file
	tx_realurl_chashcache
	tx_realurl_pathcache
	tx_realurl_urldecodecache
	tx_realurl_urlencodecache
	tx_wecmap_cache
)


	# Clear caches
function clearCaches () {
	echo 2>&1 | tee -a $logFile
	echo "Clearing typo3conf/temp_*" 2>&1 | tee -a $logFile
	rm ${siteRoot}/typo3conf/temp_*
	echo "Clearing typotemp/Cache" 2>&1 | tee -a $logFile
	rm -rf ${siteRoot}/typo3temp/Cache
}


	# Ensure the _cli_tuesanitizer user exists
function createCliUsers () {
	echo 2>&1 | tee -a $logFile
	echo "Creating _cli_tuesanitizer backend user" 2>&1 | tee -a $logFile
	mysql -h $databaseHost -u $databaseUser -p$databasePassword -D $database -e " \
			REPLACE INTO be_users \
			SET \
				username = '_cli_tuesanitizer', \
				password = 'b49f7cfd50d0f8b4b53598752e2ea103',
				usergroup = 77;"
				# Usergroup 77: role_eindredacteur is needed for t3d export
	echo "Creating _cli_lowlevel backend user" 2>&1 | tee -a $logFile
	mysql -h $databaseHost -u $databaseUser -p$databasePassword -D $database -e " \
			REPLACE INTO be_users \
			SET \
				username = '_cli_lowlevel', \
				password = 'b49f7cfd50d0fkjhwekhrkj4hk345hb53598752e2ea103';"
}


  # Flush cache tables
function flushCacheTables () {
	local len=${#flushCacheTables[*]}
	local i=0
	echo 2>&1 | tee -a $logFile
	echo "Flushing $len cache tables:" 2>&1 | tee -a $logFile
	while [ $i -lt $len ]; do
		echo "truncate table ${database}.${flushCacheTables[$i]}" 2>&1 | tee -a $logFile
		mysql -h $databaseHost -u $databaseUser -p$databasePassword -e "truncate table ${database}.${flushCacheTables[$i]}" > /dev/null 2>&1
		let i++
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


	# Run
function excercise() {
	local i=0
	local len=10
	while [ $i -lt $len ]; do
		currentRevision=`git rev-parse HEAD`
		echo "Excercising revision ${currentRevision} . . ." 2>&1
		clearCaches
		flushCacheTables
		(ruby ${benchMarkDirectory}/ExcerciseTypo3.rb -v v -- ${currentRevision} ${url} ${adminPassword}) &
		spinner $!
		git reset --hard HEAD~1
		let i++
	done
}


pushd $sourceDirectory
if [ -z "$revision" ]; then
	echo "Fetching head . . ."
	git pull
else
	echo "Checking out revision: ${revision} . . ."
	git checkout ${revision}
fi
createCliUsers
excercise
popd