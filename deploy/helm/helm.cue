package helm

import (
	"alpha.dagger.io/dagger"
	"alpha.dagger.io/dagger/op"
	"strconv"
	"alpha.dagger.io/kubernetes"
)

#Deploy: {
	// Ingress host name
	ingressHostName: dagger.#Input & {string}

	// Ghcr name
	ghcrName: dagger.#Input & {string}

	// Ghcr password
	ghcrPassword: dagger.#Input & {dagger.#Secret}

	//Release name
	releaseName: dagger.#Input & {string}

	// Github SSH private key
	// sshDir: dagger.#Artifact @dagger(input)

	// Helm chart path
	helmPath: dagger.#Input & {string}

	// Git repo url
	repoUrl: dagger.#Input & {string}

	// Cluster kubeconfig
    myKubeconfig: dagger.#Input & {dagger.#Secret}

	// Deploy namespace
	namespace: dagger.#Input & {string}

	// TODO default repoDir path, now you can set "." with dagger dir type
	sourceCodeDir: dagger.#Artifact @dagger(input)

	// Wait for
	waitFor: *null | dagger.#Artifact
    
    // Application URL
	install: {
		string

		#up: [
			op.#FetchContainer & {
				ref: "docker.io/lyzhang1999/ubuntu:latest"
			},

			op.#Exec & {
                mount: "/run/secrets/github": secret: ghcrPassword
				mount: "/root": from:             sourceCodeDir
				if (myKubeconfig & dagger.#Secret) != _|_ {
					mount: "/kubeconfig": secret: myKubeconfig
				}
				if waitFor != null {
					mount: "/waitfor": from: waitFor
				}
				dir: "/"
				env: {
					REPO_URL:        repoUrl
					HELM_PATH:       helmPath
					RELEASE_NAME:    releaseName
					NAMESPACE:       namespace
					GHCRNAME:        ghcrName
					INGRESSHOSTNAME: ingressHostName
				}
				args: [
					"/bin/bash",
					"--noprofile",
					"--norc",
					"-eo",
					"pipefail",
					"-c",
					#"""
							# use setup avoid download everytime
							export KUBECONFIG=/kubeconfig
							mkdir /root/.ssh && cp /root/infra/ssh/id_rsa /root/.ssh/id_rsa && chmod 400 /root/.ssh/id_rsa
							GIT_SSH_COMMAND="ssh -vvv -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no" git clone $REPO_URL
							cd $RELEASE_NAME-helm
							kubectl create secret docker-registry h8r-secret \
							--docker-server=ghcr.io \
							--docker-username=$GHCRNAME \
							--docker-password=$(cat /run/secrets/github) \
							--namespace $NAMESPACE \
							-o yaml --dry-run=client | kubectl apply -f -

							# Try delete pending-upgrade helm release
							# https://github.com/helm/helm/issues/4558
							kubectl -n $NAMESPACE delete secret -l name=$RELEASE_NAME,status=pending-upgrade
							kubectl -n $NAMESPACE delete secret -l name=$RELEASE_NAME,status=pending-install

							helm upgrade $RELEASE_NAME . --dependency-update --namespace $NAMESPACE --create-namespace --install --set "ingress.hosts[0].host=$INGRESSHOSTNAME,ingress.hosts[0].paths[0].path=/,ingress.hosts[0].paths[0].pathType=ImplementationSpecific"
							# wait for deployment ready
							kubectl wait --for=condition=available --timeout=600s deployment/$RELEASE_NAME -n $NAMESPACE
							echo $INGRESSHOSTNAME > /end_point.txt
						"""#,
				]
				always: true
			},

			op.#Export & {
				source: "/end_point.txt"
				format: "string"
			},
		]
	} @dagger(output)
}

// Install a Helm chart
#Chart: {

	// Helm deployment name
	name: dagger.#Input & {string}

	// Helm chart to install from source
	chartSource: *null | dagger.#Artifact

	// Helm chart to install from repository
	chart: dagger.#Input & {*null | string}

	// Helm chart repository
	repository: dagger.#Input & {*null | string}

	// Helm values (either a YAML string or a Cue structure)
	values: dagger.#Input & {*null | string}

	// Kubernetes Namespace to deploy to
	namespace: dagger.#Input & {string}

	// Helm action to apply
	action: dagger.#Input & {*"installOrUpgrade" | "install" | "upgrade"}

	// time to wait for any individual Kubernetes operation (like Jobs for hooks)
	timeout: dagger.#Input & {string | *"10m"}

	// if set, will wait until all Pods, PVCs, Services, and minimum number of
	// Pods of a Deployment, StatefulSet, or ReplicaSet are in a ready state
	// before marking the release as successful.
	// It will wait for as long as timeout
	wait: dagger.#Input & {*true | bool}

	// if set, installation process purges chart on fail.
	// The wait option will be set automatically if atomic is used
	atomic: dagger.#Input & {*true | bool}

	// Kube config file
	kubeconfig: dagger.#Input & {string | dagger.#Secret}

	// Helm version
	version: dagger.#Input & {*"3.5.2" | string}

	// Kubectl version
	kubectlVersion: dagger.#Input & {*"v1.19.9" | string}

	// Wait for
	waitFor: *null | dagger.#Artifact

	#up: [
		op.#Load & {
			from: kubernetes.#Kubectl & {
				version: kubectlVersion
			}
		},
		op.#Exec & {
			env: HELM_VERSION: version
			args: [
				"/bin/bash",
				"--noprofile",
				"--norc",
				"-eo",
				"pipefail",
				"-c",
				#"""
					# Install Yarn
					curl -sfL -S https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz | \
					    tar -zx -C /tmp && \
					    mv /tmp/linux-amd64/helm /usr/local/bin && \
					    chmod +x /usr/local/bin/helm
					"""#,
			]
		},
		op.#Mkdir & {
			path: "/helm"
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

		if chart != null {
			op.#WriteFile & {
				dest:    "/helm/chart"
				content: chart
			}
		},
		if values != null {
			op.#WriteFile & {
				dest:    "/helm/values.yaml"
				content: values
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

				if repository != null {
					HELM_REPO: repository
				}
				HELM_NAME:    name
				HELM_ACTION:  action
				HELM_TIMEOUT: timeout
				HELM_WAIT:    strconv.FormatBool(wait)
				HELM_ATOMIC:  strconv.FormatBool(atomic)
			}
			mount: {
				if chartSource != null && chart == null {
					"/helm/chart": from: chartSource
				}
				if (kubeconfig & dagger.#Secret) != _|_ {
					"/kubeconfig": secret: kubeconfig
				}
				if waitFor != null {
					"/waitfor": from: waitFor
				}
			}
		},

		op.#Subdir & {
			dir: "/output"
		},
	]
}