# Deployment OR Gate POC

This repository demonstrates a GitHub merge gate for teams that have:

- one dedicated `entwicklung` environment
- multiple pre-dev `d0x` environments such as `d01` to `d05`
- a requirement that a pull request may merge to `main` after deployment to `entwicklung` or any one `d0x`

## Problem

GitHub's native "require deployments to succeed before merging" rule is not a good fit here:

- selecting multiple environments behaves like `AND`
- reusing one shared GitHub environment for all `d0x` deployments causes deployment collisions
- a new deployment to the same GitHub environment can mark older deployments inactive

## Fix Pattern

This POC uses two rules:

1. Every deployable lane gets its own GitHub deployment environment.
2. A custom required status check named `pre-dev-deployment` implements the `OR` logic.

In this repo that means:

- `entwicklung` stays separate
- `d01`, `d02`, `d03`, `d04`, `d05` are separate GitHub environments
- a PR is mergeable when its head SHA has a successful deployment in at least one of those environments

## Workflows

- `CI`: basic PR sanity check
- `Simulate entwicklung deployment`: deploys the latest commit from a provided branch into `entwicklung`
- `Simulate d0x deployment`: deploys the latest commit from a provided branch into one of `d01` to `d05`
- `Pre-dev deployment gate`: seeds the gate on PR updates and allows manual status backfills when needed

## Demo Flow

1. Create two branches and open two PRs against `main`.
2. Run `Simulate d0x deployment` for PR A with `d01`.
3. Run `Simulate d0x deployment` for PR B with `d02`.
4. Both PRs can satisfy the same required gate because they use different GitHub environments.
5. Run `Simulate entwicklung deployment` for a third PR if you want to show the dedicated environment path.

## Important Limitation

This design allows parallel work across different `d0x` environments.

It does not make one single `d0x` environment safe for unlimited concurrent PRs. If two different SHAs both deploy to `d01`, the older deployment can become inactive. That is expected GitHub deployment behavior. The practical fix is to keep the lanes separate and let different people use different `d0x` environments.

## Suggested GitHub Settings

On branch protection or rulesets for `main`:

- require `CI / basic-sanity`
- require `pre-dev-deployment`
- do not use GitHub's native required deployment selection for this scenario

## Example Commands

Deploy a PR branch to `d01`:

```bash
gh workflow run "Simulate d0x deployment" \
  --repo Daniel-Snetcov-DVAG/deployment-or-gate-poc \
  --ref main \
  -f target_branch=feature/alice \
  -f d0x=d01
```

Deploy a PR branch to `entwicklung`:

```bash
gh workflow run "Simulate entwicklung deployment" \
  --repo Daniel-Snetcov-DVAG/deployment-or-gate-poc \
  --ref main \
  -f target_branch=feature/alice
```

Create the demo environments after the repo exists:

```bash
./scripts/bootstrap-environments.sh Daniel-Snetcov-DVAG/deployment-or-gate-poc
```
