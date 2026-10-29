# Akuji the Demon.
#
#   make              build bin/akuji, fetching Free Pascal first if needed
#   make release      the same, optimised, without debug info, stripped
#   make windows      the Windows release, bin/akuji.exe (built on Windows)
#   make linux        the Linux release, bin/akuji (built on Linux)
#   make portmaster   the PortMaster package, dist/akuji.zip (needs Docker)
#   make test         build, then run every self-test
#   make configure    fetch Free Pascal and check the libraries, and stop there
#   make clean        remove what the build produced
#   make distclean    also remove the fetched Free Pascal in .toolchain/
#
# The work is in tools/, so the same steps run without make:
# tools/configure.sh, tools/build.sh, tools/test.sh. See README.md.

.PHONY: all build release windows linux portmaster test configure clean distclean

HOST := $(shell uname -s)

all: build

configure:
	@tools/configure.sh

build: configure
	@tools/build.sh

release: configure
	@RELEASE=1 tools/build.sh

# Free Pascal compiles for the machine it runs on, so each desktop release is
# built on its own system; naming the other platform says which target to use.
windows: configure
	@case "$(HOST)" in \
	    MINGW*|MSYS*|CYGWIN*) ;; \
	    *) echo "make windows builds on Windows; this host builds 'make linux'" >&2; exit 1 ;; \
	esac
	@RELEASE=1 tools/build.sh

linux: configure
	@case "$(HOST)" in \
	    MINGW*|MSYS*|CYGWIN*) echo "make linux builds on Linux; this host builds 'make windows'" >&2; exit 1 ;; \
	    *) ;; \
	esac
	@RELEASE=1 tools/build.sh

portmaster:
	@tools/package-portmaster.sh

test: configure
	@tools/test.sh

clean:
	rm -rf lib
	rm -f bin/akuji bin/akuji.exe bin/selftest.log

distclean: clean
	rm -rf .toolchain
