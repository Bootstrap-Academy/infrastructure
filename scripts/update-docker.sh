#!/usr/bin/env bash

exec &> >(tee docker-images.toml)

fetch() { skopeo inspect --format "\"$1\" = \"{{.Name}}@{{.Digest}}\"" "docker://$2"; }

for img in {auth,skills,shop,jobs,events}-ms:develop; do
  fetch "$img" "ghcr.io/bootstrap-academy/$img"
done

fetch "glitchtip" "glitchtip/glitchtip"
