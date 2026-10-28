# live-build fork (Finnix)

You probably want [finnix-live-build](https://github.com/finnix/finnix-live-build), the repository used to build Finnix images.

The [main](https://github.com/finnix/live-build/tree/main) branch of this repository contains a fork of the upstream Debian [live-build](https://salsa.debian.org/live-team/live-build) repository, and is pulled in as a submodule by [finnix-live-build](https://github.com/finnix/finnix-live-build).

It strives to be the same codebase as upstream, and usually is, but occasionally contains commits needed for Finnix which have not yet been accepted upstream.

## Update procedure

In `~/git/live-build`:

```shell
git fetch origin
git push finnix origin/master:upstream

git checkout finnix/main
git merge origin/master
```

If any conflicts, resolve and then:

```shell
git add .
git merge --continue
```

For the merge commit message, leave the existing `Merge remote-tracking branch 'origin/master' into HEAD` in place, then add the `Outstanding downstream changes:` section from the previous merge commit. Once committed:

```shell
git push finnix HEAD:staging
```

In `~/git/finnix-live-build/live-build`:

```shell
git fetch finnix
git checkout finnix/staging
```

Run a build from `~/git/finnix-live-build` and test. If all looks good, in `~/git/live-build`:

```shell
git push finnix HEAD:main
```

In `~/git/finnix-live-build/live-build`:

```shell
git fetch finnix
git checkout finnix/main
```

In `~/git/finnix-live-build`:

```shell
git add live-build
git commit -m 'Update live-build submodule'
git push
```
