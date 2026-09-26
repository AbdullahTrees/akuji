# Akuji the Demon.
#
#   make              build bin/akuji, fetching Free Pascal first if needed
#   make release      the same, optimised, without debug info, stripped
#   make test         build, then run every self-test
#   make configure    fetch Free Pascal and check the libraries, and stop there
#   make clean        remove what the build produced
#   make distclean    also remove the fetched Free Pascal in .toolchain/
#
# The work is in tools/, so the same steps run without make:
# tools/configure.sh, tools/build.sh, tools/test.sh. See README.md.

.PHONY: all build release test configure clean distclean

all: build

configure:
	@tools/configure.sh

build: configure
	@tools/build.sh

release: configure
	@RELEASE=1 tools/build.sh

test: configure
	@tools/test.sh

clean:
	rm -rf lib
	rm -f bin/akuji bin/akuji.exe bin/selftest.log

distclean: clean
	rm -rf .toolchain
