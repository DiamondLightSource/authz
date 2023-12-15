package diamond_test

import data.diamond
import future.keywords

# Recommended pattern for naming:
# Tests for foo.rego are stored in foo_test.rego
# Test cases within *_test.rego are named test_*
# Unfinished test cases to be skipped are named todo_*
# For linter, To format all code in this directory run opa fmt ./* --write

test_default_not_allow if {
	not diamond.allow with input as {}
		with data.sessions as {}
		with data.proposals as {}
}

test_not_allow_without_user if {
	not diamond.allow with input as {"session": 0, "proposal": 0}
		with data.sessions as {"user": [[0, 0]]}
		with data.proposals as {"user": [0]}
}

test_not_allow_without_context if {
	not diamond.allow with input as {"user": 0}
		with data.sessions as {"user": [[0, 0]]}
		with data.proposals as {"user": [0]}
}

test_allow_if_user_on_session if {
	diamond.allow with input as {"user": "user", "session": 0}
		with data.sessions as {"user": [[0, 0]]}
		with data.proposals as {}
}

test_allow_if_user_on_sessions if {
	diamond.allow with input as {"user": "user", "session": 0}
		with data.sessions as {"user": [[0, 0], [1, 0]]}
		with data.proposals as {}
}

test_allow_if_user_on_proposal if {
	diamond.allow with input as {"user": "user", "proposal": 0}
		with data.sessions as {}
		with data.proposals as {"user": [0]}
}

test_allow_if_user_on_proposals if {
	diamond.allow with input as {"user": "user", "proposal": 0}
		with data.sessions as {}
		with data.proposals as {"user": [0, 1]}
}

test_disallow_if_user_not_on_session if {
	not diamond.allow with input as {"user": "user", "session": 0}
		with data.sessions as {"user2": [[0, 0]]}
		with data.proposals as {}
}

test_disallow_if_user_not_on_proposal if {
	not diamond.allow with input as {"user": "user", "proposal": 0}
		with data.sessions as {}
		with data.proposals as {"user2": [0]}
}

test_disallow_if_user_not_on_proposal_nor_session if {
	not diamond.allow with input as {"user": "user", "proposal": 0, "session": 0}
		with data.sessions as {"user2": [[0, 0]]}
		with data.proposals as {"user2": [0]}
}

test_allow_if_user_on_proposal_and_session if {
	diamond.allow with input as {"user": "user", "proposal": 0, "session": 0}
		with data.sessions as {"user": [[0, 0]]}
		with data.proposals as {"user": [0]}
}

test_allow_if_user_on_proposal_not_session if {
	diamond.allow with input as {"user": "user", "proposal": 0, "session": 0}
		with data.sessions as {"user2": [[0, 0]]}
		with data.proposals as {"user": [0]}
}

test_allow_if_user_on_session_not_proposal if {
	diamond.allow with input as {"user": "user", "proposal": 0, "session": 0}
		with data.sessions as {"user": [[0, 0]]}
		with data.proposals as {"user2": [0]}
}
