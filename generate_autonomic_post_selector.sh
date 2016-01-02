#!/usr/bin/env bash

work_dir="$(pwd)"
tools_dir="$(cd "$(dirname "$0")" && pwd)"
source "$tools_dir/common.sh"

echo 'Generating autonomic post selector script...' 1>&2
echo "  sources: $TWEET_BASE_DIR/scheduled" 1>&2
echo "  output : $autonomic_post_selector" 1>&2

cat << FIN > "$autonomic_post_selector"
#!/usr/bin/env bash
#
# This file is generated by "generate_autonomic_post_selector.sh".
# Do not modify this file manually.

base_dir="\$(cd "\$(dirname "\$0")" && pwd)"

case \$(uname) in
  Darwin|*BSD|CYGWIN*)
    esed="sed -E"
    ;;
  *)
    esed="sed -r"
    ;;
esac

choose_random_one() {
  local input="\$(cat)"
  local n_lines="\$(echo "\$input" | wc -l)"
  local index=\$(((\$RANDOM % \$n_lines) + 1))
  echo "\$input" | sed -n "\${index}p"
}

extract_message() {
  local source="\$1"
  if [ ! -f "\$source" ]
  then
    echo ""
    return 0
  fi

  local messages="\$(cat "\$source")"
  [ "\$messages" = '' ] && return 1
  echo "\$messages" | choose_random_one
}

echo_with_probability() {
  if [ \$(($RANDOM % 100)) -lt \$1 ]
  then
    cat
  fi
}

time_to_minutes() {
  local now="\$1"
  local hours=\$(echo "\$now" | \$esed 's/^0?([0-9]+):.*\$/\1/')
  local minutes=\$(echo "\$now" | \$esed 's/^[^:]*:0?([0-9]+)\$/\1/')
  echo $(( \$hours * 60 + \$minutes ))
}

now=\$1
[ "\$now" = '' ] && now="\$(date +%H:%M)"
now=\$(time_to_minutes \$now)

FIN

cd "$TWEET_BASE_DIR"

if [ -d ./scheduled ]
then
  for group in $(echo "$AUTONOMIC_POST_TIME_SPAN" | $esed "s/[$whitespaces]+/ /g") all
  do
    timespans="$(echo "$group" | cut -d '/' -f 2-)"
    group="$(echo "$group" | cut -d '/' -f 1)"
    messages_file="$status_dir/scheduled_$group.txt"
    echo '' > "${messages_file}.tmp"
    ls ./scheduled/$group* |
      sort |
      while read path
    do
      # convert CR+LF => LF for safety.
      nkf -Lu "$path" >> "${messages_file}.tmp"
      echo '' >> "$messages_file"
    done
    egrep -v "^#|^[$whitespaces]*$" "${messages_file}.tmp" > "$messages_file"
    rm -rf "${messages_file}.tmp"

    # no timespan given
    if [ "$timespans" = "$group" ]
    then
      cat << FIN >> "$autonomic_post_selector"
[ "\$DEBUG" != '' ] && echo "Allday case: choosing message from \"$messages_file\"" 1>&2
extract_message "$messages_file"
exit \$?

FIN
    else
      for timespan in $(echo "$timespans" | sed 's/,/ /g')
      do
        start="$(echo "$timespan" | cut -d '-' -f 1)"
        start="$(time_to_minutes "$start")"
        end="$(echo "$timespan" | cut -d '-' -f 2)"
        end="$(time_to_minutes "$end")"
        cat << FIN >> "$autonomic_post_selector"
if [ \$now -ge $start -a \$now -le $end ]
then
  [ "\$DEBUG" != '' ] && echo "$timespan: choosing message from \"$messages_file\"" 1>&2
  message="\$(extract_message "$messages_file" | echo_with_probability 60)"
  if [ "\$message" != '']
  then
    echo "\$message"
    exit \$?
  fi
fi

FIN
     done
    fi
  done
fi

cat << FIN >> "$autonomic_post_selector"
exit 1
FIN

chmod +x "$autonomic_post_selector"
