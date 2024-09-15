# SDRPP Server AMD64 Docker Image
This image contains a dockerized sdrpp server built for AMD64.
- SDRplay API 3.15 is included.
- RTL-SDR is included.
- SDRPP Releases Nightly Builds is the source for SDRPP.
## Notes:
- The final install image is built on alpaquita a derivative of alpine linux using 
the glibc libraries.
- The sdrpp configs directory can be shared as a volume or a default set is supplied.  
Be aware that the default may not be what you desire.  sdrpp-server will not run properly
without a good set of configuration files.
## Usage:
I generally run this with a docker compose file:
```
# sdrpp server
# server to allow sdrpp connections to sdrplay and rtl-sdr devices
#
# D. G. Adams 2024-Aug-18
#
name: sdrppserver
services:
  sdrppserver:
    container_name: sdrpp-server
    image: sdrpp-server
    restart: unless-stopped
    init: true
    devices:
      - /dev/bus/usb
    ports:
      - 5259:5259
    volumes:
      - /home/doug/servers/conf.sdrpp:/sdrpp/conf.d
#     Be sure to edit the config file directory to point to your own
#     If no volume is specified a default set of configs for sdrpp
#     will be used.  See sdrpp documentation for more details.
```
