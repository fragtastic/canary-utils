#!/bin/bash

#.SYNOPSIS
#    Adaption of Invoke-CreateCanarytokensFactoryLocal.ps1 to bash.
#    Creates Canarytokens and drops them to local host.
#    Uses Canarytoken Factory, so it can be safely used for mass deployment.
#
#.NOTES
#    For this tool to work, you must have your Canary Console API enabled, please 
#    follow this link to learn how to do so:
#    https://help.canary.tools/hc/en-gb/articles/360012727537-How-does-the-API-work-
#
#    Also, you must have a Canarytoken Factory Auth, and the Flock *ID* you want to deploy to beforehand.
#    if you don't know how, please reach out to support@canary.tools.
#
#    ###################
#    How does this work?
#    ###################
#    Requires curl and sed to be in the path
#    1. Create the flock you want the tokens to be part of in your Console.
#    2. Get the Flock ID (https://docs.canary.tools/flocks/queries.html#list-flocks-summary)
#    3. Create a Canarytoken Factory (https://docs.canary.tools/canarytokens/factory.html#create-canarytoken-factory-auth-string)
#    4. Make sure the host has access to the internet.
#    5. Run script as a user that has read/write access on the target directory.
#
#.EXAMPLE
#    sh .\CreateCanaryToken.sh
#    This will run the tool with the default flock, asking interactively for missing params.
#    Flags 
#    -d Domain e.g aabbccdd.canary.tools
#    -a FactoryAuth ""
#    -f Flock ID e.g "flock:xxyyzz" Note: not setting the flock id will use "flock:default"
#    -o Output Directory e.g "~/secret"
#    -t Token Type e.g aws-id
#    -n Token Filename e.g aws_secret.txt Note: Use an appropriate extension for your token type.
#
#    sh .\CreateCanaryToken.sh -d aabbccdd.canary.tools -a XXYYZZ -f flock:xxyyzz -o "~/secret" -t aws-id -n aws_secret.txt -m '{"json": "format memo"}'
#    creates an AWS-ID Canarytoken, using aws_secret.txt as the filename, and places it under ~/secret

#
#Constants
DOMAIN=""
FACTORYAUTH=""
FLOCKID=""
TARGETDIRECTORY=""
TOKENTYPE=""
TOKENFILENAME=""
TOKENMEMO=""

REGEX_DOMAIN="^([a-zA-Z0-9]{8,8}).canary.tools$"
REGEX_FACTORYAUTH="^[a-zA-Z0-9]{32,32}$"
REGEX_FLOCKID="^flock:([a-f0-9]{32,32}|default)$"
REGEX_TOKENTYPE="^(aws-id|doc-msword|doc-msexcel|slack-api|windows-dir)$"
REGEX_MEMO='^[[:space:]]*{[[:space:]]*(\"[a-zA-Z0-9\-\_\.[:space:]]+\"[[:space:]]*:[[:space:]]*\"[a-zA-Z0-9\-\_\.[:space:]]+\")([[:space:]]*,[[:space:]]*\"[a-zA-Z0-9\-\_\.[:space:]]+\"[[:space:]]*:[[:space:]]*\"[a-zA-Z0-9\-\_\.[:space:]]+\")*[[:space:]]*}[[:space:]]*$'


#Set script flags
while getopts d:a:f:o:t:n:m: flag
do
    case "${flag}" in
        d) DOMAIN=${OPTARG};;
        a) FACTORYAUTH=${OPTARG};;
        f) FLOCKID=${OPTARG};;
        o) TARGETDIRECTORY=${OPTARG};;
        t) TOKENTYPE=${OPTARG};;
        n) TOKENFILENAME=${OPTARG};;
        m) TOKENMEMO=${OPTARG};;
    esac
done

if [ -z "$FLOCKID" ]; then
    /usr/bin/printf 'Flock ID not specified. Setting it to "flock:default"'
    FLOCKID="flock:default"
fi

# Mark readonly only after collecting values
readonly DOMAIN
readonly FACTORYAUTH
readonly FLOCKID
readonly TARGETDIRECTORY
readonly TOKENTYPE
readonly TOKENFILENAME
readonly TOKENMEMO

#Collect unset variables from user.
if [ -z "$TOKENTYPE" ]; then
    /usr/bin/printf "No token type set.\nPlease set in one of the below token types\n> $REGEX_TOKENTYPE\n"
    exit 1
fi

