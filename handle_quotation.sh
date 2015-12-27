#!/usr/bin/env bash

tools_dir="$(cd "$(dirname "$0")" && pwd)"
tweet_sh="$tools_dir/tweet.sh/tweet.sh"

base_dir="$TWEET_BASE_DIR"
log_dir="$TWEET_BASE_DIR/logs"
logfile="$log_dir/handle_quotation.log"

source "$tweet_sh"
load_keys

log() {
  echo "$*" 1>&2
  echo "[$(date)] $*" >> "$logfile"
}

while read -r tweet
do
  owner="$(echo "$tweet" | jq -r .user.screen_name)"
  id="$(echo "$tweet" | jq -r .id_str)"
  url="https://twitter.com/$owner/status/$id"

  log '=============================================================='
  log "Quoted by $owner at $url"

  body="$(echo "$tweet" | "$tweet_sh" body)"
  me="$(echo "$tweet" | jq -r .quoted_status.user.screen_name)"
  log " me: $me"
  log " body: $body"

  response="$(echo "$body" | "$responder")"
  if [ $? != 0 -o "$response" != '' ]
  then
    # Don't follow, favorite, and reply to the tweet
    # if it is a "don't respond" case.
    log " no response"
    continue
  fi

  if echo "$tweet" | jq -r .user.following | grep "false"
  then
  log " => follow $owner"
  result="$("$tweet_sh" follow $owner)"
  if [ $? = 0 ]
  then
    log '  => successfully followed'
  else
    log "  => failed to follow $owner"
    log "     result: $result"
  fi
  else
    log " => already followed"
  fi

  if echo "$tweet" | jq -r .favorited | grep "false"
  then
  log " => favorite $url"
  result="$("$tweet_sh" favorite $url)"
  if [ $? = 0 ]
  then
    log '  => successfully favorited'
  else
    log '  => failed to favorite'
    log "     result: $result"
  fi
  else
    log " => already favorited"
  fi

  if echo "$body" | grep "^@$me" > /dev/null
  then
    log "Seems to be a reply."
    log " response: $response"
    result="$("$tweet_sh" reply "$url" "$response")"
    if [ $? = 0 ]
    then
      log '  => successfully respond'
    else
      log '  => failed to reply'
      log "     result: $result"
    fi
  else
    log "Seems to be an RT with quotation."
    if echo "$tweet" | jq -r .retweeted | grep "false"
    then
    log " => retweet $url"
    result="$("$tweet_sh" retweet $url)"
    if [ $? = 0 ]
    then
      log '  => successfully retweeted'
    else
      log '  => failed to retweet'
      log "     result: $result"
    fi
    else
      log " => already retweeted"
    fi
  fi
done
