FROM debian:bullseye-slim
LABEL org.opencontainers.image.authors="tekmanic"

# set version label
ARG BUILD_DATE
ARG VERSION
ARG DUPLICATI_RELEASE
LABEL build_version="tekmanic version:- ${VERSION} Build-date:- ${BUILD_DATE}"

# environment settings
ENV HOME="/config" \
LANGUAGE="en_US.UTF-8" \
LANG="en_US.UTF-8" \
TERM="xterm" \
PATH="${PATH}:/command"

# environment settings
ARG DEBIAN_FRONTEND="noninteractive"

# set version for s6 overlay
ARG OVERLAY_VERSION="2.2.0.3"
ARG OVERLAY_ARCH="x86"

# Base mono layer
RUN \
 echo "**** install apt-transport-https ****" && \
 apt-get update && \
 apt-get install -y apt-transport-https dirmngr gnupg ca-certificates xz-utils locales && \
 echo "**** add mono repository ****" && \
 apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF && \
 echo "deb http://download.mono-project.com/repo/debian stable-buster main" | tee /etc/apt/sources.list.d/mono-official-stable.list && \
 echo "**** install packages ****" && \
 apt-get update && \
 apt-get install -y \
	--no-install-recommends \
	--no-install-suggests \
	ca-certificates-mono \
	libcurl4-openssl-dev \
	mono-devel \
	mono-vbnc && \
 echo "**** clean up ****" && \
 echo "**** generate locale ****" && \
 locale-gen en_US.UTF-8 && \
 echo "**** create abc user and make our folders ****" && \
 useradd -u 911 -U -d /config -s /bin/false abc && \
 usermod -G users abc && \
 mkdir -p \
	/app \
	/config \
	/defaults

# add s6 overlay
ADD https://github.com/just-containers/s6-overlay/releases/download/v${OVERLAY_VERSION}/s6-overlay-${OVERLAY_ARCH}.tar.gz /tmp

RUN \
 tar -C / -xf /tmp/s6-overlay-${OVERLAY_ARCH}.tar.gz && \
 echo "**** install dependencies ****" && \
 apt-get update && \
 apt-get install -y \
	jq curl unzip wget make python3 python3-cryptography && \
 echo "**** install duplicati ****" && \
 if [ -z ${DUPLICATI_RELEASE+x} ]; then \
	DUPLICATI_RELEASE=$(curl -sX GET "https://api.github.com/repos/duplicati/duplicati/releases" \
	| jq -r 'first(.[] | select(.tag_name | contains("beta"))) | .tag_name'); \
 fi && \
 mkdir -p \
	/app/duplicati && \
  duplicati_url=$(curl -s https://api.github.com/repos/duplicati/duplicati/releases/tags/"${DUPLICATI_RELEASE}" |jq -r '.assets[].browser_download_url' |grep zip |grep -v signatures) && \
 curl -o \
 /tmp/duplicati.zip -L \
	"${duplicati_url}" && \
 unzip -q /tmp/duplicati.zip -d /app/duplicati && \
 echo "**** fix CA certificates ****" && \
 mkdir /certs && \
 cd /certs && \
 wget https://launchpad.net/debian/+archive/primary/+sourcefiles/ca-certificates/20211016/ca-certificates_20211016.tar.xz && \
    tar -xJf ca-certificates_20211016.tar.xz && \
    cd work && \
    make && \
    make install && \
    sed -i"" 's/mozilla\/DST_Root_CA_X3.crt/!mozilla\/DST_Root_CA_X3.crt/' /etc/ca-certificates.conf && \
    rm -rf /usr/share/ca-certificates/mozilla/DST_ROOT_CA_X3.crt /etc/ssl/certs/DST_Root_CA_X3.pem && \
    dpkg-reconfigure -fnoninteractive ca-certificates && \
    update-ca-certificates -f && \
 echo "**** cleanup ****" && \
 export DEBIAN_FRONTEND=noninteractive && \
 apt-get --yes --allow-downgrades --allow-remove-essential --allow-change-held-packages --purge remove \
    make patch curl unzip && \
 apt-get --yes --allow-downgrades --allow-remove-essential --allow-change-held-packages --purge --auto-remove remove \
    python3 python3-cryptography gnupg xz-utils locales && \ 
 apt-get autoremove && \
 apt-get clean && \
 rm -rf \
	/tmp/* \
    /certs \
    /usr/share/doc/* \
    /usr/share/fonts/* \
    /usr/share/i18n/* \
	/var/lib/apt/lists/* \
	/var/tmp/* \
    /var/cache/apt/archives/* \
    /var/dpkg/info/*

# copy local files
COPY root/ /

# ports and volumes
EXPOSE 8200
VOLUME /backups /config /source
RUN chown abc:abc /config /app/duplicati

ENTRYPOINT ["/init"]
# ENTRYPOINT [ "tail", "-f", "/dev/null" ]