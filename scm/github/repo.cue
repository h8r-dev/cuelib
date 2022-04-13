package github

import (
	"dagger.io/dagger"
	"dagger.io/dagger/core"
	"universe.dagger.io/alpine"
	"universe.dagger.io/bash"
	"universe.dagger.io/docker"
)

#DeleteRepo: {
	// Application name, will be set as repo name
	applicationName: string

	// Suffix
	suffix: *"" | string

	accessToken: dagger.#Secret

	organization: string

	base: alpine.#Build & {
		packages: {
			bash: {}
			curl: {}
		}
	}

	run: bash.#Run & {
		input:  base.output
		always: true
		env: GITHUB_TOKEN: accessToken
		script: contents:  #"""
		curl -sSH "Authorization: token $GITHUB_TOKEN" -XDELETE  https://api.github.com/repos/\#(organization)/\#(applicationName)\#(suffix)
		"""#
	}
}

#InitRepo: {

	// Application name, will be set as repo name
	applicationName: string

	// Suffix
	suffix: *"" | string

	// Github personal access token, and will also use to pull ghcr.io image
	accessToken: dagger.#Secret

	// Github organization name or username
	organization: string

	// Source code path, for example code/go-gin
	sourceCodePath: string

	sourceCodeDir: dagger.#FS

	// Helm chart
	isHelmChart: string | *"false"

	base: docker.#Build & {
		steps: [
			alpine.#Build & {
				packages: {
					bash: {}
					curl: {}
					wget: {}
					"github-cli": {}
					git: {}
					jq: {}
				}
			},
			docker.#Copy & {
				contents: sourceCodeDir
				dest:     "/root"
			},
		]
	}

	_loadScripts: core.#Source & {
		path: "./scripts",
		include: ["*.sh"]
	}

	run: bash.#Run & {
		input: base.output
		export: files: "/create.json": _
		workdir: "/root"
		always:  true
		env: {
			GITHUB_TOKEN:     accessToken
			APPLICATION_NAME: applicationName
			SUFFIX:           suffix
			ORGANIZATION:     organization
			SOURCECODEPATH:   sourceCodePath
			ISHELMCHART:      isHelmChart
		}
		script: {
			directory: _loadScripts.output
			filename: "install-repos.sh"
		}
	}

	readFile: core.#ReadFile & {
		input: run.output.rootfs
		path:  "/create.json"
	}

	url: readFile.contents
}
