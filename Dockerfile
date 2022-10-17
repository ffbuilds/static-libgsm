
# bump: libgsm /LIBGSM_COMMIT=([[:xdigit:]]+)/ gitrefs:https://github.com/timothytylee/libgsm.git|re:#^refs/heads/master$#|@commit
# bump: libgsm after ./hashupdate Dockerfile LIBGSM $LATEST
# bump: libgsm link "Changelog" https://github.com/timothytylee/libgsm/blob/master/ChangeLog
ARG LIBGSM_URL="https://github.com/timothytylee/libgsm.git"
ARG LIBGSM_COMMIT=98f1708fb5e06a0dfebd58a3b40d610823db9715

# Must be specified
ARG ALPINE_VERSION

FROM alpine:${ALPINE_VERSION} AS base

FROM base AS download
ARG LIBGSM_URL
ARG LIBGSM_COMMIT
WORKDIR /tmp
RUN \
  apk add --no-cache --virtual download \
    git && \
  git clone "$LIBGSM_URL" && \
  cd libgsm && git checkout $LIBGSM_COMMIT && \
  apk del download

FROM base AS build
COPY --from=download /tmp/libgsm/ /tmp/libgsm/
WORKDIR /tmp/libgsm
ARG CFLAGS="-O3 -s -static-libgcc -fno-strict-overflow -fstack-protector-all -fPIC"
RUN \
  apk add --no-cache --virtual build \
    build-base && \
  # Makefile is garbage, hence use specific compile arguments and flags
  # no need to build toast cli tool \
  rm src/toast* && \
  SRC=$(echo src/*.c) && \
  gcc ${CFLAGS} -c -ansi -pedantic -s -DNeedFunctionPrototypes=1 -Wall -Wno-comment -DSASR -DWAV49 -DNDEBUG -I./inc ${SRC} && \
  ar cr libgsm.a *.o && ranlib libgsm.a && \
  mkdir -p /usr/local/include/gsm && \
  cp inc/*.h /usr/local/include/gsm && \
  cp libgsm.a /usr/local/lib && \
  # Sanity tests
  ar -t /usr/local/lib/libgsm.a && \
  readelf -h /usr/local/lib/libgsm.a && \
  # Cleanup
  apk del build

FROM scratch
ARG LIBGSM_COMMIT
COPY --from=build /usr/local/lib/libgsm.a /usr/local/lib/libgsm.a
COPY --from=build /usr/local/include/gsm/ /usr/local/include/gsm/
