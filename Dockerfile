ARG DISTRO=alpine
ARG DISTRO_VARIANT=3.21

FROM docker.io/alpine:${DISTRO_VARIANT}
LABEL maintainer="lunksnee (github.com/lunksnee)"

SHELL ["/bin/sh", "-o", "pipefail", "-c"]

ENV INFLUX1_CLIENT_VERSION=1.8.0 \
    INFLUX2_CLIENT_VERSION=2.7.5 \
    MSODBC_VERSION=18.6.1.1-1 \
    MSSQL_VERSION=18.6.1.1-1 \
    MYSQL_VERSION=mysql-8.4.8 \
    POSTGRES_TAR_SHA256=6f14aa10bb67b8c2d7f280c63ddb3dbee9554a2a39d7d358f24431bac4798c75 \
    CONFIG_GUESS_SHA256=3c1ff0db10ef9f4e8b6ed0125db308d614a209077487c03cd362d5b88b1d8e16 \
    CONFIG_SUB_SHA256=ca694343d4058d58b016ad905f25d29d4c7ef8bdd9b3bf1d0c1df5c1e046a6bf \
    INFLUX2_CLIENT_SHA256=d8a48d4f94a8b1c2f0a846e0ae6b5f7d03d10e7f7ed004cf2810e38b2718e6f6 \
    PBZIP2_SHA256=6f4c2fdcc3bf55c4d505ccf7f5dfd303e8f5d69a49e497f420ccc8664e761a12 \
    MSODBCSQL18_SHA256=29c17885e2f8e5bcb0f4e9f5cd2a34b6d5d361bef4d9189e02c4c6ff7753beec \
    MSSQL_TOOLS18_SHA256=94acd01795511efd83f03f59e5fdcbe812eaeecd6335ba8e2f3770f4977ebf31 \
    BLOBXFER_VERSION=1.17.4 \
    MYSQL_REPO_URL=https://github.com/mysql/mysql-server \
    AWS_CLI_VERSION=1.44.56 \
    POSTGRES_VERSION=18.3 \
    CONTAINER_ENABLE_MESSAGING=TRUE \
    CONTAINER_ENABLE_MONITORING=TRUE \
    IMAGE_NAME="lunksnee/container-db-backup" \
    IMAGE_REPO_URL="https://github.com/lunksnee/container-db-backup/"

