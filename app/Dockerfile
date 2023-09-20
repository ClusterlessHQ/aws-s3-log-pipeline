FROM azul/zulu-openjdk-alpine:11-jre

RUN apk add jq bash --no-cache

RUN wget https://github.com/ClusterlessHQ/tessellate/releases/download/v1.0-wip-31/tessellate-1.0-wip-31.zip -P /opt \
    && unzip /opt/tessellate-*.zip -d /opt \
    && rm /opt/tessellate-*.zip \
    && mv /opt/tessellate-* /opt/tessellate

WORKDIR /app

COPY . .

# ENTRYPOINT ["/app/tess-ingest.sh"]
