package diamond_test

import data.diamond
import future.keywords

# Recommended pattern for naming:
# Tests for foo.rego are stored in foo_test.rego
# Test cases within *_test.rego are named test_*
# Unfinished test cases to be skipped are named todo_*
# For linter, To format all code in this directory run opa fmt ./* --write

example_session := {"user": [[0, 0]]}

example_proposal := {"user": [0]}

example_profile := {"sub": "user"}

test_default_not_allow if {
	not diamond.user_on_session(0, 0) with diamond.profile as {}
	not diamond.user_on_proposal(0) with diamond.profile as {}
}

test_not_allow_without_user if {
	not diamond.user_on_session(0, 0) with data.diamond.users.sessions as example_session
		with data.diamond.users.proposals as example_proposal
		with diamond.profile as {}
	not diamond.user_on_proposal(0) with data.diamond.users.sessions as example_session
		with data.diamond.users.proposals as example_proposal
		with diamond.profile as {}
}

test_not_allow_with_empty_context if {
	not diamond.user_on_session(0, 0) with data.diamond.users.sessions as {}
		with data.diamond.users.proposals as {}
		with diamond.profile as example_profile
	not diamond.user_on_proposal(0) with data.diamond.users.sessions as {}
		with data.diamond.users.proposals as {}
		with diamond.profile as example_profile
}

test_allow_if_user_on_session if {
	diamond.user_on_session(0, 0) with data.diamond.users.sessions as example_session
		with diamond.profile as example_profile
	not diamond.user_on_proposal(0) with data.diamond.users.sessions as example_session
		with diamond.profile as example_profile
}

test_allow_if_user_on_sessions if {
	diamond.user_on_session(0, 0) with data.diamond.users.sessions as {"user": [[0, 0], [1, 0]]}
		with diamond.profile as example_profile
	not diamond.user_on_proposal(0) with data.diamond.users.sessions as {"user": [[0, 0], [1, 0]]}
		with diamond.profile as example_profile
}

test_disallow_if_user_not_on_session if {
	not diamond.user_on_session(1, 0) with data.diamond.users.sessions as example_session
		with diamond.profile as example_profile
	not diamond.user_on_session(0, 1) with data.diamond.users.sessions as example_session
		with diamond.profile as example_profile
	not diamond.user_on_session(1, 1) with data.diamond.users.sessions as example_session
		with diamond.profile as example_profile
	not diamond.user_on_proposal(0) with data.diamond.users.sessions as example_session
		with diamond.profile as example_profile
}

test_allow_if_user_on_proposal if {
	not diamond.user_on_session(0, 0) with data.diamond.users.proposals as example_proposal
		with diamond.profile as example_profile
	diamond.user_on_proposal(0) with data.diamond.users.proposals as example_proposal
		with diamond.profile as example_profile
}

test_allow_if_user_on_proposals if {
	not diamond.user_on_session(0, 0) with data.diamond.users.proposals as {"user": [0, 1]}
		with diamond.profile as example_profile
	diamond.user_on_proposal(0) with data.diamond.users.proposals as {"user": [0, 1]}
		with diamond.profile as example_profile
}

test_disallow_if_user_not_on_proposal if {
	not diamond.user_on_session(0, 0) with data.diamond.users.proposals as example_proposal
		with diamond.profile as example_profile
	not diamond.user_on_proposal(1) with data.diamond.users.proposals as example_proposal
		with diamond.profile as example_profile
}
