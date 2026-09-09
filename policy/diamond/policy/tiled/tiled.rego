package diamond.policy.tiled

import data.diamond.policy.beamline as beamline_policy
import data.diamond.policy.proposal
import data.diamond.policy.session
import data.diamond.policy.token
import rego.v1

# METADATA
# title: Tiled Scopes
# description: |
#   Says what the caller is allowed to do in tiled.
#   Anyone who gets this far may read metadata and data.
#   Clients whose token carries the "tiled-writer" audience may also write,
#   create nodes and register data.
#   Requires:
#     - `input.token`, a JWT
# entrypoint: true
default scopes := {
	"read:metadata",
	"read:data",
}

scopes := {
	"read:metadata",
	"read:data",
	"write:metadata",
	"write:data",
	"create:node",
	"register",
} if {
	"tiled-writer" in token.claims.aud
}

# METADATA
# title: Bare Proposal Number
# description: |
#   Turns a proposal label into the plain number it is stored under,
#   so "cm1234" becomes 1234.
bare_proposal(p) := to_number(trim_left(lower(p), "abcdefghijklmnopqrstuvwxyz"))

# METADATA
# title: Session Lookup
# description: |
#   Finds the session that `input.visit` refers to within proposal `p`.
#   Undefined when the proposal has no such visit, which is how the rules
#   below check that a session really exists.
_session(p) := data.diamond.data.proposals[format_int(p, 10)].sessions[format_int(input.visit, 10)]

# METADATA
# title: Beamline Tag
# description: |
#   The access tag for a beamline, the top level of the beamline, proposal
#   and session tree.
beamline_tag(bl) := sprintf("beamline:%s", [bl])

# METADATA
# title: Proposal Tag
# description: |
#   The access tag for a proposal. It names the beamline above it as well,
#   so that one flat membership check can match a node at any level of the
#   tree. `p` is always the bare proposal number.
proposal_tag(bl, p) := sprintf("beamline:%s,proposal:%s", [bl, format_int(p, 10)])

# METADATA
# title: Session Tag
# description: |
#   The access tag for a session, the leaf of the tree. Like the proposal
#   tag it names every ancestor, and it identifies the session by proposal
#   and visit, for example "beamline:i03,proposal:1,session:1-1".
session_tag(bl, p, v) := sprintf("beamline:%s,proposal:%s,session:%s-%d", [bl, format_int(p, 10), format_int(p, 10), v])

# METADATA
# title: Proposal Beamlines
# description: |
#   The beamlines hosting at least one session of the bare proposal number `p`.
proposal_beamlines(p) := {data.diamond.data.sessions[format_int(s, 10)].beamline |
	some s in data.diamond.data.proposals[format_int(p, 10)].sessions
}

# METADATA
# title: Node Access Tag
# description: |
#   The access tag to stamp on the node the caller is creating, or nothing
#   at all if they are not allowed to create it.
#   tiled's create-node flow (see `init_node` in dls.py) tells the policy
#   nothing about the path or the parent, so the only clue to which level is
#   being created is which fields arrive alongside the beamline:
#     - beamline alone, a beamline node
#     - beamline and proposal, a proposal node
#     - beamline, proposal and visit, a session node
#   The three levels are kept apart by checking that the deeper fields are
#   absent. The first rule below is the session level for a named user, who
#   must have write access to the beamline, proposal and visit they name, and
#   the rules after it cover the other two levels and the service accounts.
#   Requires:
#     - `input.token`, a JWT
#     - `input.beamline`, the beamline the node belongs to
#     - `input.proposal`, a proposal label such as "cm1234", for the lower
#       two levels
#     - `input.visit`, a visit number, for a session node
# entrypoint: true
user_session := session_tag(input.beamline, p, input.visit) if {
	input.visit
	p := bare_proposal(input.proposal)
	session.access_session(token.claims.fedid, p, input.visit)
	input.beamline == session.beamline_for(p, input.visit)
	_session(p)
}

# Session level, for a service account tied to the beamline.
user_session := session_tag(input.beamline, p, input.visit) if {
	input.visit
	not token.claims.fedid
	input.beamline == token.claims.beamline
	p := bare_proposal(input.proposal)
	input.beamline == session.beamline_for(p, input.visit)
	_session(p) in data.diamond.data.beamlines[input.beamline].sessions
}

# Proposal level: the caller has access to the proposal, and the proposal
# actually runs on the beamline they asked for.
user_session := proposal_tag(input.beamline, p) if {
	not input.visit
	input.proposal
	p := bare_proposal(input.proposal)
	proposal.access_proposal(token.claims.fedid, p)
	input.beamline in proposal_beamlines(p)
}

# Proposal level, for a service account tied to the beamline.
user_session := proposal_tag(input.beamline, p) if {
	not input.visit
	input.proposal
	not token.claims.fedid
	input.beamline == token.claims.beamline
	p := bare_proposal(input.proposal)
	input.beamline in proposal_beamlines(p)
}

# Beamline level: the caller is authorized on the beamline itself.
user_session := beamline_tag(input.beamline) if {
	not input.visit
	not input.proposal
	input.beamline in beamline_policy.user_beamlines
}

# METADATA
# title: Modify Session
# description: |
#   Whether the caller may change an existing session. A named user needs
#   access to that session; a service account needs the session to sit on
#   the beamline named in its token.
#   Requires:
#     - `input.token`, a JWT
#     - `input.session`, a session id
# entrypoint: true
default modify_session := false

modify_session if session.access_session(
	token.claims.fedid,
	data.diamond.data.sessions[input.session].proposal_number,
	data.diamond.data.sessions[input.session].visit_number,
)

# Service accounts may modify any session on their own beamline.
modify_session if {
	not token.claims.fedid
	session.beamline_for(
		data.diamond.data.sessions[input.session].proposal_number,
		data.diamond.data.sessions[input.session].visit_number,
	) == token.claims.beamline
}

# METADATA
# title: Accessible Node Tags
# description: |
#   Every access tag the caller is allowed to see. tiled asks for these when
#   listing the tree and keeps the nodes whose own tag is in the set.
#   Each session the caller can reach contributes three tags, one for itself
#   and one for each of its ancestors, so the beamline and proposal that
#   contain a session stay visible alongside the session itself.
#   Admins get "*", which stands in for every tag.
#   The tags are rebuilt from the numbers in the data bundle, exactly as they
#   are built when a node is created, so the two always agree.
#   Requires:
#     - `input.token`, a JWT
# entrypoint: true
user_sessions contains "*" if "*" in session.user_sessions

user_sessions contains beamline_tag(s.beamline) if {
	not "*" in session.user_sessions
	some id in session.user_sessions
	s := data.diamond.data.sessions[id]
}

user_sessions contains proposal_tag(s.beamline, s.proposal_number) if {
	not "*" in session.user_sessions
	some id in session.user_sessions
	s := data.diamond.data.sessions[id]
}

user_sessions contains session_tag(s.beamline, s.proposal_number, s.visit_number) if {
	not "*" in session.user_sessions
	some id in session.user_sessions
	s := data.diamond.data.sessions[id]
}
