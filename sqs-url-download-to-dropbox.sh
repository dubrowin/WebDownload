function handler () {

    ## SQS Sample Message: { "Destination" : "Podcast", "URL": "https://isc.sans.edu/podcast/podcast6814.mp3" }

    ################################
    ## variables
    ################################
    EVENT_DATA=$1
    SQSLIB="s3://dubrowin-sync/bin"
    PATH="$PATH:/tmp"
    AUTHTMP="/tmp/$( basename "$0" ).authtmp"
    LIBBUCKET="s3://dubrowin-layers/"
    LIB="DropboxAPI.sh"
    DEBUG="Y"
    COUNT=""
    CORE=""
    EXT=""
    QUEUE_URL="https://sqs.us-east-2.amazonaws.com/524365920037/PushBullet"	
    FILEOUT=""
    WGETOPT=""


    ################################
    ## Functions
    ################################

    function logit () {
        
        echo -e "$1" >&2

    }
    
    function Err {
        echo "$1" >&2
        RESPONSE="{\"statusCode\": 500, \"body\": \"ERROR: $1 ($EVENT_DATA)\"}"
        exit
    }
    

    function GetAuth {
        # Check if the AUTHTMP file is already there with values
        AUTH=`grep Value $AUTHTMP | cut -d \" -f 4 || true`
        if [ "$AUTH" == "" ]; then

        
            logit "executing authorization request"
            aws ssm get-parameters --names "Dropbox" --region us-east-2 > $AUTHTMP # 1> /dev/null >&1
            AUTH=`grep Value $AUTHTMP | cut -d \" -f 4 || true`
            ##FOO=`cat $AUTHTMP`
            ##logit "AUTH: $AUTH FOO: $FOO"
            

        fi
        
        ## Get DropboxAPI.sh
        logit "Fetching ${LIBBUCKET}${LIB}"
        aws s3 cp ${LIBBUCKET}${LIB} /tmp/ 1> /dev/null >&1
        ## Sourcing the DropboxAPI.sh only after getting the AUTH Key
        logit "running source"
        source /tmp/${LIB}
        logit "finished running source"
            
    }
    
    function CheckFile {
        logit "Starting CheckFile DBFILE $DBFILE"
        CORE=`echo $DBFILE | rev | cut -d . -f 2 | rev`
        EXT=`echo $DBFILE | rev | cut -d . -f 1 | rev`
        logit "Checking CORE and COUNT: ${CORE}${COUNT}.${EXT} against DBFILES: \n $DBFILES"
        logit "CORE $CORE"
        logit "COUNT $COUNT"
        logit "EXT $EXT"
        CFSTAT=`echo $DBFILES | grep -c ${CORE}${COUNT}.${EXT} || true`
        if [ "$CFSTAT" != "0" ]; then
            logit "${CORE}${COUNT}.${EXT} exists"
            let "COUNT = $COUNT + 1"
            CheckFile
        else
            if [ "$COUNT" != "" ]; then
                COUNT="-${COUNT}"
            fi
            logit "Setting DBFILE to ${CORE}${COUNT}.${EXT}"
            DBFILE="${CORE}${COUNT}.${EXT}"
            if [ "$OUTFILE" != "$DBFILE" ]; then
                mv /tmp/${DEST}/$OUTFILE /tmp/${DEST}/$DBFILE
            fi
        fi
    }
    ################################    
    ## Main Code
    ################################
    
    ## Parse Event Data
    ################################
    DEST=`echo $EVENT_DATA | grep '"body"' | tr '"' '\n' | sed 's/.$//' | grep Destination -A 2 | tail -1`
    URL=`echo $EVENT_DATA | grep '"body"' | tr '"' '\n' | sed 's/.$//' | grep URL -A 2 | head -n 3 | tail -1`
    # FILEOUT to allow for destination named file in the SQS command
    FILEOUT=`echo $EVENT_DATA | grep '"body"' | tr '"' '\n' | sed 's/.$//' | grep OUTFILE -A 2 | tail -1 || true`
    
    logit "DEST $DEST URL $URL FILEOUT $FILEOUT"
    
    case $DEST in
        Podcast )
            DIR="/Podcast"
        ;;
        * )
            Err "unrecognized DEST $DEST"
        ;;
    esac
    
    #logit "DEST $DEST URL $URL"

    logit "Creating Directory /tmp/${DEST}"
    mkdir -p /tmp/${DEST}
    
    cd /tmp/${DEST}
    
    logit "Getting URL $URL"

    if [ "$FILEOUT" != "" ]; then
        WGETOPT="-O $FILEOUT"
    fi
    
    wget -qc "${URL}" $WGETOPT || Err "WGET: $?"

    logit "Upload to Dropbox"
    
    GetAuth
    
    # Start the Upload
    
    #SIZE=`ls -alhtr ${DEST} | tail -1`
    DBFILE=`ls -1tr /tmp/${DEST}/ | tail -1`
    OUTFILE="$DBFILE"
        
    ## Check to see if file exists already in Dropbox
    DBFILES=`DropboxSearch $DBFILE`
    logit "DropboxSearch (check to see if file already exists, OK to be empty) DBFILES: $DBFILES"
        
    CheckFile
        
    logit "uploading DropboxUpload $OUTFILE " #($SIZE)"
    
    DropboxUpload $DBFILE
    logit "completed upload"
    
    logit "starting cleanup"
    rm $DBFILE
    logit "Deleted $DBFILE, cleanup complete"
    
    ## Notify of Upload
    logit "Notify of Upload to Dropbox"
    JSON="{ \"TITLE\" : \"SQS Download\", \"MESSAGE\": \"$DBFILE uploaded \" }"
    #logit "Notification currently disabled, Pushbullet lambda needs work."
    aws sqs send-message --queue-url "$QUEUE_URL" --message-body "$JSON"
    
    logit "completed notification"

    #STAT=`/tmp/jq`
    #logit "STAT $STAT"
    
    # Grab a message from the SQS queue
    #OUTPUT=`/tmp/sqs-get-msg-url.sh URLs`
    #logit "OUTPUT $OUTPUT"
    
    #cd /tmp/
    #wget -q "https://isc.sans.edu/podcast/podcast6814.mp3" && logit "a ok"

    RESPONSE="{\"statusCode\": 200, \"body\": \"Hello from Lambda!\"}"
    echo $RESPONSE
}
