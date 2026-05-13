FROM alpine:latest

COPY .*.env ./etc
RUN mkdir /etc/cert 
COPY cert/* ./etc/cert
RUN mkdir /tmp/ftp-bridge

# Copy additional scripts to bin and make them executable
COPY ftp-bridge.sh ./bin
RUN chmod a+x /bin/ftp-bridge.sh

COPY connection-test.sh ./bin
RUN chmod a+x /bin/connection-test.sh

# Install dependencies
RUN apk update
RUN apk add --no-cache sshpass openssh

ENTRYPOINT [ "/bin/connection-test.sh" ]
CMD [ "--server", "/etc/.ftp-bridge.target.env" ]

# ENTRYPOINT [ "/bin/ftp-bridge.sh" ]
# CMD [ "--source", "/etc/.ftp-bridge.source.env", "--target", "/etc/.ftp-bridge.target.env" ]