#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./verify.sh [--image IMAGE] [--denylist FILE]

Check public source files and an existing linux/amd64 base image.
Default image: docker.io/smilchsack/mendix-ubi-buildbase:ubi9-2026-09
Requires Docker, Bash, and standard Unix command-line tools.

The optional external denylist contains one literal, case-insensitive pattern per
line. Empty lines are rejected. Patterns and the file path are never printed.
It scans public files, image metadata/history, the saved image archive, and an
export of the final filesystem. Archive scans include literal binary strings.
Compressed/encrypted content, encoded variants, build caches, Git history, and
unknown sensitive information are outside this check. Deleted layer contents
are only covered when present as uncompressed bytes in the saved archive.
These checks detect known paths and supplied patterns; they cannot establish
that every file is free of credentials. Review public files and publication
history separately before publishing. Verification does not publish anything.
EOF
}
fail() { printf 'Verification failed: %s\n' "$1" >&2; exit 1; }
image=docker.io/smilchsack/mendix-ubi-buildbase:ubi9-2026-09
denylist=
while [ "$#" -gt 0 ]; do
  case "$1" in
    --image) [ "$#" -ge 2 ] || fail 'missing image argument'; image=$2; shift 2 ;;
    --denylist) [ "$#" -ge 2 ] || fail 'missing denylist argument'; denylist=$2; shift 2 ;;
    --help|-h) usage; exit 0 ;;
    *) fail 'unknown argument (see --help)' ;;
  esac
done
public_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
source_files=()
for entry in "$public_dir"/* "$public_dir"/.[!.]* "$public_dir"/..?*; do
  [ -e "$entry" ] || [ -L "$entry" ] || continue
  [ ! -L "$entry" ] || fail 'public directory contains a symlink'
  case "${entry##*/}" in
    Dockerfile|README.md|SECURITY.md|LICENSE|NOTICE|LICENSES.md|release-manifest.json|packages.tsv|sources-manifest.json|verify.sh|.dockerignore|.gitignore)
      [ -f "$entry" ] || fail 'public source must be a regular file'
      source_files+=("$entry") ;;
    .github)
      [ -d "$entry" ] || fail 'unexpected CI metadata file'
      while IFS= read -r -d '' ci_entry; do
        [ ! -L "$ci_entry" ] || fail 'CI configuration contains a symlink'
        case "${ci_entry#"$public_dir/"}" in
          .github/workflows) [ -d "$ci_entry" ] || fail 'unexpected CI directory' ;;
          .github/workflows/publish.yml|.github/dependabot.yml)
            [ -f "$ci_entry" ] || fail 'CI configuration must be a regular file'
            source_files+=("$ci_entry") ;;
          *) fail 'public CI directory contains an unexpected file or directory' ;;
        esac
      done < <(find "$entry" -mindepth 1 -print0)
      ;;
    .git) [ -d "$entry" ] || fail 'unexpected Git metadata file' ;;
    *) fail 'public directory contains an unexpected file or directory' ;;
  esac
done
for name in Dockerfile README.md verify.sh .dockerignore LICENSES.md \
  release-manifest.json packages.tsv sources-manifest.json; do
  [ -f "$public_dir/$name" ] || fail 'required public source is missing'
done
cmp -s "$public_dir/.dockerignore" <(printf '**\n!Dockerfile\n!.dockerignore\n') \
  || fail 'build context must contain only Dockerfile and .dockerignore'
awk '
  /^[[:space:]]*($|#)/ { next }
  { first = continued ? 1 : 2 }
  !continued {
    instruction = toupper($1)
    if (instruction != "FROM" && instruction != "RUN" &&
        instruction != "ENV" && instruction != "CMD" && instruction != "LABEL") exit 1
    if (instruction == "FROM") bases++
    environment = instruction == "ENV"
  }
  environment {
    for (field = first; field <= NF; field++)
      if ($field != "\\" && $field !~ /^(LANG|LC_ALL)=/) exit 1
  }
  { continued = /\\[[:space:]]*$/ }
  END { if (continued || bases != 1) exit 1 }
' "$public_dir/Dockerfile" || fail 'Dockerfile contains an unexpected instruction'
grep -Eq '^FROM registry\.access\.redhat\.com/ubi9/ubi-minimal:9\.[0-9]+@sha256:[a-f0-9]{64}[[:space:]]*$' \
  "$public_dir/Dockerfile" || fail 'UBI9 base image must be pinned by SHA-256 digest'
if grep -Eq '^#[[:space:]]*syntax=' "$public_dir/Dockerfile"; then
  grep -Eq '^# syntax=docker/dockerfile:1@sha256:[a-f0-9]{64}$' "$public_dir/Dockerfile" \
    || fail 'an explicit Dockerfile frontend must be pinned by SHA-256 digest'
fi
while IFS= read -r origin; do
  case "$origin" in
    https://registry.access.redhat.com|https://dl.fedoraproject.org) ;;
    *) fail 'Dockerfile contains an unexpected package source' ;;
  esac
done < <(grep -Eo 'https?://[[:alnum:]._-]+(:[0-9]+)?' "$public_dir/Dockerfile" || true)

