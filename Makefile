.PHONY: cluster deploy config argocd test smoke destroy deploy-public deploy-remote

CLUSTER ?= observability
FLUENTD_IMAGE ?= fluentd-loki:1.0.0

cluster:            ## Crée un cluster kind local et les namespaces
	kind create cluster --name $(CLUSTER)
	cd terraform && terraform init && terraform apply -auto-approve

image-local:        ## Construit et charge l'image Fluentd dans Kind
	docker build -t $(FLUENTD_IMAGE) fluentd
	kind load docker-image $(FLUENTD_IMAGE) --name $(CLUSTER)

deploy: image-local  ## Installe Prometheus, Loki et Fluentd (Helmfile)
	helmfile sync

config:             ## Applique Fluentd, datasources, dashboards, alertes et app de démo
	for d in fluentd grafana/datasources grafana/dashboards alerts/loki apps/demo; do kubectl apply -k $$d; done
	kubectl apply -f alerts/prometheus -f alerts/alertmanager

argocd:             ## Mode GitOps : applique l'application racine (après installation d'ArgoCD)
	kubectl apply -f argocd/root-app.yaml

test:               ## Valide et teste les règles d'alerte
	python3 scripts/extract-rules.py alerts/prometheus alerts/rules-extracted
	promtool check rules alerts/rules-extracted/*.rules.yaml
	promtool test rules alerts/tests/*_test.yaml

smoke:              ## Test de fumée post-déploiement
	./scripts/smoke-test.sh

destroy:
	kind delete cluster --name $(CLUSTER)

deploy-public:      ## Démo en ligne (sur le serveur k3s) : voir docs/DEPLOY.md
	./scripts/deploy-public.sh

deploy-remote:      ## Déploie sur k3s distant sans domaine ni TLS
	./scripts/deploy-remote.sh
