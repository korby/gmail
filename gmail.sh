#!/bin/bash

access_token=""
# If stdin is not empty, get token from it
if [ ! -t 0 ];
then
  while read line
  do
    access_token=$line
  done < /dev/stdin
fi

client_id="$(cat client_id.txt 2>/dev/null)"
client_secret="$(cat client_secret.txt 2>/dev/null)"
tokens_path=$client_id  
google_url_console="https://console.developers.google.com/apis/"
google_url_get_code="https://accounts.google.com/o/oauth2/auth?scope=https%3A%2F%2Fwww.googleapis.com%2Fauth%2Fgmail.readonly&redirect_uri=urn:ietf:wg:oauth:2.0:oob&response_type=code&client_id=$client_id"
google_url_get_tokens="https://accounts.google.com/o/oauth2/token"

if [ -f "./parent_dir" ]; then . ./parent_dir; fi

if [ "$client_id" == "" ]; then echo "Need client_id, you can get it here: "; echo "$google_url_console/credentials"; exit 1; fi
if [ "$client_secret" == "" ]; then echo "Need client_secret, you can get it here: "; echo "$google_url_console/credentials"; exit 1; fi
if [ ! -f $tokens_path ] && [ "$access_token" = "" ]; then
	echo "Need a code to get token, please get it here: "
	echo $google_url_get_code
    read -p "Type the code:" code
	json_back=`curl -H 'Content-Type: application/x-www-form-urlencoded' -d "code=$code&client_id=$client_id&client_secret=$client_secret&redirect_uri=urn:ietf:wg:oauth:2.0:oob&grant_type=authorization_code" $google_url_get_tokens`

    refresh_token=`echo "$json_back" | grep "refresh_token" |cut -d ":" -f2 | sed "s/.$//" | sed "s/^.//" | sed 's/"//g'`
    if [ "$refresh_token" == "" ]; then
    	echo "Failure during token request, here the response:"
    	echo $json_back
    	exit 1
    fi
    echo "$refresh_token:" > $tokens_path;
fi

function get_access_token () {
  if [ "$access_token" != "" ]; then echo $(echo $access_token | cut -d ':' -f2); return 0; fi
	# if token is less than one hour aged
  if [ "$(find $tokens_path -mmin +55)" == "" ]; then
    access_token=`cat $tokens_path | cut -d ':' -f2`
  fi
	if [ "$access_token" == "" ]; then
		refresh_token=`cat $tokens_path | cut -d ':' -f1`;
		json_back=`curl -sS -d "client_id=$client_id&client_secret=$client_secret&refresh_token=$refresh_token&grant_type=refresh_token" $google_url_get_tokens`;
		access_token=`echo "$json_back" | grep "access_token" |cut -d ":" -f2 | sed "s/.$//" | sed "s/^.//" | sed 's/"//g'`
    if [ "$(uname)" == "Darwin" ]; then
            sed -i "" "s/:.*$/:$access_token/g" $tokens_path
    else
            sed -i "s/:.*$/:$access_token/g" $tokens_path
    fi

	fi

    echo $access_token;
}

function get_last_mail () {
	access_token=$1
  emergency_address="toto@toto.com"
  subject_header_index=19
	ref=`curl --silent \
				-X GET \
				-H "Host: www.googleapis.com" \
				-H "Authorization: Bearer $access_token" \
				"https://www.googleapis.com/gmail/v1/users/me/messages?q=to:$emergency_address%20is:unread"`

  num_result=$(echo "$ref" | python3 -c 'import sys, json; print(json.load(sys.stdin)["resultSizeEstimate"])')

  if [ $num_result == 0 ]; then
    echo "No newmail"
    exit 0
  else
    message_id=$(echo "$ref" | python3 -c 'import sys, json; print(json.load(sys.stdin)["messages"][0]["id"])')
  fi
	

	ref=`curl --silent \
				-X GET \
				-H "Host: www.googleapis.com" \
				-H "Authorization: Bearer $access_token" \
				"https://www.googleapis.com/gmail/v1/users/me/messages/$message_id"`

	echo "$ref" | python3 -c 'import sys, json; print(json.load(sys.stdin)["payload"]["headers"]['$subject_header_index']["value"])'
}
access_token=`get_access_token`;

get_last_mail $access_token

exit 0;
