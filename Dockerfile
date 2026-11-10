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
# --no-install-recommends avoids pulling in extra libs.
# busybox-static is a single static binary, so it needs no shared libraries at all.
# binutils is only for strip and never reaches the final image.
RUN <<ENDRUN
    set -e
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get -y --no-install-recommends install ./sdrpp.deb libusb-1.0-0 libglfw3 busybox binutils
ENDRUN
# sdrpp is installed in /usr/bin/sdrpp
# libraries are in /usr/lib/libsdrpp_core* and /usr/lib/sdrpp

# Put the SDRplay and sdrpp libraries where the loader (and ldd, below) will find them
WORKDIR /lib/x86_64-linux-gnu/
RUN <<EOR
    set -e
    cp -a /sdrplay/amd64/libsdrplay_api* .
    ln -s libsdrplay_api.so.3.15 libsdrplay_api.so.3
    cp -a /usr/lib/libsdrpp_core.* .
    rm -f *.a
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
# Build the final filesystem in /out by copying IN only what is needed.
#   - the sdrpp and sdrplay_apiService binaries
#   - the plugins we want (SDRplay + rtl_tcp, both network/API based, no USB claim by sdrpp)
#   - every shared library those binaries need, found with ldd, so there is no
#     hand-kept library list to maintain when sdrpp or SDRplay versions change
#   - busybox with all applets, /etc/passwd and /etc/group (for USER nobody)
# Nothing is ever deleted, so scratch gets a minimal, clean filesystem.

WORKDIR /
COPY files/ /out/sdrpp/
RUN <<EOR
#!/bin/bash
    set -e
    OUT=/out
    mkdir -p $OUT/usr/lib/x86_64-linux-gnu $OUT/usr/lib/sdrpp/plugins \
             $OUT/usr/bin $OUT/lib64 $OUT/etc $OUT/sdrpp $OUT/tmp
    chmod 1777 $OUT/tmp
    ln -s usr/lib $OUT/lib
    ln -s usr/bin $OUT/bin

#   binaries
    cp -a /usr/bin/sdrpp /sdrplay/amd64/sdrplay_apiService $OUT/sdrpp/

#   plugins: add or remove names here
#    for p in sdrplay_source rtl_tcp_source; do
    for p in sdrplay_source ; do
        cp -a /usr/lib/sdrpp/plugins/$p.so $OUT/usr/lib/sdrpp/plugins/
    done

#   busybox: install every applet as a symlink
    cp -a /bin/busybox $OUT/bin/busybox
    /bin/busybox --install -s $OUT/bin

#   users for USER nobody.
    cp -a /etc/passwd /etc/group $OUT/etc/

#   shared libraries: whatever ldd says the binaries and plugins need
    for f in /usr/bin/sdrpp /sdrplay/amd64/sdrplay_apiService /usr/bin/busybox $OUT/usr/lib/sdrpp/plugins/*.so; do
        ldd "$f"
    done | awk '$2=="=>" && $3 ~ /^\// {print $3} $1 ~ /^\// && $2 ~ /^\(/ {print $1}' \
         | sort -u | while read -r lib; do
        cp -L --parents "$lib" $OUT
    done
EOR

#####################################################################
#   Ready for scratch. Only the needed files get copied in.
#       Libraries are in /usr/lib/x86_64-linux-gnu (and the loader in /lib64)
#       binaries and config files are in /sdrpp, plugins in /usr/lib/sdrpp/plugins

FROM scratch
COPY --from=dga-build /out/ /
EXPOSE 5259
WORKDIR /sdrpp
USER nobody
CMD ["/sdrpp/sdrpp.sh" ]
