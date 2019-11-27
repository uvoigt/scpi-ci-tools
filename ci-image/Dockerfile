FROM alpine

ARG GIT_BASE_DIR

RUN apk add bash curl jq util-linux zip

ADD src/ /opt/scpi-cli/src
ADD install /opt/scpi-cli
RUN cd /opt/scpi-cli
RUN /opt/scpi-cli/install ${GIT_BASE_DIR}

CMD ["/bin/bash"]