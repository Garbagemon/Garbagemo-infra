#!/bin/bash

export PATH="/root/.nvm/versions/node/v16.20.1/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/root/bin"
echo "Using PATH='$PATH'"

PM2_PROCESS_NAME="express-garbagemon-backend"

echo "------------------------------------------------------------------------"
echo "PM2_PROCESS_NAME=$PM2_PROCESS_NAME"
date

cd /home/ec2-user/Garbagemon-backend/
git fetch origin main || echo  "fetch-fail"
git reset --hard FETCH_HEAD || echo "reset fail"
npm i || echo "npm install failure"

pm2 stop "$PM2_PROCESS_NAME"  || echo "pm2 stop failure"
systemctl start nginx || echo "nginx start failure"

pm2 start npm --name "$PM2_PROCESS_NAME" -- start || echo "pm2 start process failure"

date
echo "------------------------------------------------------------------------"