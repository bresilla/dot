#!/bin/bash

# Default to Ubuntu 24.04
version="ubuntu2404"

# Get Ubuntu version from /etc/os-release
. /etc/os-release

# Check for Ubuntu 22.04
if [ "$VERSION_ID" = "22.04" ]; then
    version="ubuntu2204"
fi

echo "Detected Ubuntu version: $VERSION_ID, using package version: $version"

wget https://developer.download.nvidia.com/compute/cuda/repos/$version/x86_64/cuda-$version.pin
sudo mv cuda-$version.pin /etc/apt/preferences.d/cuda-repository-pin-600


# wget https://developer.download.nvidia.com/compute/cuda/12.9.1/local_installers/cuda-repo-$version-12-9-local_12.9.1-575.57.08-1_amd64.deb
# sudo dpkg -i cuda-repo-$version-12-9-local_12.9.1-575.57.08-1_amd64.deb
# sudo cp /var/cuda-repo-$version-12-9-local/cuda-*-keyring.gpg /usr/share/keyrings/

# wget https://developer.download.nvidia.com/compute/cudnn/9.10.2/local_installers/cudnn-local-repo-$version-9.10.2_1.0-1_amd64.deb
# sudo dpkg -i cudnn-local-repo-$version-9.10.2_1.0-1_amd64.deb
# sudo cp /var/cudnn-local-repo-$version-9.10.2/cudnn-*-keyring.gpg /usr/share/keyrings/

# sudo apt-get update
# sudo apt-get -y install cuda-toolkit-12-9
# sudo apt-get -y install cudnn-cuda-12


wget https://developer.download.nvidia.com/compute/cuda/13.0.1/local_installers/cuda-repo-ubuntu2404-13-0-local_13.0.1-580.82.07-1_amd64.deb
sudo dpkg -i cuda-repo-ubuntu2404-13-0-local_13.0.1-580.82.07-1_amd64.deb
sudo cp /var/cuda-repo-ubuntu2404-13-0-local/cuda-*-keyring.gpg /usr/share/keyrings/

wget https://developer.download.nvidia.com/compute/cudnn/9.13.0/local_installers/cudnn-local-repo-ubuntu2404-9.13.0_1.0-1_amd64.deb
sudo dpkg -i cudnn-local-repo-ubuntu2404-9.13.0_1.0-1_amd64.deb
sudo cp /var/cudnn-local-repo-ubuntu2404-9.13.0/cudnn-*-keyring.gpg /usr/share/keyrings/

sudo apt-get update
sudo apt-get -y install cuda-toolkit-13-0
sudo apt-get -y install cudnn9-cuda-13

