FROM buildpack-deps:stretch

RUN apt-key adv --keyserver hkp://pgp.mit.edu:80 --recv-keys 573BFD6B3D8FBC641079A6ABABF5BD827BD9BF62
RUN echo "deb http://nginx.org/packages/mainline/debian/ stretch nginx" >> /etc/apt/sources.list && \
    echo "deb-src http://nginx.org/packages/mainline/debian/ stretch nginx" >> /etc/apt/sources.list

ENV NGINX_VERSION 1.13
ENV RTMP_VERSION 1.2.0
ENV VOD_VERSION 1.19

RUN mkdir -p /usr/src/nginx
WORKDIR /usr/src/nginx

# Download nginx source
RUN apt-get update && \
    apt-get install -y ca-certificates dpkg-dev && \
    apt-get source nginx=${NGINX_VERSION}-1~stretch && \
    apt-get build-dep -y nginx=${NGINX_VERSION}-1~stretch && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /usr/src/nginx/nginx-${NGINX_VERSION}/debian/modules/

# Download RTMP module
RUN curl -L https://github.com/arut/nginx-rtmp-module/archive/v${RTMP_VERSION}.tar.gz | tar xz && \
    ln -s nginx-rtmp-module-${RTMP_VERSION} nginx-rtmp-module

# Download VOD module
RUN curl -L https://github.com/kaltura/nginx-vod-module/archive/${VOD_VERSION}.tar.gz | tar xz && \
    ln -s nginx-vod-module-${VOD_VERSION} nginx-vod-module

# Add modules to build nginx debian rules
ENV RTMP_MODULE_SOURCE "\\\/usr\\\/src\\\/nginx\\\/nginx-${NGINX_VERSION}\\\/debian\\\/modules\\\/nginx-rtmp-module-${RTMP_VERSION}"
ENV VOD_MODULE_SOURCE "\\\/usr\\\/src\\\/nginx\\\/nginx-${NGINX_VERSION}\\\/debian\\\/modules\\\/nginx-vod-module-${VOD_VERSION}"
RUN sed -ri "s/--with-ipv6/--with-ipv6 --add-module=${RTMP_MODULE_SOURCE} --add-module=${VOD_MODULE_SOURCE}/" \
        /usr/src/nginx/nginx-${NGINX_VERSION}/debian/rules

# Build nginx debian package
WORKDIR /usr/src/nginx/nginx-${NGINX_VERSION}
RUN dpkg-buildpackage -b

# Install nginx
WORKDIR /usr/src/nginx
RUN dpkg -i nginx_${NGINX_VERSION}-1~stretch_amd64.deb

# Add rtmp config wildcard inclusion
RUN mkdir -p /etc/nginx/rtmp.d && \
    printf "\nrtmp {\n\tinclude /etc/nginx/rtmp.d/*.conf;\n}\n" >> /etc/nginx/nginx.conf

# Install ffmpeg / aac
RUN echo 'deb http://www.deb-multimedia.org stretch main non-free' >> /etc/apt/sources.list && \
    apt-get update && \
    apt-get install -y --force-yes deb-multimedia-keyring && \
    apt-get update && \
    apt-get install -y \
        ffmpeg

# Cleanup
RUN apt-get purge -yqq dpkg-dev && \
    apt-get autoremove -yqq && \
    apt-get clean -yqq && \
    rm -rf /usr/src/nginx

# Forward request and error logs to docker log collector
RUN ln -sf /dev/stdout /var/log/nginx/access.log
RUN ln -sf /dev/stderr /var/log/nginx/error.log

VOLUME ["/var/cache/nginx"]

EXPOSE 80 443

CMD ["nginx", "-g", "daemon off;"]
