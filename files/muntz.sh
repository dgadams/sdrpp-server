#!/bin/bash
shopt -s extglob    #bash extenstion to allow rm -rf !(execept_files|...)

# 	remove all libraries except ...
cd /usr/lib/x86_64-linux-gnu
   	EXC="!(libc.*|ld-linux*"
    EXC+="|libsdrplay_api.so.*|libsdrpp_core.*|libresolv.*"
    EXC+="|libOpenGL.*|libfftw3f.*|libvolk*|libzstd.*|libm.*"
    EXC+="|libdl.*|libX11.so.*|libpthread.*|libGLdispatch.*"
    EXC+="|liborc-0.4.*|libxcb.*|libXau.*|libXdmcp.*|libbsd.*"
    EXC+="|libmd.*|librtlsdr.*|libusb*|libstdc++*|libselinux*"
    EXC+="|libudev*|libgcc_s*|librt*|libglfw.*"
    EXC+="|libGL.so.*|libGLX.so.*|libcap.so.*)"
rm -fr $EXC

#   remove anything not needed in the container
cd /var && rm -rf *
cd /etc && rm -rf !(passwd|group|gshadow|shadow)
cd /usr && rm -rf !(lib|bin|sbin|lib64|libexec)
cd /usr/lib && rm -rf !(x86_64-linux-gnu|sdrpp)
cd /usr/sbin && rm *
cd /usr/bin  && rm !(busybox)   # Must be last

