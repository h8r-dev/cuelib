package react

import (
	"dagger.io/dagger"
	"universe.dagger.io/bash"
	"universe.dagger.io/docker"
)

#ReactRepo: {
    // React Application name
    name: string
    base: docker.#Pull & {
        source: "index.docker.io/node:lts-stretch"
    }

	run: bash.#Run & {
		input: base.output
		workdir: "/root"
		always:  true
		env: {
			APP_NAME: name
		}
		script: contents: #"""
            npx create-react-app $APP_NAME
        """#
    }

    output: run.output
}
