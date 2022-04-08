package next

import (
	"dagger.io/dagger/core"
	"universe.dagger.io/bash"
	"universe.dagger.io/docker"
	"strconv"
)

#Create: {
	// Next Application name
	name: string

	// use typescript
	typescript: bool | *true

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
				always:  false
				env: {
					APP_NAME:   name
					TYPESCRIPT: strconv.FormatBool(typescript)
				}
				script: contents: #"""
					OPTS=""
					[ "$TYPESCRIPT" = "true" ] && OPTS="$OPTS --typescript"
					echo "$APP_NAME" | yarn create next-app $OPTS
					"""#
			},
			docker.#Copy & {
				contents: dockerfile.output
				dest:     "/root/" + name + "/"
			},
		]
	}
	output: run.output
}