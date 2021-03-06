#!/bin/bash

#
# Xerox Watchman script version 0.7
# Script clears out the bad ppd code from the Xerox drivers.
#

Clear_JobPatch ()
{
Path="$1"

echo "Entering loop to fix the PPD files" >> $LogFile

cat /tmp/temp.txt | ( while read DriverNm;
     do
	echo $DriverNm

# Remove the JobPatchFile 1 line, this causes the print job to appear as US Letter
	grep -v "JobPatchFile 1" "${Path}${DriverNm}" > "${Path}${DriverNm}".tmp
	echo done the first fix

# Remove the reporting commands, this delays printing as we go through a server not direct IP
	sed -e s/ReportLevels//g -e s/ReportStatus//g "${Path}${DriverNm}".tmp > "${Path}${DriverNm}"
	echo done the second fix ${DriverNm}

# Clean up the tmp file
	rm -f "${Path}${DriverNm}".tmp

done)
}


Xerox_Watch ()
{
# The drivers could be updating at the moment so go to sleep to allow any update to complete.
sleep 20

# Fix any printers first, as we use printer status as a test to see if modification is required
Path="/private/etc/cups/ppd/"
# create the file with list of printers
ls "$Path" | grep -v '^[.*]' > /tmp/temp.txt
Clear_JobPatch "${Path}"
# Clear the file
rm -f /tmp/temp.txt


# Fix the drivers Xerox ship
Path="/Library/Printers/PPDs/Contents/Resources/"

# Create the file with list of Xerox drivers
ls $Path | grep "Xerox" | grep ".gz" > /tmp/temp.txt 

cat /tmp/temp.txt | ( while read ppd;
do
# Unzip each driver
gunzip -vf "${Path}${ppd}"
done)

# Clean up the ppd file
ls $Path | grep "Xerox" | grep -v ".gz" > /tmp/temp.txt 

Clear_JobPatch "${Path}"

cat /tmp/temp.txt | ( while read ppd;
do
# Gzip each driver
gzip -vf "${Path}${ppd}"
done)
# Clear the file
rm -f /tmp/temp.txt
}


GZ_Driver_Cleanup ()
{
# Check if the drivers are actually ok...
Path="/Library/Printers/PPDs/Contents/Resources/"

ls $Path | grep "Xerox" | grep -v ".gz" > /tmp/DriverTest.txt 

cat /tmp/DriverTest.txt | ( while read PPD;
do
echo $PPD
TestGZ=`gzip -t "${Path}${PPD}.gz" 2>&1`

if ! [ -z "${TestGZ}" ]
then
	rm -f "${Path}${PPD}.gz"
	gzip -vf "${Path}${PPD}"
else
	rm -f "${Path}${PPD}"
fi
done)

rm -f /tmp/DriverTest.txt 
}


LogFile="/Library/Logs/Xerox-Watchman.log"
date > $LogFile

# Check to make sure script isn't running already
ps | grep -w "[X]eroxWatchman.sh"  > /var/tmp/XeroxWatchman.sh.pid
echo "Creating the lock file" >> $LogFile

pids=$(cat /var/tmp/XeroxWatchman.sh.pid | cut -d ' ' -f 1)
for pid in $pids
do
   if [ $pid -ne $$ ]; then
    echo "[`date`] : XeroxWatchman.sh : Process is already running"
    exit 1;
   fi
done

# Find out if the driver files need to be fixed
AllPrinters=$(ls /private/etc/cups/ppd)

for ppd in $AllPrinters
do
# Use grep -l for simplicity, if what we are looking for is found it returns the file name
XeroxQ=`grep -l "Xerox" /private/etc/cups/ppd/$ppd | awk -F "/" '{print $6}'`

if [ "${XeroxQ}" == "${ppd}" ]
then
	# This queue uses the Xerox driver.
	BadFile=`grep -l "JobPatchFile 1" /private/etc/cups/ppd/$ppd | awk -F "/" '{print $6}'`
	if [ "${BadFile}" == "${ppd}" ]
	then
		# This queue has a JobPatchFile 1 line.
		Xerox_Watch
	else
		echo "No action taken, drivers are correct - no JobPatchFile 1 line."  >> $LogFile
	fi
fi

done

# Sort out any driver issues with uncompressed files and corrupt .gzs.
GZ_Driver_Cleanup 

echo "Deleting the lock file" >> $LogFile

rm -f /var/tmp/XeroxWatchman.sh.pid

exit 0;
