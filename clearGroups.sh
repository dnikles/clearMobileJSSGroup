#!/bin/bash
source ./getCreds.sh
getCreds

groups=$(curl -H "Accept: application/json" -su ${jssAPIUsername}:${jssAPIPassword} -X GET ${jssAddress}/JSSResource/mobiledevicegroups)

staticCount=$(echo $groups|./jq '.mobile_device_groups[]|select(.is_smart==false)|{}' | wc -l)

staticNames=$(echo $groups|./jq  '.mobile_device_groups[]|select(.is_smart==false)|.name')
newName="${staticNames:1}" # trim first quote
newName="${newName%?}" # trim last quote
i=0
groupOption=""
newLine=$'\n'
while [ $i -lt $staticCount ]; do
  (( i++ ))
  tempName=$(echo $newName | awk -F '" "' -v j=$i '{print $j}')
  groupOption="$groupOption groupSelection.option = $tempName\n"

done
groupOption=$(echo -e $groupOption)
conf="
*.title = Group Selection
*.floating = 1
groupSelection.type = popup
groupSelection.label = Pick a group to remove all of it's members
${groupOption}
# Add a cancel button with default label
cb.type = cancelbutton
"
#run pashua, get the asset tag
pashua_run "$conf"


#if cancel, exit
[ "$cb" -eq 1 ] && exit 1


groupID=$(echo $groups|./jq --arg v "$groupSelection" '.mobile_device_groups[]|select(.name==$v).id')
devices=$(curl -H "Accept: application/json" -su ${jssAPIUsername}:${jssAPIPassword} -X GET ${jssAddress}/JSSResource/mobiledevicegroups/id/$groupID)
deviceCount=$(echo $devices|./jq '.mobile_device_group.mobile_devices|length')

deviceIDs=$(echo $devices|./jq '.mobile_device_group.mobile_devices[].id')

conf="
*.title = Warning!
*.float = 1
txt.type = text
txt.default = Are you sure you want to remove $deviceCount devices from $groupSelection?
# Add a cancel button with default label
cb.type = cancelbutton
db.type = defaultbutton
db.label = Delete
"
pashua_run "$conf"
if [ "$db" == "1" ]
  then
    i=0
    apiDeletions=""
    while [ $i -lt $deviceCount ]; do
      (( i++ ))
      tempDevice=$(echo $deviceIDs | awk -v j=$i '{print $j}')
      apiDeletions="$apiDeletions<mobile_device><id>$tempDevice</id></mobile_device>"

  done

    apiData="<mobile_device_group><mobile_device_deletions>$apiDeletions</mobile_device_deletions></mobile_device_group>"
    output=$(curl -sS -k -i -u ${jssAPIUsername}:${jssAPIPassword} -X PUT -H "Content-Type: text/xml" -d "<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?>$apiData" ${jssAddress}/JSSResource/mobiledevicegroups/id/$groupID)
    echo $output

fi
