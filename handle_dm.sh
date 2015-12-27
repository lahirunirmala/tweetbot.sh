#!/usr/bin/env bash

tools_dir="$(cd "$(dirname "$0")" && pwd)"
tweet_sh="$tools_dir/tweet.sh/tweet.sh"

base_dir="$TWEET_BASE_DIR"
log_dir="$TWEET_BASE_DIR/logs"
logfile="$log_dir/handle_mention.log"

source "$tweet_sh"
load_keys

log() {
  echo "$*" 1>&2
  echo "[$(date)] $*" >> "$logfile"
}

administrators="$(cat "$TWEET_BASE_DIR/administrators.txt" |
                    sed 's/^\s+|\s+$//' |
                    paste -s -d '|')"
if [ "$administrators" = '' ]
then
  exit 1
fi

while read -r message
do
  screen_name="$(echo "$message" | jq -r .user.screen_name)"
  id="$(echo "$message" | jq -r .id_str)"

  log '=============================================================='
  log "DM from $screen_name"

  body="$(echo "$message" | "$tweet_sh" body)"
  log " body    : $body"

  if echo "$screen_name" | egrep -v "$administrators" > /dev/null
  then
    log ' => not an administrator, ignore it"
    continue
  fi
done