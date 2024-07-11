#!/usr/bin/env bash

exec &> >(tee docker-images.toml)

fetch() { skopeo inspect --format "\"$1\" = \"{{.Name}}@{{.Digest}}\"" "docker://$2"; }

fetch "glitchtip" "glitchtip/glitchtip"
fetch "morpheushelper" "ghcr.io/pydrocsid/morpheushelper"
