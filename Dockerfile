# syntax=docker/dockerfile:1@sha256:ecfaec9ed6d810b56388c508f4121597bfbba70d41a6dfeee4d8cad5f295fc32
FROM registry.access.redhat.com/ubi9/ubi-minimal:9.6@sha256:34880b64c07f28f64d95737f82f891516de9a3b43583f39970f7bf8e4cfa48b7

RUN set -eu; \
    curl --fail --silent --show-error --location --retry 3 \
        https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm \
        --output /tmp/epel-release.rpm; \
    rpm --import https://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-9; \
    rpmkeys --checksig /tmp/epel-release.rpm; \
    rpm -ivh /tmp/epel-release.rpm; \
    microdnf update -y; \
    microdnf install -y --setopt=install_weak_deps=0 \
        ca-certificates glibc-langpack-en openssl fontconfig tzdata-java \
        libgdiplus libicu tar gzip jq \
        java-11-openjdk-devel java-17-openjdk-devel java-21-openjdk-devel \
        unzip git which dejavu-sans-fonts shadow-utils; \
    microdnf clean all; \
    rm -rf /var/cache/yum /var/cache/dnf /tmp/epel-release.rpm; \
    rm -f /var/log/dnf* /var/log/yum.log; \
    ln -s libgdiplus.so.0 /usr/lib64/libgdiplus.so

ENV LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8
CMD ["/bin/bash"]
