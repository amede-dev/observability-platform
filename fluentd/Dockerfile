FROM fluent/fluentd:v1.17-debian-1

USER root
# fluent-plugin-kubernetes_metadata_filter dépend de ffi et compile une
# extension native ; l'image Fluentd de base ne fournit pas gcc/libffi.
RUN apt-get update \
 && apt-get install -y --no-install-recommends build-essential libffi-dev \
 && rm -rf /var/lib/apt/lists/*

RUN gem install --no-document \
      fluent-plugin-kubernetes_metadata_filter \
      fluent-plugin-grafana-loki \
      fluent-plugin-prometheus \
 && gem sources --clear-all

USER fluent
