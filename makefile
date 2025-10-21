# Makefile inspiration from Kore (Kore.io)
CC?=gcc
PREFIX?=/usr/local
HLSDL=hlsdl
INSTALL_DIR=$(PREFIX)/bin
MAN=hlsdl.1
INSTALL_DIR_MAN=$(PREFIX)/man/man1
OSNAME=$(shell uname -s | sed -e 's/[-_].*//g' | tr A-Z a-z)

S_SRC= src/main.c src/aes_openssl.c src/curl.c src/hls.c src/misc.c src/msg.c src/mpegts.c
ifeq ("$(OSNAME)", "darwin")
    OPENSSL_MACOS=$(shell brew --prefix openssl)
	CFLAGS+=-I/usr/local/include/
	CFLAGS+=-I$(OPENSSL_MACOS)/include
	LDFLAGS+=-L/usr/local/lib
	LDFLAGS+=-L$(OPENSSL_MACOS)/lib
else ifeq ("$(OSNAME)", "linux")
	CFLAGS+=-D_GNU_SOURCE=1 -std=gnu99
else ifneq ($(findstring "$(OSNAME)","mingw32" "mingw64" "cygwin"),)
	CFLAGS+=-D_GNU_SOURCE=1 -std=gnu99 -DCURL_STATICLIB
	S_SRC+=msvc/win/memmem.c
else
endif
S_OBJS=	$(S_SRC:.c=.o)

CFLAGS+=-Wall -Wstrict-prototypes -Wmissing-prototypes
CFLAGS+=-Wmissing-declarations -Wshadow -Wpointer-arith -Wcast-qual
CFLAGS+=-Wsign-compare -Iincludes
CFLAGS+=-DPREFIX='"$(PREFIX)"'

ifeq ("$(OSNAME)", "cygwin")
	LDFLAGS+=-lpthread $(shell pkg-config libcurl --static --libs)
else ifneq ($(findstring "$(OSNAME)","mingw32" "mingw64"),)
	LDFLAGS+=-Wl,-Bstatic -lpthread -lcurl -lnghttp2 -lssh2 -lbrotlidec-static -lbrotlicommon-static -lssl -lcrypto -lcrypt32 -lwsock32 -lws2_32 -lwldap32 -lz -lzstd
else
	LDFLAGS+=-lpthread -lcurl -lcrypto -lssl
endif


all: $(HLSDL)

hlsdl: $(S_OBJS)
	$(CC) $(S_OBJS) $(LDFLAGS) -o $(HLSDL)

install:
	mkdir -p $(INSTALL_DIR)
	install -m 755 $(HLSDL) $(INSTALL_DIR)/$(HLSDL)
	mkdir -p $(INSTALL_DIR_MAN)
	cp $(MAN) $(INSTALL_DIR_MAN)

uninstall:
	rm -f $(INSTALL_DIR)/$(HLSDL)

.c.o:
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	find . -type f -name \*.o -exec rm {} \;
	rm -f $(HLSDL)

.PHONY: clean

# Build debian package
APP_BIN=./hlsdl
PACKAGE_VERSION=$(patsubst v%,%,$(shell git describe --tags --long --dirty))
PACKAGE_DEPS=$(patsubst shlibs:Depends=%,%,$(shell dpkg-shlibdeps ${APP_BIN} -O))
PACKAGE_TYPE=deb
PACKAGE_ARCH=$(shell dpkg --print-architecture)
PACKAGE_NAME=hlsdl
PACKAGE_FILENAME=${PACKAGE_NAME}-${PACKAGE_VERSION}-${PACKAGE_ARCH}.${PACKAGE_TYPE}
PACKAGE_BINDIR=/usr/local/bin
LINTIAN_IGNORE=debian-changelog-file-missing-or-wrong-name,dir-in-usr-local,extended-description-is-empty,file-in-usr-local

deb: all

ifeq (, $(shell which dpkg-shlibdeps))
	$(error "dpkg-shlibdeps is required, consider doing apt-get install dpkg-dev")
endif
ifeq (, $(shell which fpm))
	$(error "fpm is required, please check https://fpm.readthedocs.io/en/latest/installation.html")
endif
	strip -s  "${APP_BIN}"
	chmod 755 "${APP_BIN}"
	chmod 644 "LICENSE"
	fpm -f -s dir                  \
  -t             "${PACKAGE_TYPE}"     \
  -p             "${PACKAGE_FILENAME}" \
  --name         "${PACKAGE_NAME}"     \
  --version      "${PACKAGE_VERSION}"  \
  --architecture "${PACKAGE_ARCH}"     \
  --depends      "${PACKAGE_DEPS}"     \
  --description "Converts .m3u8 playlists (using fragmented mpegts) to a .ts video." \
  --url         "https://github.com/selsta/hlsdl"       \
  --maintainer  "selsta <selsta@sent.at>"               \
  --license     "MIT"                                   \
    "LICENSE"="usr/share/doc/${PACKAGE_NAME}/copyright" \
    ${APP_BIN}="${PACKAGE_BINDIR}/${PACKAGE_NAME}"
ifeq (, $(shell which lintian))
	@echo "warning: lintian is not available: package checking is disabled, consider doing apt-get install lintian"
else
	lintian --suppress-tags "${LINTIAN_IGNORE}" "${PACKAGE_FILENAME}"
endif
