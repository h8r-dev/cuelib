package certmanager

import (
	"dagger.io/dagger"
	"github.com/h8r-dev/cuelib/security/certmanager"
)

// for test
dagger.#Plan & {
	client: {
		env: KUBECONFIG: string
		commands: kubeconfig: {
			name: "cat"
			args: ["\(env.KUBECONFIG)"]
			stdout: dagger.#Secret
		}
	}
	actions: test: certmanager.#InstallCertManager & {
		kubeconfig: client.commands.kubeconfig.stdout
	}
}
