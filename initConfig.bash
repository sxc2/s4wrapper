#!/bin/bash
# s4cmd Wrapper Initializer Script
# https://github.com/sxc2/s4wrapper/
#
# to start:
# bash initConfig.bash
# 
# to start over:
# delete s4.config


# initialization variables
S3_ACCESS_KEY = "";
S3_SECRET_KEY = "";
CONFIGFILE="s4.config";

S3_BUCKET="";
S3_ACCESS_KEY="";
S3_SECRET_KEY="";

LOCAL_SYNC_DIR="newFiles";

# Colors
ESC_SEQ="\x1b["
COL_RESET=$ESC_SEQ"39;49;00m"
COL_RED=$ESC_SEQ"31;01m"
COL_GREEN=$ESC_SEQ"32;01m"
COL_YELLOW=$ESC_SEQ"33;01m"
COL_GRAY=$ESC_SEQ"30;01m"
COL_WHITE=$ESC_SEQ"37;01m"
COL_BLUE=$ESC_SEQ"34;01m"
COL_MAGENTA=$ESC_SEQ"35;01m"
COL_CYAN=$ESC_SEQ"36;01m"

# temporary variable
tempsize=0;

# first time initialization function
#   prompts users for S3 information to persist it to s4.config
#   
firstTimeInit() {
	echo  -e "${COL_WHITE}First Time Initialize${COL_RESET}";
	echo  -e "${COL_GRAY}_____________________________________________${COL_RESET}";
	sudo pip install s4cmd


	read -p "Enter your S3 bucket name, e.g. s3://<bucket-name> :" S3_BUCKET
	read -p "Enter your local sync dir, e.g. newFiles :" LOCAL_SYNC_DIR

	read -p "Enter your access key for S3:" S3_ACCESS_KEY
	read -p "Enter your secret key for S3:" S3_SECRET_KEY

	echo -e "  ${COL_YELLOW}You chose $S3_BUCKET with access key $S3_ACCESS_KEY and secret key $S3_SECRET_KEY ${COL_RESET}"
	echo -e "  ${COL_YELLOW}You chose remote S3 bucket $S3_BUCKET and local sync dir $LOCAL_SYNC_DIR ${COL_RESET}"
	select yn in "Yes" "No"; do
	    case $yn in
	        Yes ) 	

				echo "$S3_BUCKET" > "$CONFIGFILE"
				echo "$S3_ACCESS_KEY" >> "$CONFIGFILE"
				echo "$S3_SECRET_KEY" >> "$CONFIGFILE"
				echo "$LOCAL_SYNC_DIR" >> "$CONFIGFILE"
				echo " " >> "$CONFIGFILE"

				mkdir LOCAL_SYNC_DIR;

				alwaysInit; break;;
	        No ) exit;;
	    esac
	done
}

# starts reoccuring work items after initial init
alwaysInit() {
	CheckEnvironmentVariables;
}

# helper function to parse output for size
#   takes a first parameter for the string lines to check
#   sets a global variable to the size calculated
parseLineForSize() {
	while read -r line; do
		read -r tempNum _ <<< "$line"

		if [ "$tempNum" ]; then	
			if (( tempNum )); then
				tempsize=$(( $tempsize + $tempNum ));
				#echo "$tempNum $tempsize"   # Output the line itself.

			fi
		fi
	done <<< "$1"
}

