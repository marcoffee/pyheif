ARG PLAT=manylinux2014_x86_64

FROM quay.io/pypa/$PLAT AS base
ARG PLAT


###############
# Build tools #
###############

FROM base AS build-tools

WORKDIR /build

# pkg-config
RUN set -ex \
    && PKG_CONFIG_VERSION="0.29.2" \
    && curl -fLO https://pkg-config.freedesktop.org/releases/pkg-config-${PKG_CONFIG_VERSION}.tar.gz \
    && tar xvf pkg-config-${PKG_CONFIG_VERSION}.tar.gz \
    && cd pkg-config-${PKG_CONFIG_VERSION} \
    && ./configure \
    && make -j $(nproc) && make install \
    && pkg-config --version \
    && rm -rf /build

# nasm
RUN set -ex \
    && NASM_VERSION="2.15.02" \
    && curl -fLO https://www.nasm.us/pub/nasm/releasebuilds/${NASM_VERSION}/nasm-${NASM_VERSION}.tar.gz \
    && tar xvf nasm-${NASM_VERSION}.tar.gz \
    && cd nasm-${NASM_VERSION} \
    && ./configure \
    && make -j $(nproc) && make install \
    && nasm --version \
    && rm -rf /build


################
# Dependencies #
################

FROM build-tools AS build-deps

# x265
RUN set -ex \
    && X265_VERSION="3.5" \
    && curl -fLO https://bitbucket.org/multicoreware/x265_git/downloads/x265_${X265_VERSION}.tar.gz \
    && tar xvf x265_${X265_VERSION}.tar.gz \
    && cd x265_${X265_VERSION} \
    && cmake -DCMAKE_INSTALL_PREFIX=/usr -G "Unix Makefiles" ./source \
    && make -j $(nproc) && make install && ldconfig \
    && rm -rf /build

# libde265
RUN set -ex \
    && LIBDE265_VERSION="1.0.8" \
    && curl -fLO https://github.com/strukturag/libde265/releases/download/v${LIBDE265_VERSION}/libde265-${LIBDE265_VERSION}.tar.gz \
    && tar xvf libde265-${LIBDE265_VERSION}.tar.gz \
    && cd libde265-${LIBDE265_VERSION} \
    && ./autogen.sh \
    && ./configure --prefix /usr --disable-encoder --disable-dec265 --disable-sherlock265 --disable-dependency-tracking \
    && make -j $(nproc) && make install && ldconfig \
    && rm -rf /build

# libaom
RUN set -ex \
    && LIBAOM_VERSION="v3.2.0" \
    && mkdir -v aom && mkdir -v aom_build && cd aom \
    && curl -fLO "https://aomedia.googlesource.com/aom/+archive/${LIBAOM_VERSION}.tar.gz" \
    && tar xvf ${LIBAOM_VERSION}.tar.gz \
    && cd ../aom_build \
    && MINIMAL_INSTALL="-DENABLE_TESTS=0 -DENABLE_TOOLS=0 -DENABLE_EXAMPLES=0 -DENABLE_DOCS=0" \
    && cmake $MINIMAL_INSTALL -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_INSTALL_LIBDIR=lib -DBUILD_SHARED_LIBS=1 ../aom \
    && make -j $(nproc) && make install && ldconfig \
    && rm -rf /build

# libheif
RUN set -ex \
    && LIBHEIF_VERSION="1.12.0" \
    && curl -fLO https://github.com/strukturag/libheif/releases/download/v${LIBHEIF_VERSION}/libheif-${LIBHEIF_VERSION}.tar.gz \
    && tar xvf libheif-${LIBHEIF_VERSION}.tar.gz \
    && cd libheif-${LIBHEIF_VERSION} \
    && ./configure --prefix /usr --disable-examples \
    && make -j $(nproc) && make install && ldconfig \
    && rm -rf /build


##########################
# Build manylinux wheels #
##########################

FROM build-deps AS repaired

COPY ./ /pyheif