if [ -n "$denylist" ]; then
  [ -f "$denylist" ] && [ -r "$denylist" ] && [ ! -L "$denylist" ] && [ -s "$denylist" ] \
    || fail 'denylist must be a readable, nonempty external regular file'
  deny_dir=$(CDPATH= cd -- "$(dirname -- "$denylist")" 2>/dev/null && pwd -P) \
    || fail 'cannot access denylist directory'
  case "$deny_dir/" in
    "$public_dir/"*) fail 'denylist must be outside the public directory' ;;
  esac
  if LC_ALL=C grep -Eq '^[[:space:]]*$' "$denylist" 2>/dev/null; then
    fail 'denylist must not contain empty or whitespace-only lines'
  fi
fi
command -v docker >/dev/null 2>&1 || fail 'Docker is required'
umask 077
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/buildbase-verify.XXXXXXXX" 2>/dev/null) \
  || fail 'cannot create private temporary directory'
container_id=
cleanup() {
  [ -z "$container_id" ] || docker rm "$container_id" >/dev/null 2>&1 || true
  rm -rf "$work_dir"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
scan() {
  [ -n "$denylist" ] || return 0
  local result=0
  LC_ALL=C grep -aiF -f "$denylist" "$@" >/dev/null 2>"$work_dir/tool.log" || result=$?
  [ "$result" -ne 0 ] || fail 'a denylist pattern was found (details withheld)'
  [ "$result" -eq 1 ] || fail 'denylist scan could not be completed'
}
scan "${source_files[@]}"
docker image inspect "$image" >"$work_dir/metadata.json" 2>"$work_dir/tool.log" \
  || fail 'cannot inspect the local image'
platform=$(docker image inspect --format '{{.Os}}/{{.Architecture}}' "$image" 2>"$work_dir/tool.log")
[ "$platform" = linux/amd64 ] || fail 'image platform must be linux/amd64'
docker image inspect --format '{{range .Config.Env}}{{println .}}{{end}}' "$image" \
  >"$work_dir/environment.txt" 2>"$work_dir/tool.log" || fail 'cannot inspect image environment'
awk -F= 'tolower($1) ~ /(proxy|token|secret|password|passwd|access_key|username|credential)/ { exit 1 }' \
  "$work_dir/environment.txt" || fail 'image contains a sensitive environment variable'
docker history --no-trunc --format '{{json .}}' "$image" >"$work_dir/history.json" 2>"$work_dir/tool.log" \
  || fail 'cannot inspect image history'
scan "$work_dir/metadata.json" "$work_dir/history.json"
docker run --rm --pull=never --platform linux/amd64 --network=none --read-only \
  --user 0:0 --cap-drop=ALL --security-opt=no-new-privileges \
  --entrypoint /bin/sh "$image" -ec '
  rpm -q glibc-langpack-en openssl fontconfig tzdata-java libgdiplus libicu \
    tar gzip jq java-11-openjdk-devel java-17-openjdk-devel \
    java-21-openjdk-devel ca-certificates >/dev/null
  for version in 11 17 21; do
    /usr/lib/jvm/java-${version}-openjdk/bin/java -version >/dev/null 2>&1
    /usr/lib/jvm/java-${version}-openjdk/bin/javac -version >/dev/null 2>&1
  done
  found=0
  for library in /usr/lib64/libgdiplus.so*; do
    [ -f "$library" ] || continue
    found=1
    dependencies=$(ldd "$library")
    case "$dependencies" in *"not found"*) exit 1 ;; esac
  done
  [ "$found" -eq 1 ]
  for path in /opt/mendix /opt/gradle /app /application /srv/app \
    /usr/local/gradle /root/.gradle /root/.m2 /root/.npmrc /root/.git-credentials \
    /root/.ssh /root/.aws /root/.azure /opt/app; do
    [ ! -e "$path" ]
  done
  unexpected=$(find / -path /proc -prune -o -path /sys -prune -o \
    -path /dev -prune -o \( -iname "*mxbuild*" -o -iname "*mendix*" \
    -o -iname "*gradle*" -o -name "*.mda" -o -name "*.mpr" \
    -o -name "*.mpk" -o -name "m2.conf" -o -name "settings.xml" \
    -o -name ".env" -o -name ".env.*" -o -name ".npmrc" \
    -o -name ".git-credentials" -o -name "id_rsa" -o -name "id_ed25519" \) -print)
  [ -z "$unexpected" ]
' >"$work_dir/runtime.log" 2>&1 || fail 'image package, Java, library, or base-only content check failed'
if [ -n "$denylist" ]; then
  docker image save --output "$work_dir/image.tar" "$image" 2>"$work_dir/tool.log" \
    || fail 'cannot save image for denylist scan'
  scan "$work_dir/image.tar"
  rm "$work_dir/image.tar"
  container_id=$(docker create --platform linux/amd64 --network=none --read-only "$image" 2>"$work_dir/tool.log") \
    || fail 'cannot create image filesystem snapshot'
  docker export --output "$work_dir/filesystem.tar" "$container_id" 2>"$work_dir/tool.log" \
    || fail 'cannot export image filesystem for denylist scan'
  scan "$work_dir/filesystem.tar"
fi
printf 'Verified public sources, required packages, Java 11/17/21, and base-only image contents.\n'
if [ -n "$denylist" ]; then
  printf 'Denylist scan passed for sources, metadata, history, saved layers, and final filesystem.\n'
else
  printf 'No denylist supplied; organization-specific text was not checked.\n'
fi
