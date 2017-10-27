#!/bin/bash

# Simple script to check current version / branch of oref0 installed and check for updates

branch=$(cd $HOME/src/oref0/ && git rev-parse --abbrev-ref HEAD)
version=$(jq .version "$HOME/src/oref0/package.json" | sed 's/"//g')

if [[ $1 =~ "update" ]]; then
	cd $HOME/src/oref0/ && git fetch # pull latest remote info
	behind=$(cd $HOME/src/oref0/ && git rev-list --count ${branch}...origin/${branch})
    if (("$behind" > "0")); then
		# we are out of date
		echo "Your instance of oref0 [${version}, ${branch}] is out-of-date by ${behind} commits, you may want to consider updating."
        if [ $branch != "master" ]; then
			echo; echo "You are currently running a development branch of oref0.  Such branches change frequently."
			echo "Please read the latest PR notes and update with the latest commits to dev before reporting any issues."; echo
		else
			echo "Please make sure to read any new documentation that may accompany update, as some things may have changed."
		fi
	else
		echo "Your instance of oref0 [${version}, ${branch}] is up-to-date."
	fi
else
	# simple version check and report.
	echo "${version} [${branch}]"
fi