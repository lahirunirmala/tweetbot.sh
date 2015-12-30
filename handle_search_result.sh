#!/usr/bin/env bash

work_dir="$(pwd)"
tools_dir="$(cd "$(dirname "$0")" && pwd)"
source "$tools_dir/common.sh"
logfile="$log_dir/handle_search_result.log"

while read -r tweet
do
  screen_name="$(echo "$tweet" | jq -r .user.screen_name)"
  id="$(echo "$tweet" | jq -r .id_str)"
  url="https://twitter.com/$screen_name/status/$id"

  log '=============================================================='
  log "Search result found, tweeted by $screen_name at $url"

  if echo "$tweet" | expired_by_seconds $((24 * 60 * 60))
  then
    log " => ignored, because this is tweeted one day or more ago"
    continue
  fi

  if is_already_replied "$id"
  then
    log '  => already replied'
    continue
  fi

  body="$(echo "$tweet" | "$tweet_sh" body)"
  log " body    : $body"

  if echo "$body" | egrep "^RT @[^:]+:" > /dev/null
  then
    log " => ignored, because this is a retweet"
    continue
  fi

  export SCREEN_NAME="$owner"
  responses="$(echo "$body" | "$responder")"
  if [ $? != 0 -o "$responses" = '' ]
  then
    # Don't favorite and reply to the tweet
    # if it is a "don't respond" case.
    log " => don't response case"
    continue
  fi

  # log " => follow $screen_name"
  # "$tweet_sh" follow $screen_name > /dev/null

  is_true "$FAVORITE_SEARCH_RESULTS" && (echo "$tweet" | favorite)
  is_true "$RETWEET_SEARCH_RESULTS" && (echo "$tweet" | retweet)
  if is_true "$RESPOND_TO_SEARCH_RESULTS"
  then
    # Don't post default questions as quotation!
    responses="$(echo "$body" | env NO_QUESTION=1 "$responder")"
    if [ $? != 0 -o "$responses" = '' ]
    then
      log " => don't quote case"
      continue
    fi
    echo "$responses" |
      post_quotation "$screen_name" "$id"
  fi
done
