package kubectl

import (
	"alpha.dagger.io/dagger"
	"alpha.dagger.io/dagger/op"
	"alpha.dagger.io/kubernetes"
	"alpha.dagger.io/alpine"
)

#WaitFor: {
	// Kube config file
	kubeconfig: dagger.#Input & {dagger.#Secret}

	// Workload type
	worklaod: *"pod" | string

	#runCode: #"""
		while ! kubectl get $WORKLOAD; 
		do
			sleep 3
			echo 'wait for '$WORKLOAD
		done
		mkdir /output
		echo 'OK' > /output/done
		"""#
	
	#up: [
		op.#Load & {
			from: kubernetes.#Kubectl
		},

		op.#WriteFile & {
			dest:    "/entrypoint.sh"
			content: #runCode
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
				WORKLOAD: worklaod
			}
			if (kubeconfig & dagger.#Secret) != _|_ {
				mount: "/kubeconfig": secret: kubeconfig
			}
		},

		op.#Subdir & {
			dir: "/output"
		},
	]
}

#CreateImagePullSecret: {
	// Kube config file
	kubeconfig: dagger.#Input & {dagger.#Secret}

	// Image pull username
	username: string

	// Image pull password
	password: dagger.#Input & {dagger.#Secret}

	// Image pull secret name
	secretName: *"h8r-secret" | string

	// Server url
	server: *"ghcr.io" | string

	// Namespace
	namespace: string

	#runCode: #"""
		kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
		kubectl create secret docker-registry $SECRETNAME \
		--docker-server=$SERVER \
		--docker-username=$USERNAME \
		--docker-password=$(cat /run/secrets/github) \
		--namespace $NAMESPACE \
		-o yaml --dry-run=client | kubectl apply -f -
		mkdir /output
		"""#
	
	#up: [
		op.#Load & {
			from: kubernetes.#Kubectl
		},

		op.#WriteFile & {
			dest:    "/entrypoint.sh"
			content: #runCode
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
				USERNAME: username
				SECRETNAME: secretName
				SERVER: server
				NAMESPACE: namespace
			}
			if (kubeconfig & dagger.#Secret) != _|_ {
				mount: "/kubeconfig": secret: kubeconfig
			}
			mount: "/run/secrets/github": secret: password
		},

		op.#Subdir & {
			dir: "/output"
		},
	]
}

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
					"/entrypoint.sh",
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

// Kubectl client
#Kubectl: {

	// Kubectl version
	version: dagger.#Input & {*"v1.19.9" | string}

	#code: #"""
		[ -e /usr/local/bin/kubectl ] || {
			curl -sfL https://dl.k8s.io/${KUBECTL_VERSION}/bin/linux/amd64/kubectl -o /usr/local/bin/kubectl \
			&& chmod +x /usr/local/bin/kubectl
		}
		"""#

	#up: [
		op.#Load & {
			from: alpine.#Image & {
				package: bash: true
				package: jq:   true
				package: curl: true
			}
		},
		op.#WriteFile & {
			dest:    "/entrypoint.sh"
			content: #code
		},
		op.#Exec & {
			args: [
				"/bin/bash",
				"--noprofile",
				"--norc",
				"-eo",
				"pipefail",
				"/entrypoint.sh",
			]
			env: KUBECTL_VERSION: version
		},
	]
}

// Apply Kubernetes resources
#Resources: {

	// Kubernetes config to deploy
	source: dagger.#Input & {*null | dagger.#Artifact}

	// Kubernetes manifest to deploy inlined in a string
	manifest: dagger.#Input & {*null | string}

	// Kubernetes manifest url to deploy remote configuration
	url: dagger.#Input & {*null | string}

	// Kubernetes Namespace to deploy to
	namespace: dagger.#Input & {*"default" | string}

	// Version of kubectl client
	version: dagger.#Input & {*"v1.19.9" | string}

	// Kube config file
	kubeconfig: dagger.#Input & {string | dagger.#Secret}

	// Wait for
	waitFor: *null | dagger.#Artifact

	#code: #"""
		kubectl create namespace "$KUBE_NAMESPACE"  > /dev/null 2>&1 || true

		if [ -d /source ] || [ -f /source ]; then
			kubectl --namespace "$KUBE_NAMESPACE" apply -R -f /source
			exit 0
		fi

		if [ -n "$DEPLOYMENT_URL" ]; then
			kubectl --namespace "$KUBE_NAMESPACE" apply -R -f "$DEPLOYMENT_URL"
			exit 0
		fi
		"""#

	#up: [
		op.#Load & {
			from: #Kubectl & {"version": version}
		},
		op.#WriteFile & {
			dest:    "/entrypoint.sh"
			content: #code
		},

		if (kubeconfig & string) != _|_ {
			op.#WriteFile & {
				dest:    "/kubeconfig"
				content: kubeconfig
				mode:    0o600
			}
		},

		if manifest != null {
			op.#WriteFile & {
				dest:    "/source"
				content: manifest
			}
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
				if url != null {
					DEPLOYMENT_URL: url
				}
			}
			if manifest == null && source != null {
				mount: "/source": from: source
			}
			if (kubeconfig & dagger.#Secret) != _|_ {
				mount: "/kubeconfig": secret: kubeconfig
			}
			if waitFor != null {
				mount: "/waitfor": from: waitFor
			}
		},
	]
}