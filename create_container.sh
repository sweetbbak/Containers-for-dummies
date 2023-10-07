#!/bin/env bash
# auto build container creation from docker hub
# image metadata

[ -z "${1}" ] && {
    echo -e ./"${0##*/} <container-directory> <output-dir>"
}

dir="${1}"
output="${2}"
readarray layers < <(jq '.[].Layers.[]' < "${dir}/manifest.json")

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
