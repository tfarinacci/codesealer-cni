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

.PHONY: run-unit-tests
run-unit-tests:
	go test ./... -tags=unit

.PHONY: run-e2e-tests
run-e2e-tests:
	go test ./... -tags=integration

# .PHONY: push
push: push-codesealer-cni
