package application.policy

import rego.v1
import data.diamond.policy.can_read_from_session

# METADATA
# description: 'Allow a user to access their own data'
# entrypoint: true
default allow := false

allow if {
	can_read_from_session(input.parsed_path[0], input.parsed_path[1])
}
