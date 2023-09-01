#!/bin/bash

set -eu

declare -r current_source_directory="${PWD}"

declare -r revision="$(git rev-parse --short HEAD)"

declare -r toolchain_directory='/tmp/nero'

declare -r gmp_tarball='/tmp/gmp.tar.xz'
declare -r gmp_directory='/tmp/gmp-6.2.1'

declare -r mpfr_tarball='/tmp/mpfr.tar.xz'
declare -r mpfr_directory='/tmp/mpfr-4.2.0'

declare -r mpc_tarball='/tmp/mpc.tar.gz'
declare -r mpc_directory='/tmp/mpc-1.3.1'

declare -r binutils_tarball='/tmp/binutils.tar.xz'
declare -r binutils_directory='/tmp/binutils-2.41'

declare -r gcc_tarball='/tmp/gcc.tar.gz'
declare -r gcc_directory='/tmp/gcc-13.2.0'

declare -r optflags='-Os'
declare -r linkflags='-Wl,-s'

declare -r max_jobs="$(($(nproc) * 8))"

declare build_type="${1}"

if [ -z "${build_type}" ]; then
	build_type='native'
fi

declare is_native='0'

if [ "${build_type}" == 'native' ]; then
	is_native='1'
fi

declare OBGGCC_TOOLCHAIN='/tmp/obggcc-toolchain'
declare CROSS_COMPILE_TRIPLET=''

declare cross_compile_flags=''

if ! (( is_native )); then
	source "./submodules/obggcc/toolchains/${build_type}.sh"
	cross_compile_flags+="--host=${CROSS_COMPILE_TRIPLET}"
fi

if ! [ -f "${gmp_tarball}" ]; then
	curl --connect-timeout '10' --retry '15' --retry-all-errors --fail --silent --url 'https://mirrors.kernel.org/gnu/gmp/gmp-6.2.1.tar.xz' --output "${gmp_tarball}"
	tar --directory="$(dirname "${gmp_directory}")" --extract --file="${gmp_tarball}"
fi

if ! [ -f "${mpfr_tarball}" ]; then
	curl --connect-timeout '10' --retry '15' --retry-all-errors --fail --silent --url 'https://mirrors.kernel.org/gnu/mpfr/mpfr-4.2.0.tar.xz' --output "${mpfr_tarball}"
	tar --directory="$(dirname "${mpfr_directory}")" --extract --file="${mpfr_tarball}"
fi

if ! [ -f "${mpc_tarball}" ]; then
	curl --connect-timeout '10' --retry '15' --retry-all-errors --fail --silent --url 'https://mirrors.kernel.org/gnu/mpc/mpc-1.3.1.tar.gz' --output "${mpc_tarball}"
	tar --directory="$(dirname "${mpc_directory}")" --extract --file="${mpc_tarball}"
fi

if ! [ -f "${binutils_tarball}" ]; then
	curl --connect-timeout '10' --retry '15' --retry-all-errors --fail --silent --url 'https://mirrors.kernel.org/gnu/binutils/binutils-2.41.tar.xz' --output "${binutils_tarball}"
	tar --directory="$(dirname "${binutils_directory}")" --extract --file="${binutils_tarball}"
fi

if ! [ -f "${gcc_tarball}" ]; then
	curl --connect-timeout '10' --retry '15' --retry-all-errors --fail --silent --url 'https://mirrors.kernel.org/gnu/gcc/gcc-13.2.0/gcc-13.2.0.tar.xz' --output "${gcc_tarball}"
	tar --directory="$(dirname "${gcc_directory}")" --extract --file="${gcc_tarball}"
fi

sed --in-place 's/LDBL_MANT_DIG == 106/defined(__powerpc64__)/g' "${gcc_directory}/libgcc/dfp-bit.h"

[ -d "${gmp_directory}/build" ] || mkdir "${gmp_directory}/build"

cd "${gmp_directory}/build"

../configure \
	--prefix="${toolchain_directory}" \
	--enable-shared \
	--enable-static \
	${cross_compile_flags} \
	CFLAGS="${optflags}" \
	CXXFLAGS="${optflags}" \
	LDFLAGS="${linkflags}"

make all --jobs
make install

[ -d "${mpfr_directory}/build" ] || mkdir "${mpfr_directory}/build"

cd "${mpfr_directory}/build"

../configure \
	--prefix="${toolchain_directory}" \
	--with-gmp="${toolchain_directory}" \
	--enable-shared \
	--enable-static \
	${cross_compile_flags} \
	CFLAGS="${optflags}" \
	CXXFLAGS="${optflags}" \
	LDFLAGS="${linkflags}"

make all --jobs
make install

[ -d "${mpc_directory}/build" ] || mkdir "${mpc_directory}/build"

cd "${mpc_directory}/build"

../configure \
	--prefix="${toolchain_directory}" \
	--with-gmp="${toolchain_directory}" \
	--enable-shared \
	--enable-static \
	${cross_compile_flags} \
	CFLAGS="${optflags}" \
	CXXFLAGS="${optflags}" \
	LDFLAGS="${linkflags}"

make all --jobs
make install

declare -r sysroot_filename='/tmp/sysroot.tar.xz'
declare -r sysroot_directory='/tmp/SDK_481-5.2/arm-obreey-linux-gnueabi/sysroot'

