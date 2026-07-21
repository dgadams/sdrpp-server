# SDRPP Server AMD64 Docker Image
This project implements a dockerized sdrpp server built for AMD64.
- SDRplay API 3.15 is included.
- RTL-SDR is included.
- SDRPP Releases Nightly Builds is the source for SDRPP.
## Notes:
- The final install image is built on debian
 - There is a Dockerfile.alpaquita that used Alpaquita as a base image instead of debian.
   but the Alpaquita version is unmaintained.
- The sdrpp configs directory can be shared as a volume or a default set is supplied.
Be aware that the default may not be what you desire.  sdrpp-server will not run properly
without a good set of configuration files.
- Build this with "docker build -t sdrpp-server ."
## Usage:
I generally run this with a docker compose file:
```
# sdrpp server
# server to allow sdrpp connections to sdrplay and rtl-sdr devices
#
# D. G. Adams 2025-03-12
# The SDRplay devices need USB read/write permissions.
# Add: SUBSYSTEMS=="usb", ATTRS{idVendor}=="1df7", MODE="0666"
# to a file in the docker host /etc/udev/rules.d to allow read/write access.

name: sdrppserver
services:
  sdrppserver:
    container_name: sdrpp-server
    image: dgadams/sdrpp-server
    restart: unless-stopped
    init: true
    devices:
      - /dev/bus/usb
    ports:
      - 5259:5259

#     Be sure to edit the config file directory to point to your own.
#     If you don't have your own directory just comment out the volumes section.
#     If no volume is specified a default set of configs for sdrpp
#     will be used.  See sdrpp documentation for more details.

    volumes:
      - /home/doug/servers/conf.sdrpp:/sdrpp/conf.d
```
## Ackowledgements
- The SDRplay API is provided by sdrplay at https://sdrplay.com.
Check out their hardware and software options.
The SDRplay API is licensed software.  See the terms at sdrplay.com
- Thanks to Alexandre Roma for creating sdrpp.
- SDR++ website:  https://www.sdrpp.org
