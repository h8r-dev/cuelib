package main

import (
	"dagger.io/dagger"
	"dagger.io/dagger/core"
)

dagger.#Plan & {
	client: env: {
		APP_NAME:     string
		ORGANIZATION: string
		GITHUB_TOKEN: dagger.#Secret
	}

	actions: {
		test: {
			applicationName: client.env.APP_NAME
			accessToken:     client.env.GITHUB_TOKEN
			organization:    client.env.ORGANIZATION

			_source: core.#Source & {
				path: "code"
			}

			initHelmRepo: #InitRepo & {
				suffix:            "-deploy"
				sourceCodePath:    "helm"
				isHelmChart:       "true"
				"applicationName": applicationName
				"accessToken":     accessToken
				"organization":    organization
				sourceCodeDir:     _source.output
			}
		}

		testd: {
			applicationName: client.env.APP_NAME
			accessToken:     client.env.GITHUB_TOKEN
			organization:    client.env.ORGANIZATION

			deleteHelmRepo: #DeleteRepo & {
				suffix:            "-deploy"
				"applicationName": applicationName
				"accessToken":     accessToken
				"organization":    organization
			}
		}
	}
}
