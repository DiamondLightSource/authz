package diamond.policy.blueapi_test

import data.diamond.policy.blueapi
import rego.v1

test_service_account_if_beamline_matches if {
	blueapi.service_account_for_beamline with input as {"beamline": "i22"}
		with data.diamond.policy.token.claims as {"beamline": "i22", "aud": ["tiled-writer"]}
}

test_not_service_account_if_beamline_mismatch if {
	not blueapi.service_account_for_beamline with input as {"beamline": "b21"}
		with data.diamond.policy.token.claims as {"beamline": "i22", "aud": ["tiled-writer"]}
}

test_not_service_account_if_missing_aud if {
	not blueapi.service_account_for_beamline with input as {"beamline": "i22"}
		with data.diamond.policy.token.claims as {"beamline": "i22", "aud": ["blueapiCli"]}
}

test_not_service_account_if_fedid_present if {
	not blueapi.service_account_for_beamline with input as {"beamline": "i22"}
		with data.diamond.policy.token.claims as {"beamline": "i22", "aud": ["tiled-writer"], "fedid": "abc12345"}
}