RUN source /assets/functions/00-container && \
    set -ex && \
    addgroup -g 70 postgres && \
    adduser -S -D -H -h /var/lib/postgresql -s /bin/sh -G postgres -u 70 postgres && \
    mkdir -p /var/lib/postgresql && \
    chown -R postgres:postgres /var/lib/postgresql && \
    \
    package update && \
    package upgrade && \
    package install .postgres-build-deps \
                    bison \
                    clang19 \
                    coreutils \
                    dpkg-dev \
                    dpkg \
                    flex \
                    g++ \
                    gcc \
                    icu-dev \
                    libc-dev \
                    libedit-dev \
                    libxml2-dev \
                    libxslt-dev \
                    linux-headers \
                    llvm19-dev \
                    lz4-dev \
                    make \
                    openldap-dev \
                    openssl-dev \
                    perl-dev \
                    perl-ipc-run \
                    perl-utils \
                    python3-dev \
                    tcl-dev \
                    util-linux-dev \
                    zlib-dev \
                    zstd-dev \
                    && \
   \
   package install .postgres-run-deps \
                    icu-data-full \
                    libpq-dev \
                    llvm19 \
                    musl-locales \
                    openssl \
                    zstd-libs \
                    && \
   \
   mkdir -p /usr/src/postgres && \
   curl -sSL --progress-bar https://ftp.postgresql.org/pub/source/v"${POSTGRES_VERSION}"/postgresql-"${POSTGRES_VERSION}".tar.bz2 -o /tmp/postgresql-"${POSTGRES_VERSION}".tar.bz2 && \
   echo "$POSTGRES_TAR_SHA256  /tmp/postgresql-$POSTGRES_VERSION.tar.bz2" | sha256sum -c - && \
   tar xvfj /tmp/postgresql-"${POSTGRES_VERSION}".tar.bz2 --strip 1 -C /usr/src/postgres && \
   cd /usr/src/postgres && \
   awk '$1 == "#define" && $2 == "DEFAULT_PGSOCKET_DIR" && $3 == "\"/tmp\"" { $3 = "\"/var/run/postgresql\""; print; next } { print }' src/include/pg_config_manual.h > src/include/pg_config_manual.h.new && \
   grep '/var/run/postgresql' src/include/pg_config_manual.h.new && \
   mv src/include/pg_config_manual.h.new src/include/pg_config_manual.h && \
   curl -sSL --progress-bar https://git.savannah.gnu.org/cgit/config.git/plain/config.guess?id=7d3d27baf8107b630586c962c057e22149653deb -o config/config.guess && \
   echo "$CONFIG_GUESS_SHA256  config/config.guess" | sha256sum -c - && \
   curl -sSL --progress-bar https://git.savannah.gnu.org/cgit/config.git/plain/config.sub?id=7d3d27baf8107b630586c962c057e22149653deb -o config/config.sub && \
   echo "$CONFIG_SUB_SHA256  config/config.sub" | sha256sum -c - && \
   export LLVM_CONFIG="/usr/lib/llvm19/bin/llvm-config" && \
   export CLANG=clang-19  && \
    ./configure \
        --build="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)" \
        --prefix=/usr/local \
        --with-includes=/usr/local/include \
        --with-libraries=/usr/local/lib \
        --with-system-tzdata=/usr/share/zoneinfo \
        --with-pgport=5432 \
        --disable-rpath \
        --enable-integer-datetimes \
        --enable-thread-safety \
        --enable-tap-tests \
        --with-gnu-ld \
        --with-icu \
        --with-ldap \
        --with-libxml \
        --with-libxslt \
        --with-llvm \
        --with-lz4 \
        --with-openssl \
        --with-perl \
        --with-python \
        --with-tcl \
        --with-uuid=e2fs \
        --with-zstd \
        && \
    make -j "$(nproc)" world-bin && \
    make install-world-bin && \
    make -j "$(nproc)" -C contrib && \
    make -C contrib/ install && \
    runDeps="$( \
		scanelf --needed --nobanner --format '%n#p' --recursive /usr/local \
			| tr ',' '\n' \
			| sort -u \
			| awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
			| grep -v -e perl -e python -e tcl \
            )"; \
	package install .postgres-additional-deps \
                    $runDeps \
	               && \
	\
    package remove \
                    .postgres-build-deps \
                    && \
    package cleanup && \
    find /usr/local -name '*.a' -delete && \
    rm -rf \
            /root/.cache \
            /root/go \
	       /usr/local/share/doc \
	       /usr/local/share/man \
            /usr/src/* \
            && \
    \
    set -ex && \
    addgroup -S -g 10000 dbbackup && \
    adduser -S -D -H -u 10000 -G dbbackup -g "Tired of I.T! DB Backup" dbbackup && \
    \
    package update && \
    package upgrade && \
    package install .db-backup-build-deps \
                    build-base \
                    bzip2-dev \
                    cargo \
                    cmake \
                    git \
                    go \
                    libarchive-dev \
                    libtirpc-dev \
                    openssl-dev \
                    libffi-dev \
                    ncurses-dev \
                    python3-dev \
                    py3-pip \
                    xz-dev \
                    && \
    \
    package install .db-backup-run-deps \
                    bzip2 \
                    coreutils \
                    gpg \
                    gpg-agent \
                    groff \
                    libarchive \
                    libtirpc \
                    mariadb-client \
                    mariadb-connector-c \
                    mongodb-tools \
                    ncurses \
                    openssl \
                    pigz \
                    pixz \
                    pv \
                    py3-botocore \
                    py3-colorama \
                    py3-cryptography \
                    py3-docutils \
                    py3-jmespath \
                    py3-rsa \
                    py3-setuptools \
                    py3-s3transfer \
                    py3-yaml \
                    python3 \
                    redis \
                    sqlite \
                    xz \
                    zip \
                    zstd \
                    && \
    \
    echo ""
    RUN set -ex && \
    source /assets/functions/00-container && \
    mkdir -p /opt/microsoft/msodbcsql18/ && \
    touch /opt/microsoft/msodbcsql18/ACCEPT_EULA && \
    case "$(uname -m)" in \
	    "x86_64" ) mssql=true ; mssql_arch=amd64; influx2=true ; influx_arch=amd64; ;; \
        "arm64" | "aarch64" ) mssql=true ; mssql_arch=arm64; influx2=true ; influx_arch=arm64 ;; \
        *) sleep 0.1 ;; \
    esac; \
    \
    if [ "${mssql,,}" = "true" ] ; then \
        curl -sSL --progress-bar "https://download.microsoft.com/download/9dcab408-e0d4-4571-a81a-5a0951e3445f/msodbcsql18_${MSODBC_VERSION}_${mssql_arch}.apk" -O ; \
        echo "${MSODBCSQL18_SHA256}  msodbcsql18_${MSODBC_VERSION}_${mssql_arch}.apk" | sha256sum -c - ; \
        curl -sSL --progress-bar "https://download.microsoft.com/download/b60bb8b6-d398-4819-9950-2e30cf725fb0/mssql-tools18_${MSSQL_VERSION}_${mssql_arch}.apk" -O ; \
        echo "${MSSQL_TOOLS18_SHA256}  mssql-tools18_${MSSQL_VERSION}_${mssql_arch}.apk" | sha256sum -c - ; \
        apk add --no-cache "msodbcsql18_${MSODBC_VERSION}_${mssql_arch}.apk" "mssql-tools18_${MSSQL_VERSION}_${mssql_arch}.apk" ; \
    else \
        echo >&2 "Detected non x86_64 or ARM64 build variant, skipping MSSQL installation" ; \
    fi; \
    \
    if [ "${influx2,,}" = "true" ] ; then \
        curl -sSL --progress-bar "https://dl.influxdata.com/influxdb/releases/influxdb2-client-${INFLUX2_CLIENT_VERSION}-linux-${influx_arch}.tar.gz" -o "/tmp/influxdb2-client-${INFLUX2_CLIENT_VERSION}-linux-${influx_arch}.tar.gz" && \
        echo "$INFLUX2_CLIENT_SHA256  /tmp/influxdb2-client-${INFLUX2_CLIENT_VERSION}-linux-${influx_arch}.tar.gz" | sha256sum -c - && \
        tar xvfz "/tmp/influxdb2-client-${INFLUX2_CLIENT_VERSION}-linux-${influx_arch}.tar.gz" --strip=1 -C /usr/src/ ; \
        chmod +x /usr/src/influx ; \
        mv /usr/src/influx /usr/sbin/ ; \
    else \
        echo >&2 "Unable to build Influx 2 on this system" ; \
    fi ; \
    \
    clone_git_repo https://github.com/influxdata/influxdb "${INFLUX1_CLIENT_VERSION}" && \
    go build -o /usr/sbin/influxd ./cmd/influxd && \
    strip /usr/sbin/influxd && \
    \
    clone_git_repo "${MYSQL_REPO_URL}" "${MYSQL_VERSION}" && \
    cmake \
        -DCMAKE_BUILD_TYPE=MinSizeRel \
        -DCMAKE_INSTALL_PREFIX=/opt/mysql \
        -DFORCE_INSOURCE_BUILD=1 \
        -DWITHOUT_SERVER:BOOL=ON \
        && \
    make -j$(nproc) install && \
    \
    python3 -m venv /opt/dbbackup/venv && \
    /opt/dbbackup/venv/bin/pip install --upgrade pip && \
    /opt/dbbackup/venv/bin/pip install awscli==${AWS_CLI_VERSION} blobxfer==${BLOBXFER_VERSION} && \
    ln -s /opt/dbbackup/venv/bin/aws /usr/local/bin/aws && \
    ln -s /opt/dbbackup/venv/bin/blobxfer /usr/local/bin/blobxfer && \
    \
    mkdir -p /usr/src/pbzip2 && \
    curl -sSL https://launchpad.net/pbzip2/1.1/1.1.13/+download/pbzip2-1.1.13.tar.gz -o /tmp/pbzip2-1.1.13.tar.gz && \
    echo "$PBZIP2_SHA256  /tmp/pbzip2-1.1.13.tar.gz" | sha256sum -c - && \
    tar xvfz /tmp/pbzip2-1.1.13.tar.gz --strip=1 -C /usr/src/pbzip2 && \
    cd /usr/src/pbzip2 && \
    make && \
    make install && \
    \
    package remove .db-backup-build-deps && \
    package cleanup && \
    rm -rf \
            /*.apk \
            /etc/logrotate.d/* \
            /root/.cache \
            /root/go \
            /tmp/* \
            /usr/src/*

COPY install  /
