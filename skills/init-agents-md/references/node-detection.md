# Node.js Project Detection

When invoked on a project, the skill must inspect the following signals to
classify and characterize a Node.js project.

## Identification

- `package.json` exists → Node.js project.

## Characterization

- **packageManager**: read `.packageManager` field; fall back to lockfile:
  - `pnpm-lock.yaml` → pnpm
  - `yarn.lock`     → yarn
  - `bun.lockb`     → bun
  - `package-lock.json` → npm
- **language**: presence of `tsconfig.json` → TypeScript; else JavaScript.
- **framework**: scan `.dependencies` and `.devDependencies` for first match:
  next → nuxt → remix → svelte-kit → vite → astro → gatsby → express → fastify → nestjs.
  Default: `none`.
- **scripts**: read `.scripts` object; expect keys `dev`, `build`, `test`,
  `lint`, `format`, `typecheck` (any may be missing).
- **testFramework**: scan devDeps for vitest, jest, mocha, uvu, tap.
- **linter**: scan devDeps for eslint, biome, oxlint.
- **formatter**: scan devDeps for prettier, biome, dprint.
- **typeChecker**: `tsconfig.json` present → tsc; else none.
- **bundler**: scan devDeps for webpack, turbopack, vite, esbuild, rollup, parcel.
- **lint-staged**: presence of `lint-staged` key at root of package.json.

## Workspace & CI signals

- **ciSystem**: `.github/workflows` → github-actions; `.gitlab-ci.yml` → gitlab-ci;
  `.circleci` → circleci.
- **preCommitHooks**: `.husky` → husky; `.pre-commit-config.yaml` → pre-commit;
  `lefthook.yml` → lefthook.
- **dockerSupport**: any `Dockerfile*` in root.
- **envFiles**: any `.env*` file in root.

## Edge cases

- No `package.json` → not a Node project; do not invoke `detect-node.sh`.
- Multiple lockfiles (rare) → prefer the field; otherwise pnpm > yarn > bun > npm.
- Workspace (`pnpm-workspace.yaml` or `workspaces` in package.json) → mark as
  monorepo in the rendered `AGENTS.md` §3.
