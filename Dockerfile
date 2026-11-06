FROM debian:trixie-slim AS dga-build

# Get and run SDRplay API installer. Note SDRPlay changes the ADD link with every version
# Consider manually downloading and using the COPY line instead.

WORKDIR /sdrplay
#ADD https://sdrplay.com/download/hardware-api-linux/?wpdmdl=1906&refresh=6ac861a5625b01791517093 ./SDRplay.run
#ADD https://sdrplay.com/hardware-api/ ./SDRplay.run
COPY SDRplay/SDRplay_RSP_API-Linux-3.15.2.run ./sdrplay.run
RUN <<ENDRUN
    chmod +x sdrplay.run
    ./sdrplay.run --tar xvf
    chmod 644 amd64/libsdrplay_api.so.3.15       #library
    chmod 755 amd64/sdrplay_apiService           #binary
ENDRUN
# sdrplay libs and binaries are in /sdrplay/amd64

# install sdrpp
ADD "https://github.com/AlexandreRouma/SDRPlusPlus/releases/download/nightly/sdrpp_debian_trixie_amd64.deb" ./sdrpp.deb
# --no-install-recommends avoids pulling in extra libs; binutils is only for strip
# and only exists in this throwaway stage (its files are deleted by the whitelist below).
RUN <<ENDRUN
    set -e
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get -y --no-install-recommends install ./sdrpp.deb libusb-1.0-0 libglfw3 busybox binutils
ENDRUN
# sdrpp is installed in /usr/bin/sdrpp
# libraries are in /lib/libsdrpp_core* and /lib/sdrpp

# Move libraries to x86_64-linux-gnu
WORKDIR /lib/x86_64-linux-gnu/
RUN <<EOR
    set -e
    cp -a /sdrplay/amd64/libsdrplay_api* .
    ln -s libsdrplay_api.so.3.15 libsdrplay_api.so.3
    cp -a /usr/lib/libsdrpp_core.* .
    rm -f *.a
EOR

# Server mode with only SDRplay: delete every other plugin here, before
# stripping, so no time is spent on files that will be thrown away.
# Uses extglob, so this needs bash.  Remove this section to keep all plugins
RUN <<EOR
#!/bin/bash
    set -e
    shopt -s extglob
    cd /usr/lib/sdrpp/plugins
    rm -f !(sdrplay_source.so)
EOR

# Strip symbols/debug info from the non-distro binaries (vendor and sdrpp builds
# are often unstripped). Distro libs are already stripped, so they are skipped.
# --strip-unneeded keeps the dynamic symbols, so loading is unaffected.
RUN <<EOR
    set -e
    find /usr/bin/sdrpp /sdrplay/amd64/sdrplay_apiService \
         /usr/lib/sdrpp /lib/x86_64-linux-gnu/libsdrpp_core.* \
         /lib/x86_64-linux-gnu/libsdrplay_api.* \
         -type f -exec strip --strip-unneeded {} + 2>/dev/null || true
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
COPY --from=dga-build /sdrplay/amd64/sdrplay_apiService /sdrpp/
COPY --from=dga-build /usr/bin/busybox /usr/bin/
COPY files/ /sdrpp

RUN <<EOR
#!/bin/bash
    set -e
    shopt -s extglob # bash extension for rm -rf !(except_files|...)

#   remove all libraries except ...
    cd /usr/lib/x86_64-linux-gnu
    EXC="!(libc.*|ld-linux*"
    EXC+="|libsdrplay_api.so.*|libsdrpp_core.*|libresolv.*"
    EXC+="|libOpenGL.*|libfftw3f.*|libvolk*|libzstd.*|libm.*"
    EXC+="|libdl.*|libX11.so.*|libpthread.*|libGLdispatch.*"
    EXC+="|liborc-0.4.*|libxcb.*|libXau.*|libXdmcp.*|libbsd.*"
    EXC+="|libmd.*|libusb*|libstdc++*|libselinux*"
    EXC+="|libudev*|libgcc_s*|librt*|libglfw.*"
    EXC+="|libGL.so.*|libGLX.so.*|libcap.so.*)"
    rm -rf $EXC

#   remove anything not needed in the container
    cd /            && rm -rf !(bin|dev|etc|lib|lib64|proc|run|sbin|sdrpp|sys|usr)
    cd /etc         && rm -rf !(passwd|group|gshadow|shadow|hosts|resolv.conf)
    cd /usr         && rm -rf !(lib|bin|sbin|lib64)
    cd /usr/lib     && rm -rf !(x86_64-linux-gnu|sdrpp)
    cd /usr/sbin    && rm -f *
    cd /usr/bin     && rm -f !(busybox|bash)   # Must be last

    /bin/busybox --install -s
    rm /bin/bash
EOR

#####################################################################
#   Ready for scratch.  We use scratch to keep deleted space out of
#   the install layer. Saves almost 500 MB.
#       Libraries are in /usr/lib/x86_64-linux-gnu
#       binaries and config files are in /sdrpp

FROM scratch AS install
COPY --from=dga-filesystem / /
EXPOSE 5259
WORKDIR /sdrpp
USER nobody
CMD ["/sdrpp/sdrpp.sh" ]
