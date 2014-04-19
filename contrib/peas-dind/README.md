#Dockerfile

##Running
Once you have installed Docker, install the Peas image with: `docker pull tombh/peas-dind`.

Because Peas creates Docker containers inside a parent Docker container you must remember to always
provide the `--privileged` flag when running Docker commands. To run the Peas container:
`docker run --privileged -p 4000:4000 -i peas-dind`
If you would like to hack on the codebase whilst it's running in the container you can mount your
code into the container:
`docker run --privileged -v [path to peas codebase on host machine]:/home/peas -p 4000:4000 -i peas-dind`

##Building
Because Peas itself creates Docker containers, then running Peas in Docker means runnning Docker
inside Docker. Luckily this is possible using the simple tweaks provided by @jpetazzo's
[DinD scripts](https://github.com/jpetazzo/dind).

However, there is one caveat; the parent Docker container requires '--privileged' permissions, which
is a flag that cannot be set in a Dockerfile. What this means is that a crucial step in the
building of the Peas image, namely installing the `progrium/buildstep` image, cannot be done with a
Dockerfile. So the build requires 2 steps, firstly building the Dockerfile and then manually adding
Buildstep and commiting the final container.

This process is conveniently managed in `build.sh`. So to build the Peas image, simply issue:
`./build.sh`
