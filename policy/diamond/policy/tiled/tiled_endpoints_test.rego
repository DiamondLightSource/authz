# The three endpoints tiled calls through dls_tiled.policy, with the inputs
# its build_input sends ({"audience", "token"} plus an access blob's fields):
#
#   tiled/user_session   init_node: the tags to stamp on a node being created
#   tiled/user_sessions  filters: the tags the caller may see, on every request
#   tiled/scopes         what the caller may do
#
# How tiled uses the tags
#
# dls_tiled.policy hands tiled the caller's user_sessions list, and tiled
# turns it into one SQL condition applied to every node it looks at: a node is
# visible if any of its tags is in the list (access_blob->'tags' ?| [...]).
# Two properties of that rule drive everything below:
#   1. It is exact string matching: no prefixes, wildcards or hierarchy, which
#      is also why a tag like "beamline:i22,proposal:*" can't work.
#   2. It is per node: tiled doesn't know i22/cm1 is "inside" i22, so each
#      node is judged by its own tags only, and opening i22/cm1/cm1-1 means
#      passing the check at i22, at i22/cm1 and at i22/cm1/cm1-1. A hidden
#      container hides everything under it.
#
# Grant tags: one grant covers a subtree
#
# So that a beamline admin needs one tag rather than one per session, every
# node carries the grant tags of all its ancestors as well as its own (the
# node's own tag first; dls_tiled.policy reads tags[0] back):
#
#   i22               beamline:i22                          visible:beamline:i22
#   i22/cm1           beamline:i22,proposal:1  beamline:i22  visible:beamline:i22,proposal:1
#   i22/cm1/cm1-1     beamline:i22,proposal:1,session:1-1  beamline:i22,proposal:1  beamline:i22
#   (runs in cm1-1)   same as cm1-1
#
# beamline:i22 is on every node of the beamline, which is why holding it shows
# you all of i22. Each tag on a session says who sees it: its members (session
# tag), its proposal's members (proposal tag), the beamline's admins and
# service account (beamline tag).
#
# Visible tags: see a container without its contents
#
# A session member must still pass i22 and i22/cm1 to reach their session.
# Giving them beamline:i22 for that would also match i22/cm2 and the sibling
# session i22/cm1/cm1-2, which carry it too: they'd be a beamline admin. The
# same goes for the proposal tag and cm1-2. A grant tag's scope is a node and
# its whole subtree; what's needed is a tag whose scope is exactly one node.
# That is visible:<tag>: stamped on that container only, never on anything
# below it. The beamline node carries both beamline:i22 (so beamline admins
# see it) and visible:beamline:i22 (so members of anything below can pass it).
# Sessions need no visible tag: anyone who should see one holds a grant that
# is already on it.
#
# What user_sessions returns
#
#   service account for i22    beamline:i22
#   i22 beamline admin         beamline:i22
#   proposal 1 member          beamline:i22,proposal:1, visible:beamline:i22
#   session cm1-1 member       beamline:i22,proposal:1,session:1-1,
#                              visible:beamline:i22,proposal:1, visible:beamline:i22
#   super admin                * (dls_tiled.policy applies no filter)
#
# It grows with the grants a caller holds, not with the sessions under them.
package diamond.policy.tiled_test

import data.diamond.policy.tiled
import rego.v1

i22_data := {
	"subjects": {
		"alice": {"permissions": [], "proposals": [], "sessions": [11]},
		"bob": {"permissions": ["i22_admin"], "proposals": [], "sessions": []},
		"carol": {"permissions": ["super_admin"], "proposals": [], "sessions": []},
		"dave": {"permissions": [], "proposals": [1], "sessions": []},
		"oscar": {"permissions": [], "proposals": [], "sessions": []},
	},
	"sessions": {
		"11": {"beamline": "i22", "proposal_number": 1, "visit_number": 1},
		"12": {"beamline": "i22", "proposal_number": 1, "visit_number": 2},
		"21": {"beamline": "i22", "proposal_number": 2, "visit_number": 1},
		"31": {"beamline": "b07", "proposal_number": 3, "visit_number": 1},
	},
	"proposals": {
		"1": {"sessions": {"1": 11, "2": 12}},
		"2": {"sessions": {"1": 21}},
		"3": {"sessions": {"1": 31}},
	},
	"beamlines": {"i22": {"sessions": [11, 12, 21]}, "b07": {"sessions": [31]}},
	"admin": {"i22_admin": ["i22"]},
}

# What dls_tiled.policy's build_input always sends; the token itself is
# replaced by its claims in each test.
request := {"audience": "account", "token": "<jwt>"}

writer := {"beamline": "i22", "aud": ["tiled-writer", "account"]}

