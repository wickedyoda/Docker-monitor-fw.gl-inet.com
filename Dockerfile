FROM alpine:latest

RUN apk add --no-cache bash curl coreutils

WORKDIR /app
COPY monitor.sh /app/monitor.sh
COPY wrapper.sh /app/wrapper.sh
RUN chmod +x /app/monitor.sh /app/wrapper.sh

VOLUME ["/data"]

CMD ["sh", "-c", "while true; do /app/monitor.sh; sleep ${CHECK_INTERVAL:-21600}; done"]
