
# https://docs.docker.com/registry/
# https://registry.hub.docker.com/_/registry/tags
export REGISTRY_IMAGE=registry:2

# https://quay.io/repository/keycloak/keycloak?tab=tags
export KEYCLOAK_IMAGE=quay.io/keycloak/keycloak:26.7.2

# https://hub.docker.com/r/apache/kafka/tags
export KAFKA_IMAGE=apache/kafka:3.9.0

# https://hub.docker.com/r/dgraph/dgraph/tags
export DGRAPH_IMAGE=dgraph/dgraph:v23.1.1

# https://hub.docker.com/r/dgraph/ratel/tags
export RATEL_IMAGE=dgraph/ratel:v21.03.2

# https://hub.docker.com/_/postgres/tags
export POSTGRESQL_IMAGE=postgres:16-alpine

# https://hub.docker.com/r/haproxytech/haproxy-debian
export HAPROXY_IMAGE=haproxytech/haproxy-debian:2.9

# Javascript runtime image (nodeJs, DenoJs, BunJs, ect ...)
export JAVASCRIPT_RUNTIME=node:18-alpine