#!/bin/bash
# This is the setup and update tool for machines that are using the admin scripts
# One needs to specifiy the role of the current machine to get designated role scripts added to the setup

configurationDir="/etc/admin-scripts/"

echo -n "Checking if this is a new setup ..."

if [ -d "${configurationDir}" ] ; then
	echo "Upgrade"
	echo "Upgrading existing installation"
else
	echo "New"
fi