RUN /opt/python/cp36-cp36m/bin/pip wheel /pyheif
RUN /opt/python/cp37-cp37m/bin/pip wheel /pyheif
RUN /opt/python/cp38-cp38/bin/pip wheel /pyheif
RUN /opt/python/cp39-cp39/bin/pip wheel /pyheif
RUN /opt/python/cp310-cp310/bin/pip wheel /pyheif
RUN /opt/python/cp311-cp311/bin/pip wheel /pyheif
RUN /opt/python/pp37-pypy37_pp73/bin/pip wheel /pyheif
RUN /opt/python/pp38-pypy38_pp73/bin/pip wheel /pyheif
RUN auditwheel repair pyheif*.whl --plat $PLAT -w /wheelhouse


###############
# Test wheels #
###############

FROM base AS tested

COPY ./requirements-test.txt /tmp/requirements-test.txt

RUN /opt/python/cp36-cp36m/bin/pip install -r /tmp/requirements-test.txt
RUN /opt/python/cp37-cp37m/bin/pip install -r /tmp/requirements-test.txt
RUN /opt/python/cp38-cp38/bin/pip install -r /tmp/requirements-test.txt
RUN /opt/python/cp39-cp39/bin/pip install -r /tmp/requirements-test.txt
RUN /opt/python/cp310-cp310/bin/pip install -r /tmp/requirements-test.txt
RUN /opt/python/cp311-cp311/bin/pip install -r /tmp/requirements-test.txt
RUN /opt/python/pp37-pypy37_pp73/bin/pip install -r /tmp/requirements-test.txt
# RUN /opt/python/pp38-pypy38_pp73/bin/pip install -r /tmp/requirements-test.txt

COPY --from=repaired /wheelhouse /wheelhouse
COPY ./ /pyheif
WORKDIR /pyheif

# python 3.6
RUN set -ex \
    && PNV="/opt/python/cp36-cp36m/bin" \
    && $PNV/pip install /wheelhouse/*-cp36-cp36m-*.whl \
    && $PNV/pytest
# python 3.7
RUN set -ex \
    && PNV="/opt/python/cp37-cp37m/bin" \
    && $PNV/pip install /wheelhouse/*-cp37-cp37m-*.whl \
    && $PNV/pytest
# python 3.8
RUN set -ex \
    && PNV="/opt/python/cp38-cp38/bin" \
    && $PNV/pip install /wheelhouse/*-cp38-cp38-*.whl \
    && $PNV/pytest
# python 3.9
RUN set -ex \
    && PNV="/opt/python/cp39-cp39/bin" \
    && $PNV/pip install /wheelhouse/*-cp39-cp39-*.whl \
    && $PNV/pytest
# python 3.10
RUN set -ex \
    && PNV="/opt/python/cp310-cp310/bin" \
    && $PNV/pip install /wheelhouse/*-cp310-cp310-*.whl \
    && $PNV/pytest
# python 3.11
RUN set -ex \
    && PNV="/opt/python/cp311-cp311/bin" \
    && $PNV/pip install /wheelhouse/*-cp311-cp311-*.whl \
    && $PNV/pytest    
# pypy 3.7
RUN set -ex \
    && PNV="/opt/python/pp37-pypy37_pp73/bin/" \
    && $PNV/pip install /wheelhouse/*-pp37-pypy37_pp73-*.whl \
    && $PNV/pytest
# No Pillow wheels for pypy 3.8
# # pypy 3.8
# RUN set -ex \
#     && PNV="/opt/python/pp38-pypy38_pp73/bin/" \
#     && $PNV/pip install /wheelhouse/*-pp38-pypy38_pp73-*.whl \
#     && $PNV/pytest


#################
# Upload wheels #
#################

FROM tested AS uploaded

ARG PYPI_USERNAME
ARG PYPI_PASSWORD
RUN set -ex \
    && cd "/opt/python/cp38-cp38/bin/" \
    && ./pip install twine \
    && ./twine upload /wheelhouse/*manylinux2014*.whl -u ${PYPI_USERNAME} -p ${PYPI_PASSWORD} \
