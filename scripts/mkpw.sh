#!/usr/bin/env bash

pw=$(xkcdpass)
hashed=$(mkpasswd -s -m sha512crypt <<< "$pw")
cat << EOF
users:
    root:
        # $pw
        password: $hashed
EOF
