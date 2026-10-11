# alpine:3.22 multi-arch index, resolved 2026-10-11.
# Includes linux/amd64 and linux/arm64. Renovate updates the digest when the tag moves.
# Index digest: sha256:5291449c3df73caf6ed85e649dec1b9e818b39a5d8c871e97afc13e9cd5e8fa8
FROM alpine:3.22@sha256:5291449c3df73caf6ed85e649dec1b9e818b39a5d8c871e97afc13e9cd5e8fa8

RUN apk add --no-cache openssh-client \
    && addgroup -g 1000 ssh \
    && adduser -D -u 1000 -G ssh -h /home/ssh -s /bin/sh ssh \
    && mkdir -p /home/ssh/.ssh /root/.ssh \
    && chmod 700 /home/ssh/.ssh /root/.ssh \
    && chown -R ssh:ssh /home/ssh

COPY profiles/ /etc/ssh/profiles/
COPY entrypoint.sh /usr/local/bin/entrypoint

RUN chmod 755 /usr/local/bin/entrypoint \
    && chmod 644 /etc/ssh/profiles/*

ARG IMAGE_SOURCE=https://github.com/esfahanahanbot/ssh-client-alpine
LABEL org.opencontainers.image.source="${IMAGE_SOURCE}" \
      org.opencontainers.image.title="ssh-client-alpine" \
      org.opencontainers.image.description="OpenSSH client on Alpine, with complete -F profiles for non-interactive CI." \
      org.opencontainers.image.licenses="MIT"

USER ssh
WORKDIR /home/ssh

ENTRYPOINT ["/usr/local/bin/entrypoint"]
CMD ["ssh"]
