package diamond.policy

import future.keywords

# METADATA
# description: 'hello_world only if {"hello": "world"}'
# entrypoint: true
default hello_world := false

hello_world if {
	input.hello == "world"
}
