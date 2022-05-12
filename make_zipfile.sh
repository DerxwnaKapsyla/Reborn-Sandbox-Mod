#!/bin/bash

if [ ! -e 'make_zipfile.sh' ]; then
  echo 'ERROR: it appears the script has been run from the wrong folder' >&2
  echo 'It needs to be run from the repo'\''s base folder' >&2
  exit 1
fi

releases_folder='Releases'
filename="${releases_folder}/Sandbox_E19_v$(cat 'VERSION').zip"
included_items=(
  'Data/Mods/'
  'Data/Map-05.rxdata'
  # 'Graphics/'
  'README.md'
  'Pokemon Reborn_ Sandbox Mode - Guide.xlsx'
)

mkdir -p "$releases_folder" || exit $?
[ -e "$filename" ] && rm "$filename" && echo "The old version of $filename has been deleted" >&2
echo "Generating $filename" >&2
zip -r "${filename}" "${included_items[@]}"

exit $?
