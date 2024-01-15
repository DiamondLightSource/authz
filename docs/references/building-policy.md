```yaml
name: Policy Test
# Lints and runs tests on every push to a branch
# Assumes that all policy is in policy/ dir in repository

on:
  push:
  pull_request:

jobs:
  lint:
    # Deduplicate jobs from pull requests and branch pushes within the same repo.
    if: github.event_name != 'pull_request' || github.event.pull_request.head.repo.full_name != github.repository
    runs-on: ubuntu-latest
    steps:
      - name: Checkout source
        uses: actions/checkout@v4.1.1

      - name: Setup Regal
        uses: StyraInc/setup-regal@v0.2.0
        with:
          version: latest

      - name: Lint
        run: regal lint --format github policy

  test:
    # Deduplicate jobs from pull requests and branch pushes within the same repo.
    if: github.event_name != 'pull_request' || github.event.pull_request.head.repo.full_name != github.repository
    runs-on: ubuntu-latest
    steps:
      - name: Checkout source
        uses: actions/checkout@v4.1.1

      - name: Setup OPA
        uses: open-policy-agent/setup-opa@v2.1.0
        with:
          version: latest

      - name: Test
        run: opa test policy -v
```
