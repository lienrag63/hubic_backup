#!/usr/local/bin/bash

BACKUP_DIR=$2
hubicpy=./hubic.py
sha1sumFile="${BACKUP_DIR}/.bkp_sha1sum.lst"
passphrase=$1

touch "${sha1sumFile}"
ls "$BACKUP_DIR" | while read line; do

  if [[ ! -d "$BACKUP_DIR/$line" ]]; then
    continue
  fi

  filename=$(echo $line | cut -d'/' -f 1,2 | sed "s/[ \/,.'!?()]//g")
  safeLine=$(echo $line | sed -e 's/[][()\.^$?*+]/\\&/g')

  sha1=$(find "$BACKUP_DIR/$line" -type f -print0 | sort -z | xargs -0 shasum | shasum | cut -d' ' -f 1)
  bkpsha1=$(grep -x -E "[0-9a-f]{40} ${safeLine}" "${sha1sumFile}" | cut -d' ' -f 1)
  
  if [[ -n "$bkpsha1" && ("$sha1" == "$bkpsha1") ]]; then
    echo "${sha1} ${line}"
    continue
  fi

  # Remove the line with old sha1
  if [[ -n "$bkpsha1" ]]; then
    sed -i '/'$bkpsha1'/d' "${sha1sumFile}"
  fi

  tar -P -czf - "${BACKUP_DIR}/${line}" | gpg --batch --yes --passphrase ${passphrase} -ac -o "/tmp/${filename}.tar.gz.gpg"
  $hubicpy --swift -- upload --use-slo --segment-size 15000000 --object-name "backups/$(basename $BACKUP_DIR)/${filename}.tar.gz.gpg" default /tmp/${filename}.tar.gz.gpg
  if [ $? -eq 0 ]; then
    echo "${sha1} ${line}"
    echo "${sha1} ${line}" >> "${sha1sumFile}"
  else
    $hubicpy --swift -- list default_segments | grep "backups/$(basename $BACKUP_DIR)/${filename}.tar.gz.gpg" | xargs -I {} sh -c "${hubicpy} --swift delete {}"
    exit 1
  fi
  rm -f /tmp/${filename}.tar.gz.gpg
done

# Clean the sha1 file
while IFS='' read -r line || [[ -n "$line" ]]; do
  filename=$(echo $line | cut -d' ' -f 2-)

  if [[ ! -d "$BACKUP_DIR/$filename" ]]; then
    sha1=$(echo $line | cut -d' ' -f 1)
    sed -i '/'$sha1'/d' "${sha1sumFile}"
  fi
done < "${sha1sumFile}"

