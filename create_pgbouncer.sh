#!/bin/bash

# Here you need to specify these parameters
readonly AZURE_ACCT="rifujita" 
readonly ACI_RES_LOC="japaneast"
readonly ACI_RES_GRP="${AZURE_ACCT}-pgb-aci"
readonly ACI_CNT_NAME="${ACI_RES_GRP}-cnt"

# coordinator node of Hyperscale (Citus)
readonly PGSQL_HOST="citus-c.postgres.database.azure.com"
readonly PGSQL_PASSWORD="your_pass_here"

# Checking if Resource Group exists
echo "Checking Resource Group..."
res=$(az group show -g $ACI_RES_GRP -o tsv --query "properties.provisioningState" 2>&1)
if [ "$res" == "Succeeded" ]; then
	echo "The Resource Group, ${ACI_RES_GRP} has already existed."
	exit
fi

# Create Resource Group
echo "Creating Resource Group..."
res=$(az group create -l $ACI_RES_LOC -g $ACI_RES_GRP -o tsv --query "properties.provisioningState")
if [ "$res" != "Succeeded" ]; then
	exit
fi

# Create the container
echo "Creating Container..."
res=$(az container create --image rioriost/pgbouncer \
    -g $ACI_RES_GRP \
    -n $ACI_CNT_NAME \
    --cpu 2 --memory 8 \
    --dns-name-label $ACI_CNT_NAME \
    --ip-address Public --ports 5432 \
    -e DB_USER=citus \
        DB_PASSWORD=$PGSQL_PASSWORD \
        DB_HOST=$PGSQL_HOST \
        DB_NAME=citus \
        POOL_MODE=transaction \
        AUTH_TYPE=trust \
        SERVER_RESET_QUERY="DISCARD ALL" \
        MAX_CLIENT_CONN=10000 \
        SERVER_TLS_SSLMODE=require \
        SERVER_TLS_CA_FILE=/etc/pgbouncer/root.crt \
    -o tsv --query "provisioningState")

if [ "$res" != "Succeeded" ]; then
	az group delete --yes --no-wait -g $ACI_RES_GRP
	exit
fi

echo "Try following command:"
echo "psql \"host=${ACI_CNT_NAME}.${ACI_RES_LOC}.azurecontainer.io port=5432 dbname=citus user=citus password=${PGSQL_PASSWORD}\""