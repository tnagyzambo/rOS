# rOS

Detailed notes and build instructions can be found on [GitHub Pages](https://tnagyzambo.github.io/rOS/rOS.html).

Build:

`docker build . -f rOS.Dockerfile -t r_os --build-arg RPI_VERSION=4` 

Run:

`docker run --rm --privileged -v /dev:/dev -v ${PWD}:/build -v ${PWD}:/rOS.pkr.hcl -i r_os:latest`

Configuration flags:

`-e PKR_VAR_user=`

`-e PKR_VAR_password=`

`-e PKR_VAR_hostname=`
