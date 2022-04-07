package h8r

import (
	"dagger.io/dagger"
	"github.com/h8r-dev/cuelib/h8r/h8r"
	"github.com/h8r-dev/cuelib/utils/random"
)

dagger.#Plan & {
	_uri: random.#String
	actions: test: h8r.#CreateH8rIngress & {
		name:   "just-a-test-" + _uri.output
		host:   "1.1.1.1"
		domain: _uri.output + ".foo.bar"
		port:   "80"
	}
}
