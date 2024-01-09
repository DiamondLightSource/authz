package application.policy_test

import rego.v1
import data.application.policy.allow

example_sessions := {"user": [[0, 0]]}

example_profile := {"sub": "user"}

test_parse if {
	allow with input as {"parsed_path": [0, 0]}
    with data.diamond.data.users.sessions as example_sessions
    with data.diamond.policy.profile as example_profile
}