curl \
	--connect-timeout '10' \
	--retry '15' \
	--retry-all-errors \
	--fail \
	--silent \
	--location \
	--output "${sysroot_filename}" \
	--url 'https://web.archive.org/web/0if_/https://codeload.github.com/pocketbook/SDK_481/tar.gz/refs/heads/5.2'

tar --extract --directory='/tmp' --file="${sysroot_filename}"

[ -d "${toolchain_directory}/${triplet}" ] || mkdir --parent "${toolchain_directory}/${triplet}"

cp --recursive "${sysroot_directory}/lib" "${toolchain_directory}/${triplet}"
cp --recursive "${sysroot_directory}/usr/lib" "${toolchain_directory}/${triplet}"
cp --recursive "${sysroot_directory}/usr/include" "${toolchain_directory}/${triplet}"
cp --recursive "${sysroot_directory}/usr/local/lib" "${toolchain_directory}/${triplet}"
cp --recursive --remove-destination "${sysroot_directory}/usr/local/include" "${toolchain_directory}/${triplet}"

cd "${toolchain_directory}/${triplet}/lib"

find "${toolchain_directory}/${triplet}/lib" -type 'l' | xargs ls -l | grep '/lib/' | awk '{print "unlink "$9" && ln --symbolic $(basename "$11") $(basename "$9")"}' | /proc/self/exe 
find "${toolchain_directory}/${triplet}/lib" -maxdepth '1' -mindepth '1' -type 'd' -exec rm --recursive {} \;
find "${toolchain_directory}/${triplet}/lib" -xtype 'l' -exec rm --force {} \; || true

sed --in-place 's|/usr/lib|.|g; s|/lib/|./|g' "${toolchain_directory}/${triplet}/lib/libc.so" "${toolchain_directory}/${triplet}/lib/libpthread.so"

[ -d "${binutils_directory}/build" ] || mkdir "${binutils_directory}/build"

cd "${binutils_directory}/build"
rm --force --recursive ./*

../configure \
	--target="${triplet}" \
	--prefix="${toolchain_directory}" \
	--enable-gold \
	--enable-ld \
	--enable-lto \
	--disable-gprofng \
	--with-static-standard-libraries \
	--with-sysroot="${toolchain_directory}/${triplet}" \
	${cross_compile_flags} \
	CFLAGS="${optflags}" \
	CXXFLAGS="${optflags}" \
	LDFLAGS="${linkflags}"

make all --jobs="${max_jobs}"
make install

[ -d "${gcc_directory}/build" ] || mkdir "${gcc_directory}/build"

cd "${gcc_directory}/build"

rm --force --recursive ./*

../configure \
	--target="${triplet}" \
	--prefix="${toolchain_directory}" \
	--with-linker-hash-style='gnu' \
	--with-gmp="${toolchain_directory}" \
	--with-mpc="${toolchain_directory}" \
	--with-mpfr="${toolchain_directory}" \
	--with-bugurl='https://github.com/AmanoTeam/Nero/issues' \
	--with-pkgversion="Nero v0.1-${revision}" \
	--with-sysroot="${toolchain_directory}/${triple}" \
	--with-native-system-header-dir='/include' \
	--with-arch='armv7-a' \
	--with-tune='cortex-a8' \
	--with-fpu='neon' \
	--with-float='softfp' \
	--enable-__cxa_atexit \
	--enable-cet='auto' \
	--enable-checking='release' \
	--enable-clocale='gnu' \
	--enable-default-ssp \
	--enable-gnu-indirect-function \
	--enable-gnu-unique-object \
	--enable-libstdcxx-backtrace \
	--enable-link-serialization='1' \
	--enable-linker-build-id \
	--enable-lto \
	--enable-shared \
	--enable-threads='posix' \
	--enable-libssp \
	--enable-languages='c,c++' \
	--enable-ld \
	--enable-gold \
	--disable-libgomp \
	--disable-bootstrap \
	--disable-libstdcxx-pch \
	--disable-werror \
	--disable-multilib \
	--disable-plugin \
	--disable-nls \
	--without-headers \
	${cross_compile_flags} \
	CFLAGS="${optflags}" \
	CXXFLAGS="${optflags}" \
	LDFLAGS="-Wl,-rpath-link,${OBGGCC_TOOLCHAIN}/${CROSS_COMPILE_TRIPLET}/lib ${linkflags}"

LD_LIBRARY_PATH="${toolchain_directory}/lib" PATH="${PATH}:${toolchain_directory}/bin" make \
	CFLAGS_FOR_TARGET="${optflags} ${linkflags}" \
	CXXFLAGS_FOR_TARGET="${optflags} ${linkflags}" \
	all --jobs="${max_jobs}"
make install

cd "${toolchain_directory}/${triplet}/bin"

for name in *; do
	rm "${name}"
	ln -s "../../bin/${triplet}-${name}" "${name}"
done

rm --recursive "${toolchain_directory}/share"
rm --recursive "${toolchain_directory}/lib/gcc/${triplet}/"*"/include-fixed"

patchelf --add-rpath '$ORIGIN/../../../../lib' "${toolchain_directory}/libexec/gcc/${triplet}/"*"/cc1"
patchelf --add-rpath '$ORIGIN/../../../../lib' "${toolchain_directory}/libexec/gcc/${triplet}/"*"/cc1plus"
patchelf --add-rpath '$ORIGIN/../../../../lib' "${toolchain_directory}/libexec/gcc/${triplet}/"*"/lto1"