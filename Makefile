develop: clean
	hugo server --disableFastRender -D

build-full: build download-archive

build: clean
	hugo --minify

download-archive: clear-archive
	git clone git@github.com:swvitaliy/old-swvitaliy.github.io.git public/archive
	rm -rf public/archive/.git

clean:
	rm -rf public

clear-archive:
	rm -rf public/archive

server:
	cd public && python3 -m http.server 8000

submod-update:
	git submodule update --init --recursive


