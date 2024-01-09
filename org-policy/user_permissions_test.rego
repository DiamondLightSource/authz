package diamond.policy_test

import data.diamond.policy
import rego.v1

example_sessions := {"user": [[0, 0]]}

example_proposals := {"user": [0]}

example_profile := {"sub": "user"}

test_default_not_allow if {
	not policy.user_on_session(0, 0) with policy.profile as {}
	not policy.user_on_proposal(0) with policy.profile as {}
}

test_not_allow_without_user if {
	not policy.user_on_session(0, 0) with data.diamond.data.users.sessions as example_sessions
		with data.diamond.data.users.proposals as example_proposals
		with policy.profile as {}
	not policy.user_on_proposal(0) with data.diamond.data.users.sessions as example_sessions
		with data.diamond.data.users.proposals as example_proposals
		with policy.profile as {}
}

test_not_allow_with_empty_context if {
	not policy.user_on_session(0, 0) with data.diamond.data.users.sessions as {}
		with data.diamond.data.users.proposals as {}
		with policy.profile as example_profile
	not policy.user_on_proposal(0) with data.diamond.data.users.sessions as {}
		with data.diamond.data.users.proposals as {}
		with policy.profile as example_profile
}

test_allow_if_user_on_session if {
	policy.user_on_session(0, 0) with data.diamond.data.users.sessions as example_sessions
		with policy.profile as example_profile
	not policy.user_on_proposal(0) with data.diamond.data.users.sessions as example_sessions
		with policy.profile as example_profile
}

test_allow_if_user_on_sessions if {
	policy.user_on_session(0, 0) with data.diamond.data.users.sessions as {"user": [[0, 0], [1, 0]]}
		with policy.profile as example_profile
	not policy.user_on_proposal(0) with data.diamond.data.users.sessions as {"user": [[0, 0], [1, 0]]}
		with policy.profile as example_profile
}

test_disallow_if_user_not_on_session if {
	not policy.user_on_session(1, 0) with data.diamond.data.users.sessions as example_sessions
		with policy.profile as example_profile
	not policy.user_on_session(0, 1) with data.diamond.data.users.sessions as example_sessions
		with policy.profile as example_profile
	not policy.user_on_session(1, 1) with data.diamond.data.users.sessions as example_sessions
		with policy.profile as example_profile
	not policy.user_on_proposal(0) with data.diamond.data.users.sessions as example_sessions
		with policy.profile as example_profile
}

test_allow_if_user_on_proposal if {
	not policy.user_on_session(0, 0) with data.diamond.data.users.proposals as example_proposals
		with policy.profile as example_profile
	policy.user_on_proposal(0) with data.diamond.data.users.proposals as example_proposals
		with policy.profile as example_profile
}

test_allow_if_user_on_proposals if {
	not policy.user_on_session(0, 0) with data.diamond.data.users.proposals as {"user": [0, 1]}
		with policy.profile as example_profile
	policy.user_on_proposal(0) with data.diamond.data.users.proposals as {"user": [0, 1]}
		with policy.profile as example_profile
}

test_disallow_if_user_not_on_proposal if {
	not policy.user_on_session(0, 0) with data.diamond.data.users.proposals as example_proposals
		with policy.profile as example_profile
	not policy.user_on_proposal(1) with data.diamond.data.users.proposals as example_proposals
		with policy.profile as example_profile
}
