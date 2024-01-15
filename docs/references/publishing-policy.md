```yaml
name: Policy Container
# Builds your policy into a bundle, which is published as an OCI image to github container registry, to be used as part of your OPA instance's configuration.
# Publishes only when a github release is made or a tag added to the repository
# Assumes all policy is in policy/ dir in repository
on:
  push:
  pull_request:

jobs:
  build_bundle:
    # Deduplicate jobs from pull requests and branch pushes within the same repo.
    if: github.event_name != 'pull_request' || github.event.pull_request.head.repo.full_name != github.repository
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
    steps:
      - name: Checkout source
        uses: actions/checkout@v4.1.1

      - name: Generate Image Name
      # Assuming that your policy is stored alongside your service's source code, publishes the policy as {repository}-policy
        run: echo IMAGE_REPOSITORY=ghcr.io/$(echo "${{ github.repository }}-policy" | tr '[:upper:]' '[:lower:]' | tr '[_]' '[\-]') >> $GITHUB_ENV

      - name: Log in to GitHub Docker Registry
        uses: docker/login-action@v3.0.0
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      
      - name: Setup OPA
        uses: open-policy-agent/setup-opa@v2.1.0
        with:
          version: latest
      
      - name: Build OPA Policy  # If this is a tag, use it as a revision string. Strips all tests from the bundle to prevent namespace pollution
        run: opa build -b policy -r ${{ github.ref_name }} --ignore *_test.rego

      - name: Publish OPA Bundle
        if: ${{ github.event_name == 'push' && startsWith(github.ref, 'refs/tags') }}
        run: oras push ${{ env.IMAGE_REPOSITORY }}:${{ github.ref_name }} bundle.tar.gz:application/vnd.oci.image.layer.v1.tar+gzip
```