#Don't continue unless $TOKENTYPE is supported
if [[ ! "$TOKENTYPE" =~ $REGEX_TOKENTYPE ]]; then
    /usr/bin/printf "[X] Token type '$TOKENTYPE' cannot be downloaded.\n"
    /usr/bin/printf "Please set in one of the below token types\n> $REGEX_TOKENTYPE\n"
    exit 1
fi

if [[ ! "$FLOCKID" =~ $REGEX_FLOCKID ]]; then
    /usr/bin/printf "[X] Flock ID '$FLOCKID' is not valid.\n"
    exit 1
fi

if [ -z "$DOMAIN" ] || [[ ! "$DOMAIN" =~ $REGEX_DOMAIN ]]; then
    /usr/bin/printf 'Full Canary domain (e.g. 'xyz.canary.tools') not set.\n'
    exit 1
fi

if [ -z "$FACTORYAUTH" ] || [[ ! "$FACTORYAUTH" =~ $REGEX_FACTORYAUTH ]]; then
    /usr/bin/printf 'Canarytoken Factory Auth String not set or valid.\n'
    exit 1
fi

if [ -z "$TARGETDIRECTORY" ]; then
    /usr/bin/printf 'No target directory set.\n'
    exit 1
fi

if [ -z "$TOKENFILENAME" ]; then
    /usr/bin/printf 'No file name set.\n'
    exit 1
fi

if [ -z "$TOKENMEMO" ]; then
    /usr/bin/printf 'No memo set.\n'
    exit 1
fi

if [[ ! "$TOKENMEMO" =~ $REGEX_MEMO ]]; then
    /usr/bin/printf 'Memo invalid.\n'
    /usr/bin/printf 'Memo: \"%s\".\n' "$TOKENMEMO"
    exit 1
fi

#Print current variables
/usr/bin/printf "[*] Starting Script with the following params:\n"
/usr/bin/printf "Console Domain = $DOMAIN\n"
/usr/bin/printf "Flock ID = $FLOCKID\n"
/usr/bin/printf "Target Directory = $TARGETDIRECTORY\n"
/usr/bin/printf "Token Type = $TOKENTYPE\n"
/usr/bin/printf "Token Filename = $TOKENFILENAME\n"
/usr/bin/printf "Token Memo = $TOKENMEMO\n"


# /usr/bin/printf "ending testing"; exit 0

#Checking target directory existance
/usr/bin/printf "[*] Checking if '$TARGETDIRECTORY' exists...\n"

if [ -d "$TARGETDIRECTORY" ]; then
    /usr/bin/printf "Directory exists\n"
else
    /bin/mkdir -p "$TARGETDIRECTORY"
    /usr/bin/printf "$TARGETDIRECTORY was not found. directory has been created.\n"
    /bin/chmod 755 "$TARGETDIRECTORY"
fi

#Check whether token already exists
OUTPUTFILENAME="$TARGETDIRECTORY/$TOKENFILENAME"

/usr/bin/printf "[*] Dropping '$OUTPUTFILENAME'...\n"

if [ -f "$OUTPUTFILENAME" ]; then
    /usr/bin/printf "File already exists.\n"
fi

#Create token
TOKENNAME=$OUTPUTFILENAME

/usr/bin/printf "[*] Signing to the API for a token...\n"

GETTOKEN=$(/usr/bin/curl -s -X POST "https://${DOMAIN}/api/v1/canarytoken/factory/create" -d factory_auth="$FACTORYAUTH" -d memo="$TOKENMEMO" -d flock_id="$FLOCKID" -d kind="$TOKENTYPE" --tlsv1.2 --tls-max 1.2)
TOKENID=$(echo "$GETTOKEN" | /usr/bin/awk '/"canarytoken": "/ {print $NF}' | tr -d '",')

if echo "$GETTOKEN" | grep -q '"result": "success"'; then
    /usr/bin/printf "[*] Token Created (ID: $TOKENID).\n"
else
    /usr/bin/printf "[X] Creation of $TOKENNAME failed.\n"
    exit 1
fi

#Download Token
/usr/bin/printf "[*] Downloading Token from Console...\n"

/usr/bin/curl -s -G -L --tlsv1.2 --tls-max 1.2 --output "$OUTPUTFILENAME" -J "https://$DOMAIN/api/v1/canarytoken/factory/download" -d factory_auth="$FACTORYAUTH" -d canarytoken="$TOKENID"

/bin/chmod 755 "$OUTPUTFILENAME"

/usr/bin/printf "[*] Token Successfully written to destination: '$OUTPUTFILENAME'.\n"
