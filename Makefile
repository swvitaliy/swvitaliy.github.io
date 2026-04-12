develop: clean
	hugo server --disableFastRender -D

build: clean
	hugo --minify
	rm -rf public/archive/.git

clean:
	rm -rf public

server:
	cd public && python3 -m http.server 8000

submod-update:
	git submodule update --init --recursive


