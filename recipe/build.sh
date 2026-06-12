#!/usr/bin/env bash
set -exo pipefail

if [[ "${target_platform}" == win-* ]]; then
    # The windows patches touch configure.ac and Makefile.am, so regenerate
    # the build system (tools provided by autotools_clang_conda).
    autoreconf -vfi
else
    # Get an updated config.sub and config.guess
    cp $BUILD_PREFIX/share/gnuconfig/config.* .
fi

configure_args=(
    --prefix="${PREFIX}"
    --datadir="${PREFIX}/share"
    --disable-silent-rules
    --disable-dependency-tracking
)

if [[ "${target_platform}" == win-* ]]; then
    # WIN32 enables file's built-in logic to locate magic.mgc relative to
    # the DLL/EXE location (Library/bin/../share/misc/magic.mgc) at runtime,
    # since conda cannot do prefix replacement in binaries on Windows.
    # oldnames.lib provides the POSIX-named aliases (open, close, read, ...)
    # of the UCRT functions, which are not in the msvcrt umbrella lib.
    export CFLAGS="${CFLAGS} -DWIN32 -Xclang --dependent-lib=oldnames"
    # The compression support requires fork(), which is not available on
    # Windows.
    configure_args+=(
        --disable-static
        --disable-zlib
        --disable-bzlib
        --disable-xzlib
        --disable-zstdlib
        --disable-lzlib
        --disable-libseccomp
    )
fi

if [[ "${CONDA_BUILD_CROSS_COMPILATION}" == "1" ]]; then
    CC=$CC_FOR_BUILD CFLAGS=$CFLAGS_FOR_BUILD ./configure \
        --build=${BUILD} \
        --host=${BUILD} \
        --prefix="${BUILD_PREFIX}" \
        --datadir="${BUILD_PREFIX}/share" \
        --disable-silent-rules \
        --disable-dependency-tracking

    make "-j${CPU_COUNT}"
    make install
    make clean
fi

./configure "${configure_args[@]}"

if [[ "${target_platform}" == win-* ]]; then
    # Fix up libtool for creating MSVC-compatible DLLs with clang/lld
    # (function provided by autotools_clang_conda).
    patch_libtool
    # Build libmagic.dll instead of libmagic-1.dll
    sed -i.bak -e 's|-version-info [0-9]*:[0-9]*:[0-9]*|-avoid-version|g' src/Makefile
fi

make "-j${CPU_COUNT}"

if [[ "${target_platform}" != win-* && "${CONDA_BUILD_CROSS_COMPILATION}" != "1" ]]; then
    make check
fi

make install

if [[ "${target_platform}" == win-* ]]; then
    # Rename the import library to follow the MSVC naming convention
    mv "${PREFIX}/lib/magic.dll.lib" "${PREFIX}/lib/magic.lib"
    # file.exe links against magic.dll, but ctypes consumers such as
    # python-magic look for libmagic.dll, so ship the DLL under both names.
    cp "${PREFIX}/bin/magic.dll" "${PREFIX}/bin/libmagic.dll"
    # The .pc file contains the MSYS2-style build prefix (/d/bld/...), which
    # conda's prefix replacement does not handle on Windows; make it
    # relocatable instead.
    sed -i "s|^prefix=.*|prefix=\${pcfiledir}/../..|" "${PREFIX}/lib/pkgconfig/libmagic.pc"
fi
