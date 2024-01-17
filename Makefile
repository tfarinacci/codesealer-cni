build-codesealer-install-cni:
	docker build --no-cache -t tfarinacci/codesealer-install-cni:latest -f deployments/kubernetes/Dockerfile .
	# docker buildx build --push --no-cache -t tfarinacci/codesealer-install-cni:latest --platform linux/amd64,linux/arm64 -f deployments/kubernetes/Dockerfile .

push-codesealer-install-cni:
	docker -- push tfarinacci/codesealer-install-cni:latest
	
.PHONY: build
build: build-codesealer-install-cni

.PHONY: generate-certs
generate-certs:
	echo "Generating certs"

.PHONY: push
push: push-codesealer-install-cni

.PHONY: install
install:
	helm install codesealer-cni charts/codesealer-cni --namespace=kube-system

.PHONY: uninstall
uninstall:
	helm uninstall codesealer-cni --namespace=kube-system || truem