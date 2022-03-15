package argocd

import(
    "github.com/h8r-dev/cuelib/deploy/kubectl"
    "alpha.dagger.io/alpine"
	"alpha.dagger.io/dagger"
	"alpha.dagger.io/dagger/op"
    "alpha.dagger.io/os"
)

#InstallArgoCD: {
    // Kubeconfig
    kubeconfig: dagger.#Input & {string | dagger.#Secret}

    // Install namespace
    namespace: string

    // Manifest url
    url: string

	// Wait
	waitFor: dagger.#Artifact

    // ArgoCD admin password
    install: {
        string

        #up: [
            op.#Load & {
                from: kubectl.#Resources & {
                    "kubeconfig": kubeconfig
                    "namespace": namespace
                    "url": url
                }
            },

            op.#Exec & {
                if (kubeconfig & dagger.#Secret) != _|_ {
                    mount: "/kubeconfig": secret: kubeconfig
                }
                args: [
                    "/bin/bash",
                    "--noprofile",
                    "--norc",
                    "-eo",
                    "pipefail",
                    "-c",
                    #"""
                        # patch deployment cause ingress redirct: https://github.com/argoproj/argo-cd/issues/2953
                        kubectl patch deployment argocd-server --patch '{"spec": {"template": {"spec": {"containers": [{"name": "argocd-server","command": ["argocd-server", "--insecure"]}]}}}}' -n $NAMESPACE
                        kubectl wait --for=condition=Available deployment argocd-server -n $NAMESPACE --timeout 600s
                        secret=$(kubectl -n $NAMESPACE get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo)
                        echo $secret > /secret
                        """#,
                ]
                env: {
                    KUBECONFIG:     "/kubeconfig"
                    NAMESPACE: namespace
                }
				mount: "/waitfor": from: waitFor
            },
            
            op.#Export & {
                source: "/secret"
                format: "string"
            },
        ]
    } @dagger(output)
}

// ArgoCD configuration
#Config: {
	// ArgoCD CLI binary version
	version: *"v2.3.1" | dagger.#Input & {string}

	// ArgoCD server
	server: dagger.#Input & {string}

	// ArgoCD project
	project: *"default" | dagger.#Input & {string}

	// Basic authentication to login
	basicAuth: {
		// Username
		username: dagger.#Input & {string}

		// Password
		password: dagger.#Input & {string}
	} | *null

	// ArgoCD authentication token
	token: dagger.#Input & {*null | dagger.#Secret}
}

// Re-usable CLI component
#CLI: {
	config: #Config

	#up: [
		op.#Load & {
			from: alpine.#Image & {
				package: bash: true
				package: jq:   true
				package: curl: true
			}
		},

		// Install the ArgoCD CLI
		op.#Exec & {
			args: ["bash", "-c",
				#"""
					curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/download/$VERSION/argocd-linux-amd64 &&
					chmod +x /usr/local/bin/argocd
					"""#,
			]
			env: VERSION: config.version
		},

		if config.basicAuth != null && config.token == null {
			// Login to ArgoCD server
			op.#Exec & {
				args: ["bash", "-c", #"""
					# wait until server ready
					ARGO_PASSWORD=$(echo $ARGO_PASSWORD | xargs)
					echo $ARGO_SERVER'-'$ARGO_PASSWORD'-'$ARGO_USERNAME
					curl --retry 300 --retry-delay 2 $ARGO_SERVER --retry-all-errors --fail --insecure
					argocd login "$ARGO_SERVER" --username "$ARGO_USERNAME" --password "$ARGO_PASSWORD" --insecure --grpc-web
					"""#,
				]
				env: {
					ARGO_SERVER:   config.server
					ARGO_USERNAME: config.basicAuth.username
                    ARGO_PASSWORD: config.basicAuth.password
				}
			}
		},

		if config.token != null && config.basicAuth == null {
			// Write config file
			op.#Exec & {
				args: ["bash", "-c",
					#"""
						mkdir -p ~/.argocd && cat > ~/.argocd/config << EOF
						contexts:
						- name: "$SERVER"
						  server: "$SERVER"
						  user: "$SERVER"
						current-context: "$SERVER"
						servers:
						- grpc-web-root-path: ""
						  server: "$SERVER"
						users:
						- auth-token: $(cat /run/secrets/token)
						  name: "$SERVER"
						EOF
						"""#,
				]
				mount: "/run/secrets/token": secret: config.token
				env: SERVER: config.server
			}
		},

	]
}

// Create an ArgoCD application
#App: {
	// ArgoCD configuration
	config: #Config

	// App name
	name: dagger.#Input & {string}

	// Repository url (git or helm)
	repo: dagger.#Input & {string}

	// Folder to deploy
	path: dagger.#Input & {"." | string}

	// Destination server
	server: dagger.#Input & {*"https://kubernetes.default.svc" | string}

	// Destination namespace
	namespace: dagger.#Input & {*"default" | string}

    // Helm set values, such as "key1=value1,key2=value2"
    helmSet: string | *""

	os.#Container & {
		image: #CLI & {
			"config": config
		}
		command: #"""
				echo $APP_NAME'-'$APP_REPO'-'$APP_PATH'-'$APP_SERVER'-'$APP_NAMESPACE
				APP_REPO=$(echo $APP_REPO | xargs)
				setOps=""
				for i in $(echo $HELM_SET | tr "," "\n")
				do
				setOps="$setOps --helm-set "$i""
				done
				echo $setOps
				argocd app create "$APP_NAME" \
					--repo "$APP_REPO" \
					--path "$APP_PATH" \
					--dest-server "$APP_SERVER" \
					--dest-namespace "$APP_NAMESPACE" \
					--sync-option CreateNamespace=true \
					--sync-policy automated \
					--grpc-web \
					--upsert \
					$setOps
			"""#
		always: true
		env: {
			APP_NAME:      name
			APP_REPO:      repo
			APP_PATH:      path
			APP_SERVER:    server
			APP_NAMESPACE: namespace
            HELM_SET: helmSet
		}
	}
}