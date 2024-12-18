# Verify Json Web Token (JWT)

## Preface

This guide will explain how to cryptographically validate a Subject's JSON Web Token (JWT) using the JSON Web Key Set (JWKS) of the Signle Sign On (SSO) provider.

We do not yet provide an organisational JWT verification policy. However the implementation example given in [Implementation](#implementation) can be used for testing purposes.

## Implementation

Verification of JSON Web Tokens (JWTs) may be performed without a round trip to the Single Sign On (SSO) provider by utilizing the JSON Web Key Set (JWKS) to cryptographically verify that the signature on the JWT is genuine. JSON Web Key Sets rotate periodically, thus we must occasionally fetch the current set via the JWKS endpoint with the Key ID (`kid`) supplied encoded within the JWT.

The following code expects the OIDC provider (e.g. `https://authn.diamond.ac.uk/realms/master`) to be supplied in the `ISSUER` environment variable.

```rego
package token

import rego.v1

fetch_jwks(url) := http.send({
    "url": url,
    "method": "GET",
    "force_cache": true,
    "force_cache_duration_seconds": 3600,
})

oidc_issuer := opa.runtime().env.ISSUER

jwks_endpoint := http.send({
    "url": concat("", [oidc_issuer, "/.well-known/openid-configuration"]),
    "method": "GET",
    "force_cache": true,
    "force_cache_duration_seconds": 84600
    }).body.jwks_uri

unverified := io.jwt.decode(input.token)

jwt_header := unverified[0]

jwks_url := concat("?", [jwks_endpoint, urlquery.encode_object({"kid": jwt_header.kid})])

jwks := fetch_jwks(jwks_url).raw_body

valid := io.jwt.decode_verify(input.token, {
    "cert": jwks,
    "iss": "https://authn.diamond.ac.uk/realms/master",
    "aud": "account",
})

claims := valid[2]
```
