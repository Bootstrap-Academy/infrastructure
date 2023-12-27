#!/usr/bin/env bash

pw=$(pwgen -s 32 1)
echo "\`$1\` : \`$pw\`"
htpasswd -nbB "$1" "$pw" | head -1
