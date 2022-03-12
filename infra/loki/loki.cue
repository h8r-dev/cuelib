package loki

import (
	"alpha.dagger.io/dagger"
	"alpha.dagger.io/dagger/op"
	"alpha.dagger.io/kubernetes"
)

#GetLokiSecret: {
	// Kube config file
	kubeconfig: dagger.#Input & {dagger.#Secret}

	// Namespace
	namespace: string | *"monitoring"

	// Secret Name
	secretName: string

	#code: #"""
	while ! kubectl get secret/$SECRET_NAME -n $KUBE_NAMESPACE; do sleep 5; done
	secret=$(kubectl get secret --namespace $KUBE_NAMESPACE $SECRET_NAME -o jsonpath='{.data.admin-password}' | base64 -d ; echo)
	echo $secret > /result
	"""#

	// Grafana secret, password of admin user
	get: {
		string

		#up: [
			op.#Load & {
				from: kubernetes.#Kubectl
			},

			op.#WriteFile & {
				dest:    "/entrypoint.sh"
				content: #code
			},

			op.#Exec & {
				always: true
				args: [
					"/bin/bash",
					"--noprofile",
					"--norc",
					"-eo",
					"pipefail",
					"/entrypoint.sh",
				]
				env: {
					KUBECONFIG:     "/kubeconfig"
					KUBE_NAMESPACE: namespace
					SECRET_NAME: secretName
				}
				if (kubeconfig & dagger.#Secret) != _|_ {
					mount: "/kubeconfig": secret: kubeconfig
				}
			},

			op.#Export & {
				source: "/result"
				format: "string"
			},
		]
	} @dagger(output)
}