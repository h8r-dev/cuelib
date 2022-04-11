package certmanager

import (
	"dagger.io/dagger"
	"github.com/h8r-dev/cuelib/secure/certmanager"
)

// for test
dagger.#Plan & {
	client: {
		env: {
			KUBECONFIG: string
			API_TOKEN:  dagger.#Secret
		}
		commands: kubeconfig: {
			name: "cat"
			args: ["\(env.KUBECONFIG)"]
			stdout: dagger.#Secret
		}
	}
	actions: test: {
		install: certmanager.#InstallCertManager & {
			kubeconfig: client.commands.kubeconfig.stdout
		}

		declareIssuer: certmanager.#ACMEIssuer & {
			kubeconfig: client.commands.kubeconfig.stdout
			email:      "vendor@h8r.io"
			apiToken:   client.env.API_TOKEN
			waitFor:    install.success
		}

		declareCert: certmanager.#ACMECert & {
			kubeconfig: client.commands.kubeconfig.stdout
			waitFor:    declareIssuer.success
			namespace:  "for-test"
			name:       "for-h8r"
			commonName: "heighliner.pro"
			domains: [
				"h8r.app",
				"*.h8r.app",
				"*.go-gin.h8r.app",
			]
		}
	}
}
