develop:
	hugo server -D

build:
	hugo --minify

clean:
	rm -rf public

server:
	cd public && python3 -m http.server 8000