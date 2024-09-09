#!/usr/bin/env bash

if [[ $# -eq 0 ]]; then
  nix flake update --commit-lock-file
else
  args=""
  for x in "$@"; do
    args="$args --update-input $x"
  done
  nix flake lock $args --commit-lock-file
fi

ssh root@10.23.0.2 fetch-docker-images > hosts/prod2/docker-images.nix
