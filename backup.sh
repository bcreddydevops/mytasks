#!/bin/bash

##########################################################################################
#
# Function    : usage
# Description : explains usage of the script
#
##########################################################################################

usage (){
cat <<EOF

This script downloads artifacts from nexus to artifact_download folder.

Snapshot Repository : https://nexusrepo.abcd.com/content/repositories/CRTSnapshots/
Release Repository  : https://nexusrepo.abcd.com/content/repositories/CRTReleases/

usge : $0 artifact_type version service1,service2, ... ,serviceN

      artifact_type : Artifact type must be either snapshot or release
      version       : Version of artifact
      services      : Multple services files can be given as input (seperated by comma)
                      Name of services :-
			                  crtadmin-servicefacade
			                  crtrevamp-crtclaim
			                  crtrevamp-crtcustomer
			                  crtrevamp-crtec

EOF
exit 1

}

nexus_username="abcd"
nexus_password="xxxxxx"
type=$1
version=$2
services=$(echo $3 | tr ',' ' ')
script_dir=$(pwd)
tmp_dir=$script_dir/downloads
user=$(whoami)
crt_root=/ngs/app/$user/CRTREVAMP
tmp_dir=$script_dir/downloads

if [ $# -lt 3 ]; then
  usage
fi

##########################################################################################
#
# Function    : print_message
# Description : Prints the input text in a fomrat
#
##########################################################################################

print_message(){
cat << EOF
*******************************************************************************************************
$@
*******************************************************************************************************
EOF
}

##########################################################################################
#
# Function    : rename_war_file
# Description : Renames the downloaded war file according to the service name
#
##########################################################################################

rename_war_file(){
service_name=$1
file=$2

if [ $service_name == "crtadmin-servicefacade" ]; then
		mv $file admin.war
	elif [[ $service_name == "crtrevamp-crtclaim" ]]; then
		mv $file claim.war
	elif [[ $service_name == "crtrevamp-crtcustomer" ]]; then
		mv $file customer.war
	elif [[ $service_name == "crtrevamp-crtec" ]]; then
		mv $file ec.war
	else
		echo "service name dont match!! exit!!"
		usage
fi
}

##########################################################################################
#
# Function    : usage
# Description : This function runs shell script inside script folder. Name of
#               function is given as the first input
#
##########################################################################################

run_script(){
cd $script_dir
chmod +x $1
./$1
}

##########################################################################################
#
# Function    : download_artifacts
# Description : This function downloads artifacts from nexus repo into a downloads folder.
#		According to artifact type,creates corresponding nexus url and downloads
#		the war files. Also prints out the MD5sum values at the end
#
##########################################################################################

download_artifacts(){
print_message Creating downloads folder
 if [ -d ${tmp_dir} ]; then
	rm -rf ${tmp_dir}
 fi
mkdir ${tmp_dir}  && cd ${tmp_dir}

#Downloading files from Nexus
for val in $(echo $services);do
 if [ $type == "snapshot" ];then
	#getting latest snapshot timestamp and buildnumber
	meta_data_url="https://nexusrepo.abcd.com/content/repositories/CRTSnapshots/com/abcd/ist/crtrevamp/$val/$version-SNAPSHOT/maven-metadata.xml"
	wget --user=${nexus_username} --password=${nexus_password} $meta_data_url
	timestamp=$(cat maven-metadata.xml | grep timestamp | cut -d ">" -f2 | cut -d "<" -f1)
	buildnumber=$(cat maven-metadata.xml | grep buildNumber | cut -d ">" -f2 | cut -d "<" -f1)
	rm -rf maven-metadata.xml
	file_name=${val}-${version}-${timestamp}-${buildnumber}.war
	nexus_url="https://nexusrepo.abcd.com/content/repositories/CRTSnapshots/com/abcd/ist/crtrevamp/$val/$version-SNAPSHOT/$file_name"
 elif [ $type == "release" ];then
 	file_name=${val}-${version}.war
	nexus_url="https://nexusrepo.abcd.com/content/repositories/CRTReleases/com/abcd/ist/crtrevamp/$val/$version/$file_name"
 else
 	print_message Invalid artifact type. It must be snapshot or release !!
	usage
 fi
 print_message Downloading $nexus_url
 wget --user=${nexus_username} --password=${nexus_password} $nexus_url
if [ $? != 0 ]; then
   print_message Download Failed!! Exiting from Script!!
   usage
else
	print_message Downloading of $file_name successfull
fi
rename_war_file $val $file_name

done

print_message $'MD5Sum values of Downloaded Artifacts\n'
md5sum *
echo "*******************************************************************************************************"
}

##########################################################################################
#
# Function    : copy_artifacts
# Description : This function copies the downloaded artifacts from downloades folder to
#		CRTREVAMP folder. First it creates a backup of files inside CRTREVAMP
#		and then copies the war files.
#
##########################################################################################

copy_artifacts(){
if [ ! -d $crt_root ]; then
  	mkdir $crt_root
fi
cd $crt_root
#creating backup
tmstmp=$(date '+%Y%m%d.%H%M%S')
print_message Creating backup ${crt_root}/backup_${tmstmp}
mkdir backup_$tmstmp
cp *.war backup_${tmstmp}/
tar cvf backup_${tmstmp}.tar backup_$tmstmp && rm -rf backup_$tmstmp && mv backup_${tmstmp}.tar backup/
print_message Copying artifacts from ${tmp_dir} to $crt_root
cp -r ${tmp_dir}/*.war .

}

##########################################################################################
#
#  This is the Main area where script starts
#
##########################################################################################

download_artifacts
print_message Stopping Services
run_script stopService.sh
copy_artifacts
print_message Starting Services
run_script startService.sh

########## Script End ##########
