default: build
all: build

ICED=node_modules/.bin/iced
BUILD_STAMP=build-stamp
TEST_STAMP=test-stamp

default: build
all: build

lib/%.js: src/%.iced
	$(ICED) -I node -c -o `dirname $@` $<

$(BUILD_STAMP): \
	lib/client.js \
	lib/debug.js \
	lib/dispatch.js \
	lib/errors.js \
	lib/iced.js \
	lib/list.js \
	lib/listener.js \
	lib/lock.js \
	lib/log.js \
	lib/main.js \
	lib/pack.js \
	lib/packetizer.js \
	lib/ring.js \
	lib/server.js \
	lib/timer.js \
	lib/transport.js \
	lib/version.js
	date > $@

clean:
	find lib -type f -name *.js -exec rm {} \;

build: $(BUILD_STAMP)

setup:
	npm install -d

test:
	(cd test && ../$(ICED) all.iced)

.PHONY: test setup
