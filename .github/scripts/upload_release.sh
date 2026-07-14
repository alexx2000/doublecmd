#!/bin/bash

function finish {
  echo "Upload exit"
  rm -f ssh_key upload_release.txt
}

trap finish EXIT

echo "$SSH_PRIVATE_KEY" > ssh_key
chmod 0600 ssh_key

echo "cd /home/frs/project/doublecmd" > upload_release.txt
echo "-mkdir $TAG" >> upload_release.txt
echo "cd $TAG" >> upload_release.txt
echo "put *" >> upload_release.txt
echo "quit" >> upload_release.txt

sftp -o StrictHostKeyChecking=no -i ssh_key -b upload_release.txt $REMOTE_USER@$REMOTE_HOST
