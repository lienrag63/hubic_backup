#!/bin/bash

echo `date +%Y%m%d\ %H:%M:%S` : Begining of script

passphrase=$1
backupdir=$2
foldername=$3
hubicpy=../hubic.py
sha1sumFile="${backupdir}/.bkp_sha1sum.lst"

#TODO tests of $2 local folder and $3 distant folder existance

# Creation of the temprorary folder if it does not exist yet
mkdir -p /media/wd0/tests/${foldername}
cd /media/wd0/tests/${foldername}

# FILES is an array with the name file without the date as index
# The associated values are the dates concatenated with the size
declare -A FILES

# hubic.py returns a value for each file AND column of the list swift command
# so we need a column counter. Column 0 is size and column 3 is name. 
# Column 1 and 2 are date and hour, we do not need it
column=0
# For all files in the designated distant folder
for line in `~/hubic/hubic.py --swift -- list default -p sync_backups/${foldername}/ -l`;
do
	if [ ${column} -eq 0 ]
	then
		size_remote=${line}
	elif [ ${column} -eq 3 ]
	then
		filename=${line}
		# Get the file name without the date, to be the index of the array
		echo filename : ${filename}
		filenamewodate=${filename::-27}
		# The date, to compare with another instance of the file
		date_tmp=${filename: -26}
		date=${date_tmp::-11}

		# Is there this file in the array already ?
		if [ ${FILES[${filenamewodate}]+_} ];
		then
			value=${FILES[${filenamewodate}]}
			# Date of the file in the array
			prev_date=${value:0:15}
			# Is the current file more recent ?
			if [ ${date//_} -gt ${prev_date//_} ]
			then
				# The current file is more recent, we keep it
				echo This file has a newer version existing and will not be downloaded : ${filenamewodate}_${prev_date}.tar.gz.gpg
				FILES[${filenamewodate}]=${date}_${size_remote}
			else
				echo This file has a newer version existing and will not be downloaded : ${filename}
			fi
		else
			# NO other file in the array, we keep it
			#echo File ${filenamewodate} added to the list
			FILES[${filenamewodate}]=${date}_${size_remote}
		fi
	fi
	column=$(((column+1)%4));
done

#number of values
#echo number of values : ${#FILES[@]}
#calculer le nombre total de dl à faire

for filenamewodate in "${!FILES[@]}";
do
	value=${FILES[${filenamewodate}]}
	gpg_file_path=${filenamewodate}_${value:0:15}.tar.gz.gpg
	size_remote=${value:16}

	# Sometimes the for loop goes crazy, i do not know why, yet. So, little check
	if [[ ${gpg_file_path} != *"${foldername}"* ]]
	then
		echo `date +%Y%m%d\ %H:%M:%S` : ERROR Wrong file : ${gpg_file_path}	
		continue
	fi
	
	echo `date +%Y%m%d\ %H:%M:%S` : The file has a size of ${size_remote=} : ${gpg_file_path}
	# If file already exists AND local file size equals distant file size
	if test -f "${gpg_file_path}" && test "${size_remote}" -eq "$(du -b "${gpg_file_path}" | cut -f 1)"
	then
		echo `date +%Y%m%d\ %H:%M:%S` : The file has already been succesfully downloaded : ${gpg_file_path}
		continue
	fi
	# If file already exists AND local file size NOT equals distant file size
	if test -f "${gpg_file_path}" && test "${size_remote}" -ne "$(du -b "${gpg_file_path}" | cut -f 1)"	
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
	if [ "${size_remote}" -ne "${actualsize}" ]
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
	tar -xzvf --no-overwrite-dir ${gpg_file_path::-4}

	# Deletion of the file
	rm -f ${gpg_file_path::-4} 
done 

echo `date +%Y%m%d\ %H:%M:%S` : Comparison between original folder and downloaded backup
echo ------------------------------------------------------------
echo ------------------------------------------------------------
echo ---------------------- COMPARISON --------------------------
echo ------------------------------------------------------------
echo ------------------------------------------------------------
# Comparison between the original folder backupdir and the backup
diff -r .${backupdir} ${backupdir}

#TODO deletion of the folder.${backupdir}

echo `date +%Y%m%d\ %H:%M:%S` : End of script
