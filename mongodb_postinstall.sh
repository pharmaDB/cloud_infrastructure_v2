#!/usr/bin/env bash

###############################################################################
#
# This file contains a post install script to be used with terraform deployment
# of a MongoDB database on an Ubuntu20 machine. The script will install Docker 
# and all its dependencies, pull the Docker container for the pharmaDB backend
# infrastructure from Docker Hub, and run the pulled Docker image. For
# additional information on the underlying infrastructure, see the .tf
# terraform files in this repository.
#
# @author Anthony Mancini
# @version 2.0.0
# @license GNU GPLv3 or later
#
###############################################################################

###############################################################################
#
# Updating the Ubuntu20 machine and upgrading all packages to the latest
# version.
#
###############################################################################

# Updating the package repo on the newly installed machine
sudo apt update -y

# Upgrading existing programs to the latest versions
sudo apt upgrade -y

# Updating the package repo using apt-get after all of the upgrades
sudo apt-get update


###############################################################################
#
# Installing all dependencies needed to run the monthly cron process, cloning
# all of the repositories from the pharmaDB repo, and adding code to the cron
# file to run the monthly update processes.
#
###############################################################################

# Installing the dependencies needed to run the patent code
sudo apt-get install -y git
sudo apt-get install -y nodejs
sudo apt-get install -y npm

# Downloading the patent code from the github repository
git clone https://github.com/pharmaDB/uspto_bulk_file_processor_v4.git

# Installing all of the packages from NPM to run the patent code
sudo npm --prefix "/home/ubuntu/uspto_bulk_file_processor_v4" install

# Compiling the patent project from the source code
sudo npm --prefix "/home/ubuntu/uspto_bulk_file_processor_v4" run build

# Adding the monthly patent refresh code to the cron script
echo '0 0 1 * * node /home/ubuntu/uspto_bulk_file_processor_v4/out/index.js --patent-number-file "patents.json" --start-date "$(date +"%Y-%m-01" -d "-1 month")" --end-date "$(date +"%Y-%m-01")"'  | sudo tee /etc/cron.d/monthly_patent_refresh > /dev/null


###############################################################################
#
# Installing all dependencies needed to run the Docker container, downloading
# the Docker container from Docker Hub, and running the container through the
# Docker daemon
#
###############################################################################

# Installing docker dependencies
sudo apt-get install -y apt-transport-https
sudo apt-get install -y ca-certificates
sudo apt-get install -y curl
sudo apt-get install -y gnupg

# Fetching Docker's GPG key and adding it to the GPG keyring
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Setting up the Docker repository and adding it to the sources list
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Updating the repository and installing Docker and all dependencies
sudo apt-get update
sudo apt-get install -y docker-ce
sudo apt-get install -y docker-ce-cli
sudo apt-get install -y containerd.io

# Pulling the MongoDB container from Docker Hub
sudo docker pull mongo

# Running MongoDB 4.4 on ports 27017-27019
sudo docker run \
    -p 27017-27019:27017-27019 \
    --name mongodb \
    -d mongo:4.4


###############################################################################
#
# Running all of the post installation code used to build the MongoDB database
# for the pharmaDB project.
#
###############################################################################

# Running the patent code with no date parameters to build the entire patent
# database on the first installation of the Ubuntu20 machine
node /home/ubuntu/uspto_bulk_file_processor_v4/out/index.js \
    --patent-number-file "patents.json"
