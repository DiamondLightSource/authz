package diamond

import rego.v1

example_sessions := {"user": [[0, 0]]}

example_proposals := {"user": [0]}

example_profile := {"sub": "user"}

test_default_not_allow if {
	not user_on_session(0, 0) with data.diamond.profile as {}
	not user_on_proposal(0) with data.diamond.profile as {}
}

test_not_allow_without_user if {
	not user_on_session(0, 0) with data.diamond.users.sessions as example_sessions
		with data.diamond.users.proposals as example_proposals
		with data.diamond.profile as {}
	not user_on_proposal(0) with data.diamond.users.sessions as example_sessions
		with data.diamond.users.proposals as example_proposals
		with data.diamond.profile as {}
}

test_not_allow_with_empty_context if {
	not user_on_session(0, 0) with data.diamond.users.sessions as {}
		with data.diamond.users.proposals as {}
		with data.diamond.profile as example_profile
	not user_on_proposal(0) with data.diamond.users.sessions as {}
		with data.diamond.users.proposals as {}
		with data.diamond.profile as example_profile
}

test_allow_if_user_on_session if {
	user_on_session(0, 0) with data.diamond.users.sessions as example_sessions
		with data.diamond.profile as example_profile
	not user_on_proposal(0) with data.diamond.users.sessions as example_sessions
		with data.diamond.profile as example_profile
}

test_allow_if_user_on_sessions if {
	user_on_session(0, 0) with data.diamond.users.sessions as {"user": [[0, 0], [1, 0]]}
		with data.diamond.profile as example_profile
	not user_on_proposal(0) with data.diamond.users.sessions as {"user": [[0, 0], [1, 0]]}
		with data.diamond.profile as example_profile
}

test_disallow_if_user_not_on_session if {
	not user_on_session(1, 0) with data.diamond.users.sessions as example_sessions
		with data.diamond.profile as example_profile
	not user_on_session(0, 1) with data.diamond.users.sessions as example_sessions
		with data.diamond.profile as example_profile
	not user_on_session(1, 1) with data.diamond.users.sessions as example_sessions
		with data.diamond.profile as example_profile
	not user_on_proposal(0) with data.diamond.users.sessions as example_sessions
		with data.diamond.profile as example_profile
}

test_allow_if_user_on_proposal if {
	not user_on_session(0, 0) with data.diamond.users.proposals as example_proposals
		with data.diamond.profile as example_profile
	user_on_proposal(0) with data.diamond.users.proposals as example_proposals
		with data.diamond.profile as example_profile
}

test_allow_if_user_on_proposals if {
	not user_on_session(0, 0) with data.diamond.users.proposals as {"user": [0, 1]}
		with data.diamond.profile as example_profile
	user_on_proposal(0) with data.diamond.users.proposals as {"user": [0, 1]}
		with data.diamond.profile as example_profile
}

test_disallow_if_user_not_on_proposal if {
	not user_on_session(0, 0) with data.diamond.users.proposals as example_proposals
		with data.diamond.profile as example_profile
	not user_on_proposal(1) with data.diamond.users.proposals as example_proposals
		with data.diamond.profile as example_profile
}
