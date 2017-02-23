#!/bin/bash

passphrase=$1
backupdir=$2
# check foldername does not contains forbidden chars
foldername=$3
hubicpy=../hubic.py
sha1sumFile="${backupdir}/.bkp_sha1sum.lst"
starttime=$(date +"%Y%m%d_%H%M%S")

echo `date +%Y%m%d\ %H:%M:%S` : Begining of script

touch "${sha1sumFile}"
ls "${backupdir}" | while read line; do

  namehash=$(echo -n ${line} | md5sum | awk '{ print $1 }')
  filename=$(echo ${line} | cut -d'/' -f 1,2 | sed "s/[ \/,.'!?()]//g")
  safeLine=$(echo ${line} | sed -e 's/[][()\.^$?*+]/\\&/g')
  sha1=$(find "${backupdir}/${line}" -type f -print0 | sort -z | xargs -0 shasum | shasum | cut -d' ' -f 1)
  bkpsha1=$(grep -x -E "[0-9a-f]{40} ${safeLine}" "${sha1sumFile}" | cut -d' ' -f 1)

  # Check if the file/folder is the same as the last backup
  if [[ -n "${bkpsha1}" && ("${sha1}" == "${bkpsha1}") ]]; then
    # In that case, do nothing
    echo "${sha1} ${line}"
    continue
  fi

  # Remove the line with old sha1
  if [[ -n "$bkpsha1" ]]; then
    sed -i '/'${bkpsha1}'/d' "${sha1sumFile}"
  fi

  # If its a file, the archive will be in the 'FILES' directory
  if [[ ! -d "${backupdir}/${line}" ]]; then
    dest_path=sync_backups/${foldername}/FILES/${filename}_${namehash}_${starttime}.tar.gz.gpg
  else
    dest_path=sync_backups/${foldername}/${filename}_${namehash}_${starttime}.tar.gz.gpg
  fi

  echo `date +%Y%m%d\ %H:%M:%S` : Compression will begin : ${filename}
  # Compression and encryption of the file/folder
  # TODO /home/pierre/hubic/tmp/ => ${4}/${backupdir}/ and delete/create it at the begining and the end of the script
  tar -P -czf - "${backupdir}/${line}" | gpg --batch --yes --passphrase ${passphrase} -ac -o "/home/pierre/hubic/tmp/${filename}_${namehash}.tar.gz.gpg"
  echo `date +%Y%m%d\ %H:%M:%S` : Upload will begin      : ${filename}

  #Calculate the size of swift segment to optimize the number of segment (empirical, around 100. 1000 is the maximum allowed)
  #TODO parameterize this
  actualsize=$(du -k "/home/pierre/hubic/tmp/${filename}_${namehash}.tar.gz.gpg" | cut -f 1)
  if [ ${actualsize} -le 5000000 ]; then
    segmentSize=30000000
  elif [ ${actualsize} -le 10000000 ]; then
    segmentSize=60000000
  elif [ ${actualsize} -le 20000000 ]; then
    segmentSize=120000000
  else
    segmentSize=240000000
  fi

  #Upload of the encrypted file
echo   $hubicpy --swift -- upload --use-slo --segment-size ${segmentSize} --object-threads 40 --segment-threads 20 --object-name "${dest_path}" default /home/pierre/hubic/tmp/${filename}_${namehash}.tar.gz.gpg
  $hubicpy --swift -- upload --use-slo --segment-size ${segmentSize} --object-threads 40 --segment-threads 20 --object-name "${dest_path}" default /home/pierre/hubic/tmp/${filename}_${namehash}.tar.gz.gpg
  echo `date +%Y%m%d\ %H:%M:%S` : Upload done            : ${filename}
  #TODO check the size of the uploaded file and compare with the local file size  
  if [ $? -eq 0 ]; then
    echo "${sha1} ${line}"
    echo "${sha1} ${line}" >> "${sha1sumFile}"
  else
    $hubicpy --swift -- list default_segments | grep "sync_backups/$(basename ${backupdir})/${filename}_${namehash}.tar.gz.gpg" | xargs -I {} sh -c "${hubicpy} --swift delete {}"
    exit 1
    #TODO Do not exit the script but continu and warn of the error at the end of the script
  fi

rm -f /home/pierre/hubic/tmp/${filename}_${namehash}.tar.gz.gpg
echo `date +%Y%m%d\ %H:%M:%S` : File processed         : ${filename}
done

echo `date +%Y%m%d\ %H:%M:%S` : End of script
