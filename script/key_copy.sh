#!/bin/bash
filename=$1
while read line; do
# reading each line
    if [[ $line =~ ^\[ ]]; then
        action=$(echo $line |tail -c +2 | head -c -2)
    else
        #echo "Action=$action"
        sshpass -p "alo1234" ssh-copy-id -f -i ~/.ssh/id_rsa.pub -o StrictHostKeyChecking=no root@$line
    fi
done < $filename