package helm

import (
	"alpha.dagger.io/dagger"
	"alpha.dagger.io/dagger/op"
	"alpha.dagger.io/alpine"
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

	// TODO Kubeconfig path, set infra/kubeconfig and fill kubeconfig to infra/kubeconfig/config.yaml file
	kubeconfigPath: dagger.#Input & {string}

	// Deploy namespace
	namespace: dagger.#Input & {string}

	// TODO default repoDir path, now you can set "." with dagger dir type
	sourceCodeDir: dagger.#Artifact @dagger(input)
    
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
							export KUBECONFIG=/root/infra/kubeconfig/config.yaml
							mkdir /root/.ssh && cp /root/infra/ssh/id_rsa /root/.ssh/id_rsa && chmod 400 /root/.ssh/id_rsa
							GIT_SSH_COMMAND="ssh -vvv -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no" git clone $REPO_URL
							cd $RELEASE_NAME-helm
							kubectl create secret docker-registry h8r-secret \
							--docker-server=ghcr.io \
							--docker-username=$GHCRNAME \
							--docker-password=$(cat /run/secrets/github) \
							-o yaml --dry-run=client | kubectl apply -f -
							helm upgrade $RELEASE_NAME . --dependency-update --namespace $NAMESPACE --install --set "ingress.hosts[0].host=$INGRESSHOSTNAME,ingress.hosts[0].paths[0].path=/,ingress.hosts[0].paths[0].pathType=ImplementationSpecific"
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