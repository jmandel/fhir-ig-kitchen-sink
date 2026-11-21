#!/bin/bash
# Build the kitchen-sink IG with a given IG Publisher jar.
#
# usage: ./build.sh -j PUBLISHER_JAR [options] [-- extra publisher arguments]
#
#   -j JAR     publisher jar (required). In docker mode: a path on the Docker host.
#   -w DIR     work directory: the IG source is copied here and built here (default: a fresh
#              directory under ${TMPDIR:-/tmp}). The build writes output/, temp/, input-cache/ and the
#              factory output inside it, never into the source tree. Put it on a local disk: an IG build
#              touches tens of thousands of files. In docker mode: a path on the Docker host.
#   -t MODE    terminology: "live" (default: tx.fhir.org, answers cached in input-cache/txcache),
#              "offline" (-tx n/a: no terminology server; the build needs no network once the
#              packages are in the package cache), "record:DIR", "replay:DIR" or "strict:DIR"
#              (record/replay ledgers under DIR/main and DIR/r4; these need a publisher build that has
#              -tx-record/-tx-replay).
#   -m HEAP    Java heap (default 4g).
#   -c CACHE   package cache to use as ~/.fhir (default: the user's ~/.fhir). In docker mode: a path on
#              the Docker host or a Docker volume name.
#   -d IMAGE   run the publisher in this Docker image (it needs java and bash). The source is streamed
#              into the container with tar, so nothing is bind-mounted from the machine you run this on;
#              the work directory, jar and cache live on the Docker host (local disk there).
#   -i WHICH   ".": the R5 guide (default), "r4": the R4 companion, "all": both (companion first).
#   -n         no network: pass -no-network to the publisher (it then skips package-currency checks
#              and usage stats instead of waiting for them to time out) and, in docker mode, also run the
#              container with --network none to prove the build needs none. Use with -t offline or a
#              strict replay, and a populated package cache.
#   -k         keep an existing work directory (incremental rebuild) instead of replacing it.
#   -a         also build input/extra: resources that current publishers cannot build (an R5 TestPlan and
#              Citation abort the load, a CompartmentDefinition crashes package.db generation; see README).
#              Left out by default; use -a to test a publisher fix. The rest of the guide does not need them.
#
# Prints the build time and the QA summary line. Exit code is the publisher's.
set -euo pipefail
SRC="$(cd "$(dirname "$0")" && pwd)"
JAR=""; WORK=""; TX=live; HEAP=4g; CACHE=""; IMAGE=""; KEEP=0; EXTRA=0; IGDIR=.; NONET=0
while getopts "j:w:t:m:c:d:i:knah" o; do
  case "$o" in
    j) JAR="$OPTARG" ;; w) WORK="$OPTARG" ;; t) TX="$OPTARG" ;; m) HEAP="$OPTARG" ;;
    c) CACHE="$OPTARG" ;; d) IMAGE="$OPTARG" ;; k) KEEP=1 ;; n) NONET=1 ;; a) EXTRA=1 ;; i) IGDIR="$OPTARG" ;;
    *) sed -n '2,32p' "$0"; exit 2 ;;
  esac
done
shift $((OPTIND-1))
[ -n "$JAR" ] || { sed -n '2,32p' "$0"; exit 2; }
[ -n "$WORK" ] || WORK="${TMPDIR:-/tmp}/kitchen-sink-build"

case "$TX" in
  live|offline|record:*|replay:*|strict:*) ;;
  *) echo "unknown -t $TX" >&2; exit 2 ;;
esac
case "$IGDIR" in
  all) IGDIRS="r4 ." ;;   # the companion first: the main guide lists it as a related IG
  .|r4) IGDIRS="$IGDIR" ;;
  *) echo "unknown -i $IGDIR" >&2; exit 2 ;;
esac

# The steps that run where the build runs (locally, or inside the container).
# $1 = work dir, $2 = jar, $3 = keep (0/1); stdin = tar of the IG source.
inner='set -euo pipefail
W="$1"; J="$2"; K="$3"; shift 3
if [ "$K" = 1 ] && [ -d "$W" ]; then
  tar -xf - -C "$W"
else
  rm -rf "$W"; mkdir -p "$W"; tar -xf - -C "$W"
fi
mkdir -p "$W/input/factory-output"
[ "'"$EXTRA"'" = 1 ] || rm -f "$W"/input/extra/*.json
rc=0
for d in '"$IGDIRS"'; do
  n=main; [ "$d" = . ] || n="$d"
  TX='"$TX"'
  case "$TX" in
    live) TXARGS="" ;;
    offline) TXARGS="-tx n/a" ;;
    record:*) TXARGS="-tx-record ${TX#record:}/$n" ;;
    replay:*) TXARGS="-tx-replay ${TX#replay:}/$n" ;;
    strict:*) TXARGS="-tx-replay ${TX#strict:}/$n -tx-replay-strict" ;;
  esac
  case "$TX" in record:*) mkdir -p "${TX#record:}/$n" ;; esac
  cd "$W/$d"
  start=$(date +%s)
  [ '"$NONET"' = 1 ] && TXARGS="$TXARGS -no-network"
  java -Xmx'"$HEAP"' -Duser.home="$HOME" -jar "$J" -ig . $TXARGS "$@" > "$W/publisher-$n.log" 2>&1 || rc=$?
  end=$(date +%s)
  echo "[$n] build_seconds=$((end-start)) exit=$rc log=$W/publisher-$n.log output=$PWD/output"
  grep -m1 -E "^ *(Errors:|Publishing Content Failed)" "$W/publisher-$n.log" || true
  [ "$rc" = 0 ] || break
done
exit $rc'

tarsrc() {
  # everything except build outputs and caches the publisher writes into an IG folder
  local x=()
  tar --version 2>/dev/null | grep -q bsdtar && x=(--no-mac-metadata --no-xattrs)
  (cd "$SRC" && find . \( -path ./.git -o -path ./output -o -path ./temp -o -path ./template \
      -o -path ./translations -o -path ./input/factory-output -o -path ./input/factories/log \
      -o -path ./r4/output -o -path ./r4/temp -o -path ./r4/template -o -path ./r4/translations \) -prune \
      -o -print) | COPYFILE_DISABLE=1 tar "${x[@]}" -C "$SRC" --no-recursion -T - -cf -
}

if [ -z "$IMAGE" ]; then
  [ -f "$JAR" ] || { echo "no such jar: $JAR" >&2; exit 2; }
  JAR="$(cd "$(dirname "$JAR")" && pwd)/$(basename "$JAR")"
  if [ -n "$CACHE" ]; then
    # the publisher reads the package cache from ~/.fhir
    tarsrc | HOME="$(mktemp -d)" bash -c "ln -s '$CACHE' \"\$HOME/.fhir\"; $inner" _ "$WORK" "$JAR" "$KEEP" "$@"
  else
    tarsrc | bash -c "$inner" _ "$WORK" "$JAR" "$KEEP" "$@"
  fi
else
  CM=()
  [ -n "$CACHE" ] && CM=(-v "$CACHE:/home/kitchen-sink/.fhir")
  [ "$NONET" = 1 ] && CM+=(--network none)
  tarsrc | docker run --rm -i -e HOME=/home/kitchen-sink \
    -v "$(dirname "$WORK"):$(dirname "$WORK")" -v "$JAR:/opt/publisher.jar:ro" "${CM[@]}" \
    --entrypoint bash "$IMAGE" -c "mkdir -p /home/kitchen-sink; $inner" _ "$WORK" /opt/publisher.jar "$KEEP" "$@"
fi
