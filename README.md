# SDRPP Server AMD64 Docker Image
This project implements a dockerized sdrpp server built for AMD64.
- SDRplay API 3.15.2 is included.
- RTL-SDR is included.
- SDRPP Releases Nightly Builds is the source for SDRPP.
## Notes:
- The final install image is built on debian
 - There is a Dockerfile.alpaquita that used Alpaquita as a base image instead of debian.
   but the Alpaquita version is unmaintained.
- The sdrpp configs directory can be shared as a volume or a default set is supplied.
Be aware that the default may not be what you desire.  sdrpp-server will not run properly
without a good set of configuration files.  Also, it is best to have a local volume path
because settings are saved in the .json files and will be available through GUI stop/start.
- Be sure to make any usb devices read/write for all uses on the docker host.
- SDR Play has updated the API to 3.15.2 and changes the location of the api files which
can break the Dockerfile.  Consider downloading the API manually and using a copy command
instead of add in the API download line. 
## Usage:
I generally run this with a docker compose file:
```
name: sdrpp-server
services:
  sdrpp-server:
    container_name: sdrpp-server
    image: dgadams/sdrpp-server
    restart: unless-stopped
    init: true
    devices:
      - /dev/bus/usb
    ports:
      - 5259:5259
    volumes:
      - /home/doug/.sdr++:/sdrpp/conf.d
    extra_hosts:
      - "host.docker.internal:host-gateway"
    healthcheck:
      test: timeout 2 nc host.docker.internal 5259 || [ $$? -eq 143 ]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 20s
      
```
## Ackowledgements
- The SDRplay API is provided by sdrplay at https://sdrplay.com.
Check out their hardware and software options.
The SDRplay API is licensed software.  See the terms at sdrplay.com
- Thanks to Alexandre Roma for creating sdrpp.
- SDR++ website:  https://www.sdrpp.org
