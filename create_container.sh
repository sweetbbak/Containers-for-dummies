#!/bin/env bash
# auto build container creation from docker hub
# image metadata

# usage
[ -z "${1}" ] && {
    echo -e ./"${0##*/} <container-directory> <output-dir>"
    exit 0
}

# variables
dir="${1}"
output="${2}"

# does output exist? if not, make it or exit
[ ! -d "${output}" ] && mkdir -p "${output}" || exit

# is manifest.json where its expected to be? If not, try to intervene or exit
[ ! -f "${dir}/manifest.json" ] && {
    manifest=$(find "${dir}" -iname 'manifest.json')
    [ ! -f "${manifest}" ] && {
        echo "Couldn't find manifest.json"
        exit 0
    }
}

# get a list of the container layers
readarray layers < <(jq '.[].Layers.[]' < "${dir}/manifest.json")

# iterate over the layers, layering them in our rootfs
x=0
for layer in "${layers[@]}"; do
    echo -e "extracting ${layer}"

    if [ "${x}" -eq 0 ]; then
        echo "as base Layer"
        tar --extract --file "${x}" --directory="${output}"
    fi

    tar --extract --file "${x}" --directory="${output}"
    x=$((x+1))
done

echo -e "\e[3;33;3mDone. ${output} container created\e[0m"
sudo chroot "${output}"
