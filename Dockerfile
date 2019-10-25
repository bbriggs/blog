FROM alpine:latest

VOLUME /blog
RUN apk add --no-cache hugo
WORKDIR /blog
EXPOSE 1313
ENTRYPOINT ["hugo"]
CMD ["server", "--bind", "0.0.0.0"]
