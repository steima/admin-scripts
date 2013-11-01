#!/bin/bash                                                                                                                                                  

die() { 
        echo >&2 "$@"
        exit 1
}

[ "$#" -ge 3 ] || die "usage: ${0} <database-name> <user-name> <client-host> [-c [dbpassword]]"

databaseName="${1}"
userName="${2}"
clientHost="${3}"
databaseHost=$(hostname --fqdn)

if [ "${5}" = "" ] ; then
        echo -n "Please enter the root password for the local MySQL server: "
        read -s pass
        echo "" 
else
        pass="${5}"
fi

dbUserPassword=$(pwgen -1 -n 8)

sqlCreate="create database ${databaseName} character set utf8 collate utf8_general_ci;"
sqlGrant="grant all on ${databaseName}.* to '${userName}'@'${clientHost}' identified by '${dbUserPassword}';"

echo "$sqlCreate" | mysql -u root -p${pass} mysql
echo "$sqlGrant" | mysql -u root -p${pass} mysql

if [ "${4}" = "-c" ] ; then
        echo "mysql://${userName}:${dbUserPassword}@${databaseHost}:3306/${databaseName}"     
else
        echo "Database created"
        echo "You can now connect to ${databaseName} @ ${databaseHost}${databaseHost}  from ${clientHost} using:"
        echo "Username: ${userName}"
        echo "Password: ${dbUserPassword}"
fi

pass=""
