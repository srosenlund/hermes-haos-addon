FROM docker.io/nousresearch/hermes-agent:latest
COPY run-addon.sh /run-addon.sh
RUN chmod +x /run-addon.sh
ENTRYPOINT ["/init", "/run-addon.sh"]