# loops through the designated bucket to sync if there are new files
#   instead of doing a sync, it will try to do a delta sync if there bit size changes
#   sleeps for 30 seconds between syncs
LoopSyncForBucket()
{
	echo -e "${COL_WHITE}Starting Script to Sync Files${COL_RESET}";
	echo -e "${COL_GRAY}_____________________________________________${COL_RESET}";
	echo -e "  ${COL_WHITE}Syncing Bucket for ${S3_BUCKET} ${COL_RESET}";
	echo -e "  ${COL_YELLOW}Press [CTRL+C] to stop at anytime  ${COL_RESET}"
	
	initSync=$(s4cmd.py sync $S3_BUCKET $LOCAL_SYNC_DIR -r -s);
	echo -e "  ${COL_WHITE}Finished initial sync with $S3_BUCKET ${COL_RESET}";

	initSize=$(s4cmd.py du s3://clarity-cebu/ -r);
	parseLineForSize "$initSize";

	local beginSize=$(( $tempsize ));
	echo -e "  ${COL_WHITE}Finished initial bucket size for delta sync:$tempsize ${COL_RESET}";

	while :
	do
		echo -e "  ${COL_WHITE}Sleeping for 30 seconds... ${COL_RESET}";
		sleep 30
		tempsize=0;

		initSize=$(s4cmd.py du s3://clarity-cebu/ -r);
		parseLineForSize "$initSize";

		if (( tempsize )); then
			if [ "$tempsize" != "$beginSize" ]; then
				echo -e "  ${COL_YELLOW}New bits found, starting delta sync: $tempsize $beginSize ${COL_RESET}";
				initSync=$(s4cmd.py sync $S3_BUCKET $LOCAL_SYNC_DIR -r -s);

				tempDelta=$(( $tempsize - $beginSize ));
				echo -e "  ${COL_GREEN}Updated bits: $tempDelta ${COL_RESET}";
				beginSize=$(( $tempsize ));
			fi
		fi

		echo -e "  ${COL_WHITE}Total bucket size checked for delta sync:$tempsize ${COL_RESET}";
	
	done
}

# checks enviroment variables and persisted configuration files for values
CheckEnvironmentVariables() 
{
	echo  -e  "${COL_WHITE}Checking Environment Variables${COL_RESET}";
	echo  -e  "${COL_GRAY}_____________________________________________${COL_RESET}";

	
	count=0
	while read LINE
	do
		#echo "$count $LINE";
		#		$trimmedLine=$LINE | sed -e 's/^ *//' -e 's/ *$//';
		if [ "$LINE" ]; then
			case "$count" in
	 			0)  S3_BUCKET="$LINE" ;;
	    		1)  S3_ACCESS_KEY="$LINE" ;;
	    		2)  S3_SECRET_KEY="$LINE" ;;
	    		4)  LOCAL_SYNC_DIR="$LINE" ;;
			esac
		fi
		
		let count++
		
	done < <( cat $CONFIGFILE )

	echo -e "  ${COL_YELLOW}Found access key $S3_ACCESS_KEY and secret key **************** ${COL_RESET}"
	echo -e "  ${COL_YELLOW}Found remote S3 bucket $S3_BUCKET and local sync dir $LOCAL_SYNC_DIR ${COL_RESET}"

	export S3_ACCESS_KEY; 
	export S3_SECRET_KEY; 

	if [ ! "$S3_ACCESS_KEY" ]; then
		echo -e  "  ${COL_RED}Access Key for S3 does not exist${COL_RESET}";
	elif [ ! "$S3_SECRET_KEY" ]; then
		echo -e  "  ${COL_RED}Secret Key for S3 does not exist${COL_RESET}";
	elif [ ! "$S3_BUCKET" ]; then
		echo -e  "  ${COL_RED}S3 bucket not specified ${COL_RESET}";
	elif [ ! "$LOCAL_SYNC_DIR" ]; then
		echo -e  "  ${COL_RED}Local directory to sync for S3 does not exist${COL_RESET}";
	else
		echo -e "  ${COL_GREEN}Found Access Key for S3: $S3_ACCESS_KEY ${COL_RESET}";
		echo -e "  ${COL_GREEN}Found Secret Key for S3: *********** ${COL_RESET}";
		echo -e "  ${COL_GREEN}Found S3 Bucket: $S3_BUCKET ${COL_RESET}";
		echo -e "  ${COL_GREEN}Found local sync dir: $LOCAL_SYNC_DIR S3${COL_RESET}";
		LoopSyncForBucket;
	fi

	return
}

# actual start of script
clear screen;

if [ -f "s4.config" ]; then
	alwaysInit;
else
	firstTimeInit;
fi


