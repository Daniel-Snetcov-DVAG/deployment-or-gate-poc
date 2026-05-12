# Flowcharts

This document shows the actual execution flow in the POC, from a fresh PR with no deployment to a mergeable PR, plus the two important rewrite cases:

- different lanes: no rewrite
- same lane: rewrite happens on purpose

## Components

- `.github/workflows/ci.yml`
  - creates the required `basic-sanity` check
- `.github/workflows/predev-deployment-gate.yml`
  - seeds or backfills the required `pre-dev-deployment` status
- `.github/workflows/deploy-d0x.yml`
  - deploys the selected branch head to `d01` to `d05`
- `.github/workflows/deploy-entwicklung.yml`
  - deploys the selected branch head to `entwicklung`
- `.github/actions/sync-predev-status/action.yml`
  - reads deployment history and writes the final `pre-dev-deployment` commit status

## 1. Untouched PR -> Mergeable PR

```mermaid
flowchart TD
  A[PR opened or updated against main] --> B[CI workflow runs]
  A --> C[Pre-dev deployment gate workflow runs]
  B --> D[basic-sanity = success]
  C --> E[sync-predev-status reads deployments for PR head SHA]
  E --> F{Any success in\\nentwicklung or d01..d05?}
  F -->|No| G[pre-dev-deployment = pending]
  F -->|Yes| H[pre-dev-deployment = success]

  I[Developer runs deploy workflow from feature branch] --> J{Which workflow?}
  J -->|d01..d05| K[deploy-d0x.yml]
  J -->|entwicklung| L[deploy-entwicklung.yml]
  K --> M[Use github.sha and github.ref_name from selected branch]
  L --> M
  M --> N[Create GitHub deployment]
  N --> O[Mark deployment success]
  O --> P[Mark older deployments in same lane inactive]
  P --> Q[sync-predev-status recomputes affected SHAs]
  Q --> R[pre-dev-deployment updated]

  D --> S{Branch protection}
  G --> S
  H --> S
  R --> S
  S -->|basic-sanity + pre-dev-deployment success| T[Merge allowed]
```

## 2. Different Lanes -> No Rewrite

This is the main scenario the POC fixes.

Feature A deployed to `d01` must stay valid when Feature B deploys to `d02`.

```mermaid
flowchart TD
  A1[PR A head SHA] --> B1[Deploy to d01]
  B1 --> C1[d01 deployment success]
  C1 --> D1[PR A pre-dev-deployment = success]

  A2[PR B head SHA] --> B2[Deploy to d02]
  B2 --> C2[d02 deployment success]
  C2 --> D2[PR B pre-dev-deployment = success]

  C2 --> E{Does d02 deployment touch d01 history?}
  E -->|No| F[PR A keeps success]
  D1 --> G[PR A remains mergeable]
  D2 --> H[PR B remains mergeable]
```

## 3. Same Lane -> Rewrite Happens

This is expected behavior, not the original bug.

If two different SHAs both use `d01`, the newer `d01` deployment becomes the active one and the older one is inactivated.

```mermaid
flowchart TD
  A[PR A head SHA] --> B[Deploy to d01]
  B --> C[Deployment A in d01 = success]
  C --> D[PR A pre-dev-deployment = success]

  E[PR B head SHA] --> F[Deploy to same lane d01]
  F --> G[Deployment B in d01 = success]
  G --> H[Workflow marks older d01 deployments inactive]
  H --> I[sync-predev-status recomputes recent SHAs in d01]

  I --> J[PR B pre-dev-deployment = success]
  I --> K[PR A sees d01 deployment = inactive]
  K --> L[PR A pre-dev-deployment = pending]
```

## 4. State Decision Inside sync-predev-status

This is the decision tree inside `.github/actions/sync-predev-status/action.yml`.

```mermaid
flowchart TD
  A[Given one target SHA] --> B[Check latest deployment state in each allowed environment]
  B --> C{Any state = success?}
  C -->|Yes| D[Set pre-dev-deployment = success]
  C -->|No| E{Any state = pending queued or in_progress?}
  E -->|Yes| F[Set pre-dev-deployment = pending]
  E -->|No| G{Any state = failure or error?}
  G -->|Yes| H[Set pre-dev-deployment = failure]
  G -->|No| I{Any state = inactive?}
  I -->|Yes| J[Set pre-dev-deployment = pending with redeploy message]
  I -->|No| K[Set pre-dev-deployment = pending with deploy-required message]
```

## 5. Runtime Ownership

```mermaid
flowchart LR
  A[ci.yml] --> A1[basic-sanity]
  B[predev-deployment-gate.yml] --> B1[seed or backfill sync]
  C[deploy-d0x.yml] --> C1[create success inactive sync for d01..d05]
  D[deploy-entwicklung.yml] --> D1[create success inactive sync for entwicklung]
  E[sync-predev-status action] --> E1[reads deployments]
  E --> E2[writes pre-dev-deployment]
```
