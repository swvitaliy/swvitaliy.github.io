develop:
	hugo server --disableFastRender -D

build-full: build publish-archive

build: clean
	hugo --minify

download-archive:
	[ -d static/archive ] || \
		git clone git@github.com:swvitaliy/old-swvitaliy.github.io.git static/archive && \
		rm -rf static/archive/.git

publish-archive: clear-archive download-archive
	cp -pr static/archive public/archive

clean:
	rm -rf public

clear-archive:
	rm -rf public/archive

server:
	cd public && python3 -m http.server 8000

submod-update:
	git submodule update --init --recursive


