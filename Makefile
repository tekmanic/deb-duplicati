TOPDIR=$(PWD)

all: build run 

run: build
	docker run -d \
	--name deb-duplicati \
	-e PUID=1000 \
	-e PGID=1000 \
	-e TZ=Europe/London \
	-e CLI_ARGS=`#optional` \
	-p 8200:8200 \
	-v $(TOPDIR)/config:/config \
	-v $(TOPDIR)/backups:/backups \
	-v $(TOPDIR)/source:/source \
	--restart unless-stopped \
	deb-duplicati:latest

build:
	docker build -t deb-duplicati:latest .

clean:
	docker kill deb-duplicati || true
	docker rm -f deb-duplicati