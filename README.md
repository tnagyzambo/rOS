# rocketOS

Detailed notes and build instructions can be found on [GitHub Pages](https://tnagyzambo.github.io/rocketOS/rocketOS.html).

Build:

`docker build . -f rocketOS.Dockerfile -t rocketos --build-arg RPI_VERSION=4` 

Run:

`docker run --rm --privileged -v /dev:/dev -v ${PWD}:/build -v ${PWD}:/rocketOS.pkr.hcl -i rocketos:latest`

Configuration flags:

`-e PKR_VAR_user=`

`-e PKR_VAR_password=`

`-e PKR_VAR_hostname=`
