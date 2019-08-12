#!/bin/sh

#***REMOVED***
***REMOVED***
***REMOVED***

CONFIG_FILE=.config

if [ -f $CONFIG_FILE ]; then
  . ./$CONFIG_FILE
fi
save_config() {
  printf "USER=%s\n" $USER > $CONFIG_FILE
  printf "XCSRFTOKEN=%s\n" $XCSRFTOKEN >> $CONFIG_FILE
}