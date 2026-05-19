FROM fnproject/node:20-dev as build-stage
WORKDIR /function
ADD package.json /function/
RUN npm install  && chown -R $(id -u):$(id -g) node_modules
FROM fnproject/node:20
WORKDIR /function
ADD . /function/
COPY --from=build-stage /function/node_modules/ /function/node_modules/
RUN microdnf install -y sshpass openssh-clients \
	&& microdnf clean all
RUN chmod -R o+r /function
RUN chmod +x /function/connection-test.sh
RUN chmod +x /function/lockton.source.env
ENTRYPOINT ["node", "func.js"]
