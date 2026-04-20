FROM alpine:latest

COPY .*.env ./etc
RUN mkdir /etc/cert 
COPY cert/* ./etc/cert
COPY ftp-bridge.sh ./bin
RUN chmod a+x /bin/ftp-bridge.sh
RUN mkdir /tmp/ftp-bridge

# Install dependencies
RUN apk update
RUN apk add --no-cache sshpass openssh

ENTRYPOINT [ "/bin/ftp-bridge.sh" ]
CMD [ "--source", "/etc/.ftp-bridge.source.env", "--target", "/etc/.ftp-bridge.target.env" ]