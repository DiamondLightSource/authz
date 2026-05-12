package diamond.policy.blueapi

import data.diamond.policy.token
import rego.v1

default tiled_service_account_for_beamline := false

tiled_service_account_for_beamline if {
	input.beamline == token.claims.beamline
	"tiled-writer" in token.claims.aud
	not token.claims.fedid
}
