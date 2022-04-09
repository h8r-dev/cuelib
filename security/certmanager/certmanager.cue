package certmanager

import (
	"github.com/h8r-dev/cuelib/deploy/helm"
	"universe.dagger.io/bash"
	"universe.dagger.io/docker"
	"dagger.io/dagger"

)

#InstallCertManager: {
	kubeconfig: dagger.#Secret

	install: helm.#Chart & {
		name:         "cert-manager"
		repository:   "https://charts.jetstack.io"
		chart:        "cert-manager"
		namespace:    "cert-manager"
		set:          "installCRDs=false"
		chartVersion: "v1.8.0"
		"kubeconfig": kubeconfig
	}

	base: docker.#Pull & {
		source: "index.docker.io/alpine/k8s:1.22.6"
	}

	installCrd: bash.#Run & {
		input: base.output
		mounts: "kubeconfig": {
			dest:     "/root/.kube/config"
			contents: kubeconfig
		}
		script: contents: "kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.8.0/cert-manager.crds.yaml"
	}
}

#ACMEIssuer: {

}

#ACMECert: {

}
