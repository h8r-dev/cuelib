package kubectl

import (
	"alpha.dagger.io/dagger"
	"alpha.dagger.io/dagger/op"
	"alpha.dagger.io/kubernetes"
)

#GetKubectlOutput: {
	// Kube config file
	kubeconfig: dagger.#Input & {dagger.#Secret}

	// Code
	runCode: string
	
	get: {
		string

		#up: [
			op.#Load & {
				from: kubernetes.#Kubectl
			},

			op.#WriteFile & {
				dest:    "/entrypoint.sh"
				content: runCode
			},

			op.#Exec & {
				always: true
				args: [
					"/bin/bash",
					"--noprofile",
					"--norc",
					"-eo",
					"pipefail",
					"cat /entrypoint.sh",
				]
				env: {
					KUBECONFIG:     "/kubeconfig"
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