# The tree TiledWriter's service account builds, as test_create_node_tags
# checks user_session stamps it. Runs carry their session's tags.
nodes := {
	"b07": ["beamline:b07", "visible:beamline:b07"],
	"i22": ["beamline:i22", "visible:beamline:i22"],
	"i22/cm1": ["beamline:i22,proposal:1", "beamline:i22", "visible:beamline:i22,proposal:1"],
	"i22/cm2": ["beamline:i22,proposal:2", "beamline:i22", "visible:beamline:i22,proposal:2"],
	"i22/cm1/cm1-1": ["beamline:i22,proposal:1,session:1-1", "beamline:i22,proposal:1", "beamline:i22"],
	"i22/cm1/cm1-2": ["beamline:i22,proposal:1,session:1-2", "beamline:i22,proposal:1", "beamline:i22"],
	"i22/cm2/cm2-1": ["beamline:i22,proposal:2,session:2-1", "beamline:i22,proposal:2", "beamline:i22"],
}

# The nodes tiled shows a caller whose user_sessions is `allowed`.
seen(allowed) := {name |
	some name, tags in nodes
	some tag in tags
	tag in allowed
}

# --- tiled/user_session: what blueapi's containers and runs are stamped with

test_create_node_tags if {
	tiled.user_session == nodes.i22 with input as object.union(request, {"beamline": "i22"})
		with data.diamond.policy.token.claims as writer
		with data.diamond.data as i22_data
	tiled.user_session == nodes["i22/cm1"] with input as object.union(request, {"beamline": "i22", "proposal": "cm1"})
		with data.diamond.policy.token.claims as writer
		with data.diamond.data as i22_data
	tiled.user_session == nodes["i22/cm1/cm1-1"] with input as object.union(
		request,
		{"beamline": "i22", "proposal": "cm1", "visit": 1},
	)
		with data.diamond.policy.token.claims as writer
		with data.diamond.data as i22_data
}

test_create_node_refused_on_another_beamline if {
	not tiled.user_session with input as object.union(request, {"beamline": "b07"})
		with data.diamond.policy.token.claims as writer
		with data.diamond.data as i22_data
	not tiled.user_session with input as object.union(request, {"beamline": "b07", "proposal": "cm3", "visit": 1})
		with data.diamond.policy.token.claims as writer
		with data.diamond.data as i22_data
}

# --- tiled/user_sessions: what each kind of caller sees

test_service_account_sees_its_beamline if {
	allowed := tiled.user_sessions with input as request
		with data.diamond.policy.token.claims as writer
		with data.diamond.data as i22_data
	allowed == {"beamline:i22"}
	seen(allowed) == {"i22", "i22/cm1", "i22/cm2", "i22/cm1/cm1-1", "i22/cm1/cm1-2", "i22/cm2/cm2-1"}
}

test_beamline_admin_sees_the_beamline if {
	allowed := tiled.user_sessions with input as request
		with data.diamond.policy.token.claims as {"fedid": "bob"}
		with data.diamond.data as i22_data
	allowed == {"beamline:i22"}
	seen(allowed) == {"i22", "i22/cm1", "i22/cm2", "i22/cm1/cm1-1", "i22/cm1/cm1-2", "i22/cm2/cm2-1"}
}

test_proposal_member_sees_the_proposal_and_the_beamline_node if {
	allowed := tiled.user_sessions with input as request
		with data.diamond.policy.token.claims as {"fedid": "dave"}
		with data.diamond.data as i22_data
	allowed == {"beamline:i22,proposal:1", "visible:beamline:i22"}
	seen(allowed) == {"i22", "i22/cm1", "i22/cm1/cm1-1", "i22/cm1/cm1-2"}
}

test_session_member_sees_the_session_and_the_containers_above_it if {
	allowed := tiled.user_sessions with input as request
		with data.diamond.policy.token.claims as {"fedid": "alice"}
		with data.diamond.data as i22_data
	allowed == {
		"beamline:i22,proposal:1,session:1-1",
		"visible:beamline:i22,proposal:1",
		"visible:beamline:i22",
	}
	seen(allowed) == {"i22", "i22/cm1", "i22/cm1/cm1-1"}
}

# Why the visible tags exist: passing the containers with their grant tags
# instead would show alice the whole beamline.
test_reusing_grant_tags_for_the_containers_would_leak if {
	allowed := {"beamline:i22,proposal:1,session:1-1", "beamline:i22,proposal:1", "beamline:i22"}
	seen(allowed) == {"i22", "i22/cm1", "i22/cm2", "i22/cm1/cm1-1", "i22/cm1/cm1-2", "i22/cm2/cm2-1"}
}

test_super_admin_gets_the_wildcard if {
	tiled.user_sessions == {"*"} with input as request
		with data.diamond.policy.token.claims as {"fedid": "carol"}
		with data.diamond.data as i22_data
}

test_no_permissions_sees_nothing if {
	allowed := tiled.user_sessions with input as request
		with data.diamond.policy.token.claims as {"fedid": "oscar"}
		with data.diamond.data as i22_data
	allowed == set()
	seen(allowed) == set()
}

# --- tiled/scopes

test_writer_may_create_and_write if {
	tiled.scopes == {
		"read:metadata",
		"read:data",
		"write:metadata",
		"write:data",
		"create:node",
		"register",
	} with input as request
		with data.diamond.policy.token.claims as writer
}

test_user_may_only_read if {
	tiled.scopes == {"read:metadata", "read:data"} with input as request
		with data.diamond.policy.token.claims as {"fedid": "alice", "aud": ["account"]}
}
