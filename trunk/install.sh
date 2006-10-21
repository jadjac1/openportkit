#!/bin/bash
sudo rm -rf /Library/Frameworks/OpenPort.framework
sudo cp -pR build/Debug/OpenPort.framework /Library/Frameworks
sudo cp net.sunburstweb.openpmp.plist /Library/LaunchDaemons
