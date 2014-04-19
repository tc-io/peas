#! /bin/bash
set -e

# cd ../.. && docker build -t peas-dind .
echo "Pulling progrium/buildstep, this can take a while..."
ID=$(docker run --privileged -d -e INSTALL_BUILDSTEP=true peas-dind /home/peas/contrib/peas-dind/wrapdocker)
test $(docker wait $ID) -eq 0
docker commit $ID peas-dind
