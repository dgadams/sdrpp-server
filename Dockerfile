# Dockerfile to build sdrplay and sdrpp server.
# Based on an excellent example from github f4fhh/sdrppserver_container.
# SDRplay API is pulled from sdrplay website
# sdrpp is pulled from github sdrpp nightly releases.
# Thanks to sdrplay and Alexandre Rouma for making this possible.
#
# D. G. Adams
# 2024-Sep-15

FROM debian:bookworm-slim AS build

# Get and run SDRplay API installer
WORKDIR /sdrplay
ADD https://www.sdrplay.com/software/SDRplay_RSP_API-Linux-3.15.1.run ./SDRplay.run

RUN <<ENDRUN
    chmod +x SDRplay.run
    ./SDRplay.run --tar -xvf
    chmod 644 x86_64/libsdrplay_api.so.3.15
    chmod 755 x86_64/sdrplay_apiService
ENDRUN

# install sdrpp
ADD "https://github.com/AlexandreRouma/SDRPlusPlus/releases/download/nightly/sdrpp_debian_bookworm_amd64.deb" ./sdrpp.deb

RUN <<ENDRUN
    apt-get update
    apt-get -y install ./sdrpp.deb rtl-sdr libusb-1.0-0
    cp /sdrplay/x86_64/sdrplay_apiService /usr/local/bin/sdrplay_apiService
    cp /usr/bin/sdrpp /usr/local/bin
ENDRUN

#   copy all needed libraries.  Kind of a reverse muntzing - add until it quits whinning.
WORKDIR /base/usr/lib
RUN <<ENDRUN
    mv /lib/sdrpp .
    while read p; do
        cp $p .
    done <<ENDLIST
        /lib/x86_64-linux-gnu/libglfw.so.3
        /lib/x86_64-linux-gnu/libOpenGL.so.0
        /lib/x86_64-linux-gnu/libfftw3f.so.3
        /lib/x86_64-linux-gnu/libvolk.so.2.5
        /lib/x86_64-linux-gnu/libzstd.so.1
        /lib/x86_64-linux-gnu/libm.so.6
        /lib/x86_64-linux-gnu/libdl.so.2
        /lib/x86_64-linux-gnu/libX11.so.6
        /lib/x86_64-linux-gnu/libpthread.so.0
        /lib/x86_64-linux-gnu/libGLdispatch.so.0
        /lib/x86_64-linux-gnu/liborc-0.4.so.0
        /lib/x86_64-linux-gnu/libxcb.so.1
        /lib/x86_64-linux-gnu/libXau.so.6
        /lib/x86_64-linux-gnu/libXdmcp.so.6
        /lib/x86_64-linux-gnu/libbsd.so.0
        /lib/x86_64-linux-gnu/libmd.so.0
        /lib/x86_64-linux-gnu/librtlsdr.so.0
        /usr/lib/libsdrpp_core.so
        /sdrplay/x86_64/libsdrplay_api*
ENDLIST
ENDRUN

# grab files  and move binaries
WORKDIR /base/sdrpp
COPY sdrpp.conf.d ./conf.d
COPY sdrpp.sh .
RUN cp /usr/local/bin/* .
######################################################

FROM bellsoft/alpaquita-linux-base:stream-glibc AS install

WORKDIR /sdrpp
COPY --from=build /base /
RUN apk --no-cache add libstdc++ libusb
EXPOSE 5259
USER nobody
CMD ["/sdrpp/sdrpp.sh" ]
