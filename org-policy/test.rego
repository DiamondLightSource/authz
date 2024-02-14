package diamond.policy

import rego.v1

# METADATA
# description: 'hello_world only if {"hello": "world"}'
# entrypoint: true
default hello_world := false

hello_world if {
	input.hello == "world"
}
