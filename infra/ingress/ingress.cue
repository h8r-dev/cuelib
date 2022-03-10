package ingress

import (
    "alpha.dagger.io/dagger"
	"alpha.dagger.io/dagger/op"
	"encoding/yaml"
	"alpha.dagger.io/kubernetes"
	"strings"
)

#Ingress: {
	// and generate selectors.
	name: string

	// Namespace to deploy
	namespace: string | *"default"

	// Class name.
	className: string

	// Host name
	hostName: string

	// Path
	path: string

	// Service name
	backendServiceName: string

	// 80 is the default port.
	backendServicePort: int | *80

	// cluster version, such v1, v1beta1
	ingressVersion: string

	// Ingress manifest
	// generate the resource manifest.
	
	manifest: {
		if strings.TrimSpace(ingressVersion) == "v1" {
			apiVersion: "networking.k8s.io/v1"
			kind:       "Ingress"
			metadata: {
				"name": name
				"namespace": namespace
				annotations: {
					"h8r": "true"
					"host": hostName
				}
			}
			spec: {
				"ingressClassName": "nginx"
				rules: [{
					host:  hostName
					http: paths: [{
						"path": path
						pathType: "Prefix"
						backend: {
							service: {
								"name": backendServiceName
								port: {
									"number": backendServicePort
								}
							}
						}
					}]
				}]
			}
		}
		if strings.TrimSpace(ingressVersion) == "v1beta1" {
			apiVersion: "networking.k8s.io/v1beta1"
			kind:       "Ingress"
			metadata: {
				"name": name
				"namespace": namespace
				annotations: {
					"h8r": "true"
					"host": hostName
					"kubernetes.io/ingress.class": "nginx"
				}
			}
			spec: {
				rules: [{
					host:  hostName
					http: paths: [{
						"path": path
						pathType: "Prefix"
						backend: {
							serviceName: backendServiceName
							servicePort: backendServicePort
						}
					}]
				}]
			}
		}
	}
	
	// MarshalStream
	manifestStream: yaml.MarshalStream([manifest])
}

#GetIngressEndpoint: {
	// Kube config file
	kubeconfig: dagger.#Input & {dagger.#Secret}

	// namespace
	namespace: dagger.#Input & {string | *"ingress-nginx"}

	#code: #"""
		while ! kubectl get ns $KUBE_NAMESPACE; do sleep 1; done
		while ! kubectl get svc/ingress-nginx-controller -n $KUBE_NAMESPACE; do sleep 1; done
		external_ip=""; while [ -z $external_ip ]; do echo "Waiting for end point..."; external_ip=$(kubectl get svc ingress-nginx-controller --namespace $KUBE_NAMESPACE --template="{{range .status.loadBalancer.ingress}}{{.ip}}{{end}}"); [ -z "$external_ip" ] && sleep 1; done; echo "End point ready-" && echo $external_ip; export endpoint=$external_ip
		#kubectl get services --namespace $KUBE_NAMESPACE ingress-nginx-controller --output jsonpath='{.status.loadBalancer.ingress[0].ip}' > /endpoint
		echo $endpoint | awk '$1=$1' > /endpoint
		"""#

	// Ingress nginx endpoint
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
				}
				if (kubeconfig & dagger.#Secret) != _|_ {
					mount: "/kubeconfig": secret: kubeconfig
				}
			},

			op.#Export & {
				source: "/endpoint"
				format: "string"
			},
		]
	} @dagger(output)
}