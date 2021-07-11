FROM alpine:latest

RUN set -x \
    && apk add --no-cache \
        bash \
        rsync

COPY container/ /
RUN chmod +x /backup-cleanup.sh

ENTRYPOINT [ "/backup-cleanup.sh" ]
