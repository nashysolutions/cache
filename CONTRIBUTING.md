# Contributing

## Versioning policy

Cache follows [Semantic Versioning](https://semver.org). Adopters depend on it through version ranges such as `.upToNextMajor(from:)`, so a minor or patch release must not stop their code compiling.

1. **Deprecate before removing.** A public symbol that is renamed or removed keeps an `@available(*, deprecated, renamed:)` or `@available(*, deprecated, message:)` shim through at least one released minor. It is removed only in the next major.
2. **Batch breaking changes into one major.** Minor releases carry deprecations, not removals.
3. **The on-disk layout is API.** A change to what `FileSystemCache` writes to disk carries a layout version, and either migrates entries written by the previous layout or documents that they are orphaned. The current layout is described in [On-disk format](Sources/Cache/Documentation.docc/Articles/OnDiskFormat.md).
4. **A major release's notes list every removal**, with the minor release that deprecated it. To list the breaking changes since the latest release:

   ```sh
   swift package diagnose-api-breaking-changes "$(git describe --tags --abbrev=0)"
   ```

Some breaking changes have no deprecation path, such as a new protocol requirement or a tightened generic constraint. They still wait for a major, and its release notes list them.

## Breaking-change check

Every pull request runs `swift package diagnose-api-breaking-changes` in the [API breaking changes](.github/workflows/api-breaking-changes.yml) workflow. It compares the pull request against the commit it merges into, so it reports only the breaking changes that pull request introduces.

- The check fails when it finds a breaking change, unless the pull request carries the `breaking` label. The label is the recorded ruling that the change belongs in the next major release.
- Adding or removing the label runs the check again. Re-running an earlier run reuses the labels that run started with.
- A comparison that does not complete, such as a baseline that fails to build, fails the check whether or not the label is present.
- The check cannot see a change to the on-disk layout. A pull request that makes one carries the `breaking` label too.

To run the same comparison locally, against the commit your branch would merge into:

```sh
git fetch origin
swift package diagnose-api-breaking-changes "$(git merge-base HEAD origin/main)"
```

From outside the package root, pass `--package-path`. It is an option of `swift package` itself, so it goes before the subcommand:

```sh
swift package --package-path path/to/cache diagnose-api-breaking-changes "$(git -C path/to/cache merge-base HEAD origin/main)"
```
