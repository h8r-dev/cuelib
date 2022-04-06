package react

import (
	"dagger.io/dagger"
	"github.com/h8r-dev/cuelib/framework/react"
)

// for test
dagger.#Plan & {
	client: env: APP_NAME: string

	actions: test: react.#ReactRepo & {
		name: client.env.APP_NAME
	}
}
