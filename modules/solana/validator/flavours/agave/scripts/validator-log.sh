#!/usr/bin/env bash
set -euo pipefail

function usage() {
  echo "USAGE: $0 logfile-dir symlink-name" >&2
  echo "" >&2
  echo "symlink-name  Name of the symlink to create to point to the latest log" >&2
}

function get_new_filename() {
  declare -i num
  num=0

  while true; do
    num+=1
    printf -v numStr "%02d" $num
    filename="$1/solana-validator-$(date +"%Y-%m-%d")_$numStr.log"

    [ -f "$filename" ] || break
  done

  echo "$filename"
}

if [ $# -lt 2 ]; then
  usage
  exit 1
fi

[ -d "$1" ] || mkdir -p "$1"

logfile=$(get_new_filename "$1")
touch "$logfile"
ln -sf "$logfile" "$2"
