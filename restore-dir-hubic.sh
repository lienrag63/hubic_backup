#!/bin/bash

echo `date +%Y%m%d\ %H:%M:%S` : Begining of script

passphrase=$1
backupdir=$2
foldername=$3
hubicpy=./hubic.py
sha1sumFile="${backupdir}/.bkp_sha1sum.lst"

#TODO tests of $2 local folder and $3 distant folder existance

# Creation of the temprorary folder if it does not exist yet
mkdir -p /media/wd0/tests/${foldername}
cd /media/wd0/tests/${foldername}

# For all files in the designated distant folder
for gpg_file_path in `~/hubic/hubic.py --swift -- list default -p sync_backups/${foldername}/`; do
	# Sometimes the for loop goes crazy, i do not know why, yet. So, little check
	if [[ ${gpg_file_path} != *"${foldername}"* ]]
	then
		echo `date +%Y%m%d\ %H:%M:%S` : ERROR Wrong file : ${gpg_file_path}	
		continue
	fi
	
	# Get the size of the distant file, to compare to a previous execution downloaded file and/or the futur downloaded file
	length_remote=$(~/hubic/hubic.py --swift -- stat default ${gpg_file_path} | grep "Content Length" | cut -d' ' -f11)
	echo `date +%Y%m%d\ %H:%M:%S` : The file has a size of ${length_remote=} : ${gpg_file_path}
	# If file already exists AND local file size equals distant file size
	if test -f "${gpg_file_path}" && test "${length_remote}" -eq "$(du -b "${gpg_file_path}" | cut -f 1)"
	then
		echo `date +%Y%m%d\ %H:%M:%S` : The file has already been succesfully downloaded : ${gpg_file_path}
		continue
	fi
	# If file already exists AND local file size NOT equals distant file size
	if test -f "${gpg_file_path}" && test "${length_remote}" -ne "$(du -b "${gpg_file_path}" | cut -f 1)"	
       	then
		echo `date +%Y%m%d\ %H:%M:%S` : Sizes do not match, the file is removed  : ${gpg_file_path}
		rm -f ${gpg_file_path}
	fi
	echo `date +%Y%m%d\ %H:%M:%S` : The file will be downloaded   : ${gpg_file_path}
		
	# Download the file
	~/hubic/hubic.py --swift -- download default ${gpg_file_path}
	
	# Size of the downloaded file, for comparison
	actualsize=$(du -b "${gpg_file_path}" | cut -f 1)
	# If the size of the downloaded file does not matche the size of the distant file		
	if [ "${length_remote}" -ne "${actualsize}" ]
	then
		echo `date +%Y%m%d\ %H:%M:%S` : ERROR Download KO. Size=${actualsize}
		continue
	else
		echo `date +%Y%m%d\ %H:%M:%S` : Download OK. Size=${actualsize}
	fi

	# In case there is the decrypted file wandering. Does not happen, normally
	if [ -f "${gpg_file_path::-4}" ]
       	then
		echo `date +%Y%m%d\ %H:%M:%S` : The file decrypted file already existes and will be deleted : ${gpg_file_path::-4}
		rm -f ${gpg_file_path::-4}
	fi
	echo `date +%Y%m%d\ %H:%M:%S` : The file will be decrypted    : ${gpg_file_path}
		
	# Decryption of the file
	gpg --passphrase ${passphrase} $gpg_file_path
	echo `date +%Y%m%d\ %H:%M:%S` : The file will be decompressed : ${gpg_file_path::-4}
		
	# Decompression of the file
	tar -xzvf ${gpg_file_path::-4}

	# Deletion of the file
	rm -f ${gpg_file_path::-4} 
done 

echo ------------------------------------------------------------
echo ------------------------------------------------------------
echo ---------------------- COMPARISON --------------------------
echo ------------------------------------------------------------
echo ------------------------------------------------------------
# Comparison between the original folder backupdir and the backup
diff -r .${backupdir} ${backupdir}

#TODO deletion of the folder.${backupdir}

echo `date +%Y%m%d\ %H:%M:%S` : End of script
