package react

import (
	"dagger.io/dagger/core"
	"universe.dagger.io/bash"
	"universe.dagger.io/docker"
)

#ReactRepo: {
	// React Application name
	name: string

	dockerfile: core.#Source & {
		path: "dockerfile"
	}

	base: docker.#Pull & {
		source: "index.docker.io/node:lts-stretch"
	}

	run: docker.#Build & {
		steps: [
			bash.#Run & {
				input:   base.output
				workdir: "/root"
				always:  true
				env: APP_NAME: name
				script: contents: #"""
					npx create-react-app $APP_NAME
					"""#
			},
			docker.#Copy & {
				contents: dockerfile.output
				dest:     "/root/" + name + "/"
			}
		]
	}
	output: run.output
}
