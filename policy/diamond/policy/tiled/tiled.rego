package diamond.policy.tiled

import data.diamond.policy.token

read_scopes = {
    "read:metadata",
    "read:data",
}

write_scopes = {
    "write:metadata",
    "write:data",
    "create",
    "register",
}

default scopes := set()

scopes_for(claims) := read_scopes & write_scopes if {
    "azp" in object.keys(claims)
	endswith(claims.azp,  "-blueapi")
}

scopes_for(claims) := read_scopes if {
    "azp" in object.keys(claims)
	not endswith(claims.azp,  "-blueapi")
}

scopes_for(claims) := read_scopes if {
    not "azp" in object.keys(claims)
}

scopes := scopes_for(token.claims)
