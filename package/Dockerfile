FROM registry.suse.com/bci/bci-micro:16.1 AS micro

FROM registry.suse.com/bci/bci-base:16.1 AS builder

COPY --from=micro / /rootfs
RUN zypper --installroot /rootfs --non-interactive --gpg-auto-import-keys install sqlite3 awk which grep findutils bash && \
    zypper --installroot /rootfs --non-interactive clean -a && \
    rm -rf /rootfs/var/cache/zypp/* /rootfs/usr/share/doc /rootfs/usr/share/man /rootfs/usr/share/info

FROM registry.suse.com/bci/bci-micro:16.1
COPY --from=builder /rootfs /
COPY bin/safe-sqlite-copy.sh /usr/local/bin/safe-sqlite-copy.sh
RUN chmod +x /usr/local/bin/safe-sqlite-copy.sh

ENTRYPOINT ["/usr/bin/sqlite3"]
CMD ["--version"]
