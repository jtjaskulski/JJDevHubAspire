#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "$1" >&2
  exit 2
}

if [[ $# -ne 2 ]]; then
  usage "podaj nazwę narzędzia i katalog"
fi

name=$1
dest=$2

case "$name" in
  gitleaks) repo=gitleaks/gitleaks ;;
  zizmor) repo=zizmorcore/zizmor ;;
  scorecard) repo=ossf/scorecard ;;
  *) usage "nieznane narzędzie" ;;
esac

if [[ ! -d $dest ]]; then
  usage "brak katalogu"
fi

command -v curl >/dev/null 2>&1 || usage "brak curl"
command -v sha256sum >/dev/null 2>&1 || usage "brak sha256sum"
command -v tar >/dev/null 2>&1 || usage "brak tar"

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH='' cd -- "${script_dir}/../.." && pwd)
sums="${repo_root}/.github/supply-chain/checksums.txt"
if [[ ! -f $sums ]]; then
  usage "brak checksums.txt"
fi

version=""
sha=""
filename=""
while read -r row_name row_version row_sha row_filename extra; do
  [[ -z ${row_name:-} || $row_name == \#* ]] && continue
  if [[ -n ${extra:-} ]]; then
    usage "zła linia sumy"
  fi
  if [[ $row_name == "$name" ]]; then
    if [[ -n $version ]]; then
      usage "podwójna linia narzędzia"
    fi
    version=$row_version
    sha=$row_sha
    filename=$row_filename
  fi
done < "$sums"

if [[ -z $version || -z $sha || -z $filename ]]; then
  usage "brak wiersza narzędzia"
fi

if [[ ! $sha =~ ^[0-9a-fA-F]{64}$ ]]; then
  usage "zła suma"
fi

archive=$(mktemp)
extract=$(mktemp -d)
trap 'rm -rf "$archive" "$extract"' EXIT

url="https://github.com/${repo}/releases/download/v${version}/${filename}"
curl --silent --show-error --fail --location --output "$archive" "$url"
echo "${sha}  ${archive}" | sha256sum -c -
tar -xzf "$archive" -C "$extract"
binary=$(find "$extract" -type f -name "$name" -print -quit)
if [[ -z $binary ]]; then
  echo "brak binarki ${name}" >&2
  exit 1
fi
install -m 0755 "$binary" "${dest}/${name}"
