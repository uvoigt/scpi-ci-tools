#!/bin/sh

#***REMOVED***
***REMOVED***
***REMOVED***

CONFIG_FILE=.config

if [ -f $CONFIG_FILE ]; then
  . ./$CONFIG_FILE
fi

if [ "$1" == "-a" ]; then
  ACCOUNT_ID=$2
  shift 2
fi

print_options() {
  printf "Options: -a <account_id>\n" 1>&2
  for var in "$@"; do
    printf "\t $var\n" 1>&2
  done
}
save_config() {
  printf "ACCOUNT_ID=%s\n" $ACCOUNT_ID > $CONFIG_FILE
  printf "USER=%s\n" $USER >> $CONFIG_FILE
  printf "XCSRFTOKEN=%s\n" $XCSRFTOKEN >> $CONFIG_FILE
}