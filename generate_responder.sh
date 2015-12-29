#!/usr/bin/env bash

work_dir="$(pwd)"
tools_dir="$(cd "$(dirname "$0")" && pwd)"
tweet_sh="$tools_dir/tweet.sh/tweet.sh"

source "$tweet_sh"

if [ "$TWEET_BASE_DIR" != '' ]
then
  TWEET_BASE_DIR="$(cd "$TWEET_BASE_DIR" && pwd)"
else
  TWEET_BASE_DIR="$work_dir"
fi

responder="$TWEET_BASE_DIR/responder.sh"

echo 'Generating responder script...' 1>&2
echo "  sources: $TWEET_BASE_DIR/responses" 1>&2
echo "  output : $responder" 1>&2

cat << FIN > "$responder"
#!/usr/bin/env bash
#
# This file is generated by "generate_responder.sh".
# Do not modify this file manually.

base_dir="\$(cd "\$(dirname "\$0")" && pwd)"

input="\$(cat |
            # remove all whitespaces
            sed 's/[ \f\n\r\t　]+/ /g'
            # normalize waves
            sed 's/〜/～/g')"

choose_random_one() {
  local input="\$(cat)"
  local n_lines="\$(echo "\$input" | wc -l)"
  local index=\$(((\$RANDOM % \$n_lines) + 1))
  echo "\$input" | sed -n "\${index}p"
}

# do nothing with the probability 1/N
probable() {
  local probability=\$1
  [ "\$probability" = '' ] && probability=2

  if [ \$((\$RANDOM % \$probability)) -eq 0 ]
  then
    return 0
  fi

  cat
}

extract_response() {
  local source="\$1"
  if [ ! -f "\$source" ]
  then
    echo ""
    return 0
  fi

  local responses="\$(cat "\$source" |
                        grep -v '^#' |
                        grep -v '^\s*\$')"

  [ "\$responses" = '' ] && return 1

  echo "\$responses" | choose_random_one
}

FIN

cd "$TWEET_BASE_DIR"

if [ -d ./responses ]
then
  ls ./responses/* |
    sort |
    grep -v '^(pong|questions|connectors)\.txt$' |
    while read path
  do
    matcher="$(\
      # first, convert CR+LF => LF
      nkf -Lu "$path" |
        # extract comment lines as definitions of matching patterns
        grep '^#' |
        # remove comment marks
        sed -e 's/^#\s*//' \
            -e '/^\s*$/d' |
        # concate them to a list of patterns
        paste -s -d '|')"
    [ "$matcher" = '' ] && continue
    cat << FIN >> "$responder"
if echo "\$input" | egrep -i "$matcher" > /dev/null
then
  extract_response "\$base_dir/$path"
  exit \$?
fi

FIN
  done

  pong_file='./responses/pong.txt'
  connectors_file='./responses/connectors.txt'
  questions_file='./responses/questions.txt'

  default_file='./responses/default.txt'
  if [ ! -f "$default_file"
       -a -f "$pong_file" ]
  then
    default_file="$(ls ./responses/* |
                     sort |
                     grep -v '^(pong|questions|connectors)\.txt$' |
                     tail -n 1)"
  fi
  cat << FIN >> "$responder"
# fallback to the last pattern

if [ -f "\$base_dir/$default_file" \
     -a "\$(echo 1 | probable 6)" = '' ]
then
  extract_response "\$base_dir/$default_file"
else
  pong="\$(extract_response "\$base_dir/$pong_file")"

  question="\$(extract_response "\$base_dir/$questions_file" | probable 5)"
  if [ "\$question" != '' ]
  then
    connctor="\$(extract_response "\$base_dir/$connectors_file" | probable 9)"
    [ "\$connector" != '' ] && connctor="\$connctor "

    question="\$connctor\$question"
    pong="\$(echo "\$pong" | probable 8)"
    [ "\$pong" != '' ] && pong="\$pong "
  fi

  echo "\$pong\$question"
fi

exit 0

FIN
fi

chmod +x "$responder"