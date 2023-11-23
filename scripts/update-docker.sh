#!/usr/bin/env bash

exec &> >(tee docker-images.toml)

for img in {auth,skills,shop,jobs,challenges}-ms:develop; do
  skopeo inspect --format "\"$img\" = \"{{.Name}}@{{.Digest}}\"" "docker://ghcr.io/bootstrap-academy/$img"
done
