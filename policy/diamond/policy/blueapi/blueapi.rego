package diamond.policy.blueapi

import data.diamond.policy.admin
import data.diamond.policy.session
import data.diamond.policy.token

import rego.v1

default tiled_service_account_for_beamline := false

tiled_service_account_for_beamline if {
	input.beamline == token.claims.beamline
	"tiled-writer" in token.claims.aud
	not token.claims.fedid
}

default write_to_beamline_visit := false

write_to_beamline_visit if {
	session.write_to_beamline_visit
}

# Service account check
write_to_beamline_visit if {
	input.beamline == token.claims.beamline
	input.beamline == session.beamline
}
