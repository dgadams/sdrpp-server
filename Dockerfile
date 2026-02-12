# Dockerfile to build sdrplay and sdrpp server.
# Based on an excellent example from github f4fhh/sdrppserver_container.
# SDRplay API is pulled from sdrplay website
# sdrpp is pulled from github sdrpp nightly releases.
# Thanks to sdrplay and Alexandre Rouma for making this possible.
#
# D. G. Adams
# 2025-12-05  Merged muntz.sh into Dockerfile

FROM debian:trixie-slim AS dga-build

# Get and run SDRplay API installer
WORKDIR /sdrplay
ADD https://www.sdrplay.com/software/SDRplay_RSP_API-Linux-3.15.1.run ./SDRplay.run

RUN <<ENDRUN
    chmod +x SDRplay.run
    ./SDRplay.run --tar -xvf
    chmod 644 x86_64/libsdrplay_api.so.3.15     #library
    chmod 755 x86_64/sdrplay_apiService         #binary
ENDRUN
# sdrplay libs and binaries are in /sdrplay/x86_64

# install sdrpp
#ADD "https://github.com/AlexandreRouma/SDRPlusPlus/releases/download/nightly/sdrpp_debian_bookworm_amd64.deb" ./sdrpp.deb
ADD "https://github.com/AlexandreRouma/SDRPlusPlus/releases/download/nightly/sdrpp_debian_trixie_amd64.deb" ./sdrpp.deb
RUN <<ENDRUN
    apt-get update
    apt-get -y install ./sdrpp.deb rtl-sdr libusb-1.0-0 libglfw3 busybox
ENDRUN
# sdrpp is installed in /usr/bin/sdrpp
# libraries are in /lib/libsdrpp_core* and /lib/sdrpp

# Move libraries to x86_64-linux-gnu
WORKDIR /lib/x86_64-linux-gnu/
RUN <<EOR
    cp -a /sdrplay/x86_64/libsdrplay_api* .
    ln -s libsdrplay_api.so.3.15 libsdrplay_api.so.3
    cp -a /usr/lib/libsdrpp_core.* .
    rm *.a
EOR

######################################################
# Build our filesystem. Using a new layer removes potential junk.
# copy all files from dga-build.
# Then run the muntzing process to remove unneeded files
# and last, install busybox.

FROM debian:trixie-slim AS dga-filesystem

COPY --from=dga-build /usr/lib/sdrpp /lib/sdrpp/
COPY --from=dga-build /usr/lib/x86_64-linux-gnu/ /usr/lib/x86_64-linux-gnu/
COPY --from=dga-build /usr/bin/sdrpp /sdrpp/
COPY --from=dga-build /sdrplay/x86_64/sdrplay_apiService /sdrpp/
COPY --from=dga-build /usr/bin/busybox /usr/bin/
COPY files/ /sdrpp

RUN <<EOR
#!/bin/bash
    shopt -s extglob # bash extenstion for rm -rf !(execept_files|...)

#   remove all libraries except ...
    cd /usr/lib/x86_64-linux-gnu
    EXC="!(libc.*|ld-linux*"
    EXC+="|libsdrplay_api.so.*|libsdrpp_core.*|libresolv.*"
    EXC+="|libOpenGL.*|libfftw3f.*|libvolk*|libzstd.*|libm.*"
    EXC+="|libdl.*|libX11.so.*|libpthread.*|libGLdispatch.*"
    EXC+="|liborc-0.4.*|libxcb.*|libXau.*|libXdmcp.*|libbsd.*"
    EXC+="|libmd.*|librtlsdr.*|libusb*|libstdc++*|libselinux*"
    EXC+="|libudev*|libgcc_s*|librt*|libglfw.*"
    EXC+="|libGL.so.*|libGLX.so.*|libcap.so.*)"
    rm -rf $EXC

#   remove anything not needed in the container
    cd /            && rm -rf !(bin|dev|etc|lib|lib64|proc|run|sbin|sdrpp|sys|usr)
    cd /etc         && rm -rf !(passwd|group|gshadow|shadow)
    cd /usr         && rm -rf !(lib|bin|sbin|lib64)
    cd /usr/lib     && rm -rf !(x86_64-linux-gnu|sdrpp)
    cd /usr/sbin    && rm *
    cd /usr/bin     && rm !(busybox|bash)   # Must be last

    /bin/busybox --install -s
    rm /bin/bash
EOR

#####################################################################
#   Ready for scratch.  We use scratch to keep deleted space out of
#   the install layer. Saves almost 500 MB.
#	Libraries are in /usr/lib/x86_64-linux-gnu
#	binaries and config files are in /sdrpp

FROM scratch AS install
COPY --from=dga-filesystem / /
EXPOSE 5259
WORKDIR /sdrpp
USER nobody
CMD ["/sdrpp/sdrpp.sh" ]
