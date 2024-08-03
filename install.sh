#!/bin/sh

echo "Installing tsu pakckage if not present."

pkg update 

pkg upgrade -y

pkg install tsu -y

sudo chmod +x ./main.sh

clear

su -c "./main.sh '$HOME'"


