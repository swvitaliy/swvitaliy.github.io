develop: clean
	hugo server --disableFastRender -D

build-full: build download-archive

build: clean
	hugo --minify

download-archive: clear-archive
	wget -O public/archive.zip https://github.com/swvitaliy/old-swvitaliy.github.io/archive/refs/heads/main.zip
	unzip public/archive.zip -d public
	mv public/old-swvitaliy.github.io-main public/archive
	rm public/archive.zip
	rm -rf public/archive/.git

clean:
	rm -rf public

clear-archive:
	rm -rf public/archive

server:
	cd public && python3 -m http.server 8000

submod-update:
	git submodule update --init --recursive


