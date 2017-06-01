FROM alpine:3.6

RUN adduser -S oauth2proxy \
  && apk --update add curl \
  && curl -sL -o /tmp/release.tgz https://github.com/bitly/oauth2_proxy/releases/download/v2.2/oauth2_proxy-2.2.0.linux-amd64.go1.8.1.tar.gz \
  && tar -xf /tmp/release.tgz -C /bin --strip-components=1 \
  && rm /tmp/release.tgz

USER oauth2proxy

EXPOSE 4180

CMD ["oauth2_proxy"]
