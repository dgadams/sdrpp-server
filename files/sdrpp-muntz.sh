#!/bin/bash
# This script uses a feature of bash - extglob which allows rm !(exception_list) to
# selectively remove any file in the current image layer except those listed.
# Used for muntzing libraries and files down to the minimal set needed to run the application.

shopt -s extglob

#   Remove /lib directories and files
	cd /usr/lib
	rm -rf !(x86_64-linux-gnu|sdrpp)

# 	remove all libraries except ...
	cd /usr/lib/x86_64-linux-gnu
	EXC="!(libc.*|ld-linux*"							# basic c library
#	EXC+="|libtinfo*"									# needed for bash
#	EXC+="|libselinux*|libacl.*|libattr.*|libpcre*"		# needed for cp
	EXC+="|libresolv.*"									# needed for busybox
    EXC+="|libsdrplay_api.so.*|libsdrpp_core.*"         # sdrpp libraries
    EXC+="|libOpenGL.*|libfftw3f.*|libvolk*|libzstd.*|libm.*"
    EXC+="|libdl.*|libX11.so.*|libpthread.*|libGLdispatch.*"
    EXC+="|liborc-0.4.*|libxcb.*|libXau.*|libXdmcp.*|libbsd.*"
    EXC+="|libmd.*|librtlsdr.*|libusb*|libstdc++*|libselinux*"
    EXC+="|libudev*|libgcc_s*|librt*|libglfw.*"
    EXC+="|libGL.so.*|libGLX.so.*|libcap.so.*"
	EXC+=")"
	rm -fr $EXC

#   Nuke anything not needed in the container
    cd /var && rm -rf !(nothing)
    cd /etc && rm -rf !(passwd|group|gshadow|shadow)
    cd /usr && rm -rf !(lib|bin|sbin|lib64|libexec)

# 	And last remove everything from sbin and bin except busybox.
	cd /usr/sbin && rm !(nothing)
	cd /usr/bin  && rm !(busybox)

