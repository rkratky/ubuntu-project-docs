(merge-a-package)=
# How to merge a package

Merging is the process of taking all Ubuntu changes made on top of one Debian version of a package, and re-doing them on top of a new Debian version of the package. See {ref}`merges-syncs` for a more context information.

See [the Ubuntu wiki](https://wiki.ubuntu.com/UbuntuDevelopment/Merging/GitWorkflow) for a more detailed workflow. This guide is intended to cover the majority of use cases.

For a list of packages that have been changed in Debian, but not merged into Ubuntu, see the Merge-o-Matic tool:

* [main](https://merges.ubuntu.com/main.html)
* [universe](https://merges.ubuntu.com/universe.html)
* [restricted](https://merges.ubuntu.com/restricted.html)
* [multiverse](https://merges.ubuntu.com/multiverse.html)


## Overview

Merging is done using the {command}`git-ubuntu` tool. As such, the process in many ways follows that of a {command}`git rebase` where commits from one point are replayed on top of another point:

```{mermaid}
   :caption: `git-ubuntu` process overview
   :alt: git-ubuntu process overview
   :zoom:

gitGraph
   commit id: "something 1.2"
   branch 1.2ubuntu
   checkout 1.2ubuntu
   commit id: "Ubuntu changes a, b, c on 1.2"
   commit id: "1.2ubuntu1"
   checkout main
   commit id: "something 1.3"
   branch 1.3ubuntu
   checkout 1.3ubuntu
   commit id: "Ubuntu changes a, b, c on 1.3"
   commit id: "1.3ubuntu1"
```

At a more detailed level, there are other sub-tasks to be done, such as:

* Splitting out large "omnibus" style commits into smaller logical units (one commit per logical unit).
* Harmonizing `debian/changelog` commits into two commits: a changelog merge and a reconstruction.

With this process, we keep the Ubuntu version of a package cleanly applied to the end of the latest Debian version and make it easy to drop changes as they become redundant.


## Process steps

- {ref}`merge-preliminary-steps`
    - {ref}`merge-decide-on-a-merge-candidate`
    - {ref}`merge-check-existing-bug-entries`
    - {ref}`merge-make-a-bug-report-for-the-merge`
    - {ref}`merge-clone-the-package-repository`
- {ref}`merge-the-merge-process`
    - {ref}`merge-start-a-git-ubuntu-merge`
    - {ref}`merge-make-a-merge-branch`
    - {ref}`merge-split-commits`
    - {ref}`merge-check-if-there-are-commits-to-split`
        - {ref}`merge-identify-logical-changes`
        - {ref}`merge-split-into-logical-commits`
        - {ref}`merge-tag-split`
    - {ref}`merge-prepare-the-logical-view`
        - {ref}`merge-check-the-result`
        - {ref}`merge-create-logical-tag`
    - {ref}`merge-rebase-onto-new-debian`
        - {ref}`merge-conflicts`
        - {ref}`merge-corollaries`
        - {ref}`merge-empty-commits`
        - {ref}`merge-sync-request`
        - {ref}`merge-check-patches-still-apply-cleanly`
        - {ref}`merge-unapply-patches-before-continuing`
    - {ref}`merge-adding-new-changes`
    - {ref}`merge-finish-the-merge`
    - {ref}`merge-fix-the-changelog`
        - {ref}`merge-add-dropped-changes`
        - {ref}`merge-format-any-new-added-changes`
        - {ref}`merge-commit-the-changelog-fix`
        - {ref}`merge-no-changes-to-debian-changelog`
- {ref}`merge-cheat-sheet`
- {ref}`merge-upload-a-ppa`
    - {ref}`merge-get-the-orig-tarball`
    - {ref}`merge-build-source-package`
    - {ref}`merge-push-to-your-launchpad-repository`
        - {ref}`merge-push-your-lp-tags`
    - {ref}`merge-create-a-ppa`
        - {ref}`merge-create-a-ppa-repository`
        - {ref}`merge-upload-files`
        - {ref}`merge-wait-for-packages-to-be-ready`
- {ref}`merge-test-the-new-build`
    - {ref}`merge-test-upgrading-from-the-previous-version`
    - {ref}`merge-test-installing-the-latest-from-scratch`
    - {ref}`merge-other-smoke-tests`
- {ref}`merge-submit-merge-proposal`
    - {ref}`merge-update-the-merge-proposal`
    - {ref}`merge-open-the-review`
- {ref}`merge-follow-the-migration`
    - {ref}`merge-package-tests`
    - {ref}`merge-proposed-migration`

Manual steps:
- {ref}`merge-start-a-merge-manually`
    - {ref}`merge-generate-the-merge-branch`
    - {ref}`merge-create-tags`
    - {ref}`merge-start-a-rebase`
    - {ref}`merge-clear-any-history`
    - {ref}`merge-create-reconstruct-tag`
- {ref}`merge-create-logical-tag-manually`
- {ref}`merge-finish-the-merge-manually`
- {ref}`merge-get-the-orig-tarball-manually`
    - {ref}`merge-if-git-checkout-also-fails`
- {ref}`merge-submit-merge-proposal-manually`
- {ref}`merge-known-issues`
    - {ref}`merge-empty-directories`


(merge-preliminary-steps)=
## Preliminary steps


(merge-decide-on-a-merge-candidate)=
### Decide on a merge candidate

First, check if a newer version is available from Debian. Use the {manpage}`rmadison(1)` tool:

```none
$ rmadison <package>
$ rmadison -u debian <package>
```

Example:

```none
$ rmadison at
 at | 3.1.13-1ubuntu1   | precise | source, amd64, armel, armhf, i386, powerpc
 at | 3.1.14-1ubuntu1   | trusty  | source, amd64, arm64, armhf, i386, powerpc, ppc64el
 at | 3.1.18-2ubuntu1   | xenial  | source, amd64, arm64, armhf, i386, powerpc, ppc64el, s390x
 at | 3.1.20-3.1ubuntu2 | bionic  | source, amd64, arm64, armhf, i386, ppc64el, s390x
 at | 3.1.20-3.1ubuntu2 | cosmic  | source, amd64, arm64, armhf, i386, ppc64el, s390x
 at | 3.1.20-3.1ubuntu2 | disco   | source, amd64, arm64, armhf, i386, ppc64el, s390x
$ rmadison -u debian at
at         | 3.1.13-2+deb7u1 | oldoldstable       | source, amd64, armel, armhf, i386, ia64, kfreebsd-amd64, kfreebsd-i386, mips, mipsel, powerpc, s390, s390x, sparc
at         | 3.1.16-1        | oldstable          | source, amd64, arm64, armel, armhf, i386, mips, mipsel, powerpc, ppc64el, s390x
at         | 3.1.16-1        | oldstable-kfreebsd | source, kfreebsd-amd64, kfreebsd-i386
at         | 3.1.20-3        | stable             | source, amd64, arm64, armel, armhf, i386, mips, mips64el, mipsel, ppc64el, s390x
at         | 3.1.23-1        | testing            | source, amd64, arm64, armel, armhf, i386, mips, mips64el, mipsel, ppc64el, s390x
at         | 3.1.23-1        | unstable           | source, amd64, arm64, armel, armhf, hurd-i386, i386, kfreebsd-amd64, kfreebsd-i386, mips, mips64el, mipsel, ppc64el, s390x
at         | 3.1.23-1        | unstable-debug     | source
```

You're be merging from Debian `unstable`, which in this example is `3.1.23-1`.


(merge-check-existing-bug-entries)=
### Check existing bug entries

Check for any low-hanging fruit in the Debian or Ubuntu bug list that can be wrapped into this merge.

* Ubuntu bug tracker: `https://bugs.launchpad.net/ubuntu/+source/<package>`
* Debian bug tracker: `https://tracker.debian.org/pkg/<package>`

If there are bugs you'd like to fix, make a new SRU-style commit at the end of the merge process and put them together in the same merge proposal. This process is described in the {ref}`merge-adding-new-changes` section.


(merge-make-a-bug-report-for-the-merge)=
### Make a bug report for the merge

Many regular Ubuntu team merges are pre-planned and likely already exist as bugs, or can be found in the team merge schedule.

Merges can also be picked up from [Merge-o-Matic](https://merges.ubuntu.com/main.html), weekly Merge Opportunities Reports (e.g. the [Ubuntu Server report](https://lists.ubuntu.com/archives/ubuntu-server/2024-June/010077.html)), or through awareness being raised for other reasons.

If there is no obvious pre-created bug yet, check if there is an existing merge request bug entry in Launchpad. If you don't find one, create one to avoid duplicate efforts and to allow coordination.

To do so, go to the package's Launchpad page:

`https://bugs.launchpad.net/ubuntu/+source/<package>`

From there, create a new bug report requesting a merge.

:::{admonition} Example bug:

:URL: https://bugs.launchpad.net/ubuntu/+source/at/+filebug
:Summary: "Please merge 3.1.23-1 into noble"
:Description: "tracking bug"
:Result: https://bugs.launchpad.net/ubuntu/+source/at/+bug/1802914

:::

Set the bug status to "in-progress" and assign it to yourself.

To let people who only use Merge-o-Matic know, go to the summary page (for example, [universe](https://merges.ubuntu.com/universe.html)), and if the package is listed there, leave a comment linking to the bug.

This way, those not studying the LP bugs discover more easily that there is already a bug filed for that merge. To do so:

* Click in the {guilabel}`Comment` column on the invisible text entry field.
* Leave a comment like `bug #123456` and press {kbd}`Enter`.
* The page updates and links to your bug.

```{important}
**Save the bug report number, because you'll be using it throughout the merge process.**
```


(merge-get-the-package-repository)=
### Get the package repository

Cloning the repository is the start of all further interactions. If you have already cloned the repository, update it to ensure you have the newest content before taking any further action.


(merge-clone-the-package-repository)=
#### Clone the package repository

```none
$ git ubuntu clone <package> [<package>-gu]
```

Example:

```none
$ git ubuntu clone at at-gu
```

It's a good idea to append some `git-ubuntu` specific label (like `-gu`) to distinguish it from clones of Debian or upstream Git repositories (which tend to want to clone as the same name).


(merge-update-the-package-repository)=
#### Update the package repository

Since this is just Git, the best way to update the `git-ubuntu`-based content (and any other remotes) is to update them all before going into the merge process.

```none
$ git fetch --all
```


(merge-the-merge-process)=
## The merge process


(merge-start-a-git-ubuntu-merge)=
### Start a Git Ubuntu merge

From within the Git source tree:

```none
$ git ubuntu merge start pkg/ubuntu/devel
```

This generates the following tags for you:

| Tag          | Source                                                                   |
| ------------ | ------------------------------------------------------------------------ |
| `old/ubuntu` | `ubuntu/devel`                                                           |
| `old/debian` | last import tag prior to `old/ubuntu` without `ubuntu` suffix in version |
| `new/debian` | `debian/sid`                                                             |

If `git ubuntu merge start` fails, {ref}`merge-start-a-merge-manually`.


(merge-make-a-merge-branch)=
### Make a merge branch

Use the merge tracking bug and the current Ubuntu `devel` version it's going into (in the example of doing a merge below, the current Ubuntu `devel` was `disco`, and the `merge` bug for the case was `LP #1802914`).

```none
$ git checkout -b merge-lp1802914-disco
```

If there's no merge bug, the Debian package version you're merging into can be used (for example, `merge-3.1.23-1-disco`).

:::{admonition} Empty directories warning

A message like the following one when making the merge branch indicates a problem with empty directories:

```none
$ git checkout -b merge-augeas-mirespace-testing
Switched to a new branch 'merge-augeas-mirespace-testing'

WARNING: empty directories exist but are not tracked by git:

tests/root/etc/postfix
tests/root/etc/xinetd.d/arch

These will silently disappear on commit, causing extraneous
unintended changes. See: LP: #1687057.
```

These empty directories can cause the rich history to become lost when uploading them to the Archive. When that happens, use a workaround: {ref}`merge-empty-directories`.

:::

(merge-split-commits)=
### Split commits

In this phase, split old-style commits that grouped multiple changes together.


(merge-check-if-there-are-commits-to-split)=
### Check if there are commits to split

```none
$ git log --oneline

2af0cb7 (HEAD -> merge-3.1.20-6-disco, tag: reconstruct/3.1.20-3.1ubuntu2, tag: split/3.1.20-3.1ubuntu2) import patches-unapplied version 3.1.20-3.1ubuntu2 to ubuntu/disco-proposed
2a71755 (tag: pkg/import/3.1.20-5) Import patches-unapplied version 3.1.20-5 to debian/sid
9c3cf29 (tag: pkg/import/3.1.20-3.1) Import patches-unapplied version 3.1.20-3.1 to debian/sid
...
```

Get all commit hashes since `old/debian` and check the summary for what they changed using:

```none
$ git log --stat old/debian..
```

Example (from merging the `heimdal` package):

```none
$ git log --stat old/debian..

commit 9fc91638b0a50392eb9f79d45d68bc5ac6cd6944 (HEAD ->
merge-7.8.git20221117.28daf24+dfsg-1-lunar)
Author: Michal Maloszewski <michal.maloszewski@canonical.com>
Date:   Tue Jan 17 16:16:01 2023 +0100

    Changelog for 7.8.git20221117.28daf24+dfsg-1

 debian/changelog | 1 -
 1 file changed, 1 deletion(-)


commit e217fae2dc54a0a13e4ac5397ec7d3be527fa243
Author: Michal Maloszewski <michal.maloszewski@canonical.com>
Date:   Tue Jan 17 16:13:49 2023 +0100

    update-maintainer

 debian/control | 3 ++-
 1 file changed, 2 insertions(+), 1 deletion(-)


commit 3c66d873330dd594d593d21870f4700b5e7fd153
Author: Michal Maloszewski <michal.maloszewski@canonical.com>
Date:   Tue Jan 17 16:13:49 2023 +0100

    reconstruct-changelog

 debian/changelog | 10 ++++++++++
 1 file changed, 10 insertions(+)


commit 58b895f5ff6333b1a0956dd83e478542dc7a10d3
Author: Michal Maloszewski <michal.maloszewski@canonical.com>
Date:   Tue Jan 17 16:13:46 2023 +0100

    merge-changelogs

 debian/changelog | 68
 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
 1 file changed, 68 insertions(+)
```

This command shows the specific commit, as well as what changed within the commit (i.e., how many files were changed and how many insertions and deletions there were).

Common examples of commits that need to be split:

* `changelog` with any other file(s) changed in a single commit
* `debian/changelog` with any other file(s) changed in a single commit
* commit named: `Import patches-unapplied version 1.2.3ubuntu4 to ubuntu/cosmic-proposed`, where it's applying from an Ubuntu source rather than a Debian one (in this case `ubuntu4`)

You should still look over all commits just to make sure.

If there are no commits to split, {ref}`add the "split" tag <merge-tag-split>` and continue to {ref}`merge-prepare-the-logical-view`.


(merge-identify-logical-changes)=
#### Identify logical changes

The next step is to separate the changes into logical units. For the {pkg}`at` package, this is trivial: put the {file}`changelog` change in one commit and the {file}`control` change in the other.

The second example, for {pkg}`nspr`, is more instructive. Here we have 5 files changed that need to be split out:

* All changelog changes go to one commit called `changelog`.
* Update maintainer (in `debian/control`) goes to one commit called `update maintainers`.
* All other logically separable commits go into individual commits.

Look in {file}`debian/changelog`:

```none
nspr (2:4.18-1ubuntu1) bionic; urgency=medium

  * Resynchronize with Debian, remaining changes
    - rules: Enable Thumb2 build on armel, armhf.
    - d/p/fix_test_errcodes_for_runpath.patch: Fix testcases to handle
      zesty linker default changing to --enable-new-dtags for -rpath.
```

There are two logical changes, which you need to separate. Look at the changes in individual files to see which file changes should be logically grouped together.

Example:

```none
$ git show d7ebe661 -- debian/rules
```

In this case, the following file changes are separated into logical units:

:::{list-table}
*    - File(s)
     - Logical unit
*    - `debian/rules`
     - Enable `Thumb2` build on `armel`, `armhf`
*    - `debian/patches/*`
     - Fix test cases to handle `zesty` linker default<br>changing to `--enable-new-dtags` for `-rpath`
*    - `debian/control`
     - Change maintainer
*    - `debian/changelog`
     - Changelog
:::


(merge-split-into-logical-commits)=
#### Split into logical commits

Start a rebase at `old/debian`, and then reset to `HEAD^` to bring back the changes as uncommitted changes.

1. Start a rebase: `git rebase -i old/debian`
1. Change the commit(s) you're going to separate from `pick` to `edit`
1. Do a `git reset` to get your changes back: `git reset HEAD^`

Next, add the commits:

------------------------------------------------------------------------------

Logical unit:

```none
$ git add debian/patches/*
$ git commit
```

Commit message:

```none
  * d/p/fix_test_errcodes_for_runpath.patch: Fix testcases to handle
    zesty linker default changing to --enable-new-dtags for -rpath.
```

------------------------------------------------------------------------------

Logical unit:

```none
$ git add debian/rules
$ git commit
```

Commit message:

```none
  * d/rules: Enable Thumb2 build on armel, armhf.
```

------------------------------------------------------------------------------

Maintainers:

```none
$ git commit -m "update maintainers" debian/control
```

------------------------------------------------------------------------------

Changelog:

```none
$ git commit -m changelog debian/changelog
```

------------------------------------------------------------------------------

Finally, complete the rebase:

```none
$ git rebase --continue
```

The result of this rebase should be a sequence of smaller commits, one per `debian/changelog` entry (with potentially additional commits for previously undocumented changes).

It should represent a granular history (viewable with `git log`) for the latest Ubuntu version and no content differences to that Ubuntu version. This can be verified with `git diff -p old/ubuntu`.


(merge-tag-split)=
#### Tag split

Do this even if there were no commits to split:

```none
$ git ubuntu tag --split
```

:::{admonition} Purpose of logical tags

If we do this step, we have a distinct boundary between looking at the past (analysis of what is there already) and the actual work we want to perform (bringing the old Ubuntu delta forward).

By having a well-defined point, it is easier to do the future work, and also for a reviewer to start from the same point. The reviewer can easily and almost completely automatically determine if the logical tag is correct.

The logical tag is the cleanest possible representation of a previous Ubuntu delta. By determining this representation, we make it as easy as possible to bring the delta forward.

:::


(merge-prepare-the-logical-view)=
### Prepare the logical view

In this phase, make a clean, "logical" view of the history. This history is cleaned up (but has the same delta) and only contains the actual changes that affect the package's behavior.

Start with a rebase from `old/debian`:

```none
$ git rebase -i old/debian
```

Do some cleaning:

* Delete imports, etc.
* Delete any commit that only changes metadata like changelog or maintainer.
* Possibly rearrange commits if it makes logical sense.

Squash these kinds of commits together:

 * Changes and reversions of those changes because they result in no change.
 * Multiple changes to the same patch file because they should be a logical unit.

To squash a commit, move its line underneath the one you want it to become part of, and then change it from `pick` to `fixup`.


(merge-check-the-result)=
#### Check the result

At the end of the "squash and clean" phase, the only delta you should see from the split tag is:

```none
$ git diff --stat split/6.8-0ubuntu2
 debian/changelog | 31 -------------------------------
 debian/control   |  3 +--
 2 files changed, 1 insertion(+), 33 deletions(-)
```

Only `changelog` and `control` were changed, which is what we want.


(merge-create-logical-tag)=
#### Create logical tag

What is the logical tag? It is a representation of the Ubuntu delta present against a specific historical package version in Ubuntu.

```none
$ git ubuntu tag --logical
```

This may fail with an error like:

```none
ERROR:HEAD is not a defined object in this git repository.
```

In which case, {ref}`merge-create-logical-tag-manually`.


(merge-rebase-onto-new-debian)=
### Rebase onto new Debian

```none
$ git rebase -i --onto new/debian old/debian
```


(merge-conflicts)=
#### Conflicts

If a conflict occurs, you must resolve them. Do so by modifying the conflicting commit during the rebase.

For example, merging `logwatch 7.5.0-1`:

```none
$ git rebase -i --onto new/debian old/debian
...
CONFLICT (content): Merge conflict in debian/control
error: could not apply c0efd06... - Drop libsys-cpu-perl and libsys-meminfo-perl from Recommends to
...
```

Look at the conflict in `debian/control`:

```none
    <<<<<<< HEAD
    Recommends: libdate-manip-perl, libsys-cpu-perl, libsys-meminfo-perl
    =======
    Recommends: libdate-manip-perl
    Suggests: fortune-mod, libsys-cpu-perl, libsys-meminfo-perl
    >>>>>>> c0efd06... - Drop libsys-cpu-perl and libsys-meminfo-perl from Recommends to
```

Upstream removed `fortune-mod` and deleted the entire line because it was no longer needed. Resolve it to:

```none
Recommends: libdate-manip-perl
Suggests: libsys-cpu-perl, libsys-meminfo-perl
```

Continue with the rebase:

```none
$ git add debian/control
$ git rebase --continue
```


(merge-corollaries)=
#### Corollaries

Mistake corrections are squashed.

Changes that fix mistakes made previously in the same delta are squashed against them. For example:

* `2.3-4ubuntu1` was the previous merge.
* `2.3-4ubuntu2` adjusted `debian/rules` to add the `--build-beter` configure flag.
* `2.3-4ubuntu3` fixed the typo in `debian/rules` to say `--build-better` instead.
* When the logical tag is created, there is one commit relating to `--build-better`, which omits any mention of the typo.

:::{note}
If a mistake exists in the delta itself, it is retained. For example, if `2.3-4ubuntu3` was never uploaded and the typo is still present in `2.3-4ubuntu2`, then `logical/2.3.-4ubuntu2` should contain a commit adding the configure flag with the typo still present.
:::


(merge-empty-commits)=
#### Empty commits

If a commit becomes empty, it's because the change has already been applied upstream:

```none
The previous cherry-pick is now empty, possibly due to conflict resolution.
```

In such a case, drop the commit:

```none
$ git rebase --abort
$ git rebase -i old/debian
```

Keep a copy of the redundant commit's commit message, then delete it in the rebase.


(merge-sync-request)=
#### Sync request

If all the commits are empty, or you realized there are no logical changes, you're facing a **sync request**, not a merge. Refer to the {ref}`sync guidelines <sync-process>` to continue.


(merge-check-patches-still-apply-cleanly)=
#### Check patches still apply cleanly

```none
$ quilt push -a --fuzz=0
```

**If {command}`quilt` fails**

Quilt can fail at this point if the file being patched has changed significantly upstream. The most common reason is that the issue the patch addresses has since been fixed upstream.

For example:

```none
$ quilt push -a --fuzz=0
...
Applying patch ssh-ignore-disconnected.patch
patching file scripts/services/sshd
Hunk #1 FAILED at 297.
1 out of 1 hunk FAILED -- rejects in file scripts/services/sshd
Patch ssh-ignore-disconnected.patch does not apply (enforce with -f)
```

If this patch fails because the changes in `ssh-ignore-disconnected.patch` are already applied upstream, you must remove this patch.

```none
$ git log --oneline

1aed93f (HEAD -> ubuntu/devel)   * d/p/ssh-ignore-disconnected.patch: [sshd] ignore disconnected from user     USER (LP: 1644057)
7d9d752 - Drop libsys-cpu-perl and libsys-meminfo-perl from Recommends to   Suggests as they are in universe.
```

Removing `1aed93f` removes the patch.

1. Save the commit message from `1aed93f` for later including it in the `Drop Changes` section of the new changelog entry.
1. `git rebase -i 7d9d752` and delete commit `1aed93f`.


(merge-unapply-patches-before-continuing)=
#### Unapply patches before continuing

```none
$ quilt pop -a
```


(merge-adding-new-changes)=
### Adding new changes

Add any new changes you want to include with the merge. For instance, the new package version may {term}`fail to build from source (FTBFS) <FTBFS>` in Ubuntu due to new versions of specific libraries or runtimes.

Each logical change should be in its own commit to match the work done up to this point on splitting the logical changes.

Moreover, there is no need to add changelog entries for these changes manually. They are generated from the commit messages with the merge finish process described below.


(merge-finish-the-merge)=
### Finish the merge

```none
$ git ubuntu merge finish pkg/ubuntu/devel
```

If this fails, {ref}`merge-finish-the-merge-manually`.


(merge-fix-the-changelog)=
### Fix the changelog

`git-ubuntu` attempts to put together a changelog entry, but it will likely have problems. Fix it to make sure it follows the standards. See {ref}`committing your changes <committing-changes>` for information about what it
should look like.


(merge-add-dropped-changes)=
#### Add dropped changes

If you dropped any changes (due to upstream fixes), you must note them in the changelog entry:

```none
  * Drop Changes:
    - Foo: change to bar
      [Fixed in 1.2.3-4]
```


(merge-format-any-new-added-changes)=
#### Format any new added changes

If you added any new changes, they should be in their own section in the changelog:

```none
  * New Changes:
    - Bar: change to foo
    - Baz: adjust for Foo changes
```


(merge-commit-the-changelog-fix)=
#### Commit the changelog fix

```none
$ git commit debian/changelog -m changelog
```


(merge-no-changes-to-debian-changelog)=
#### No changes to debian/changelog

The range `old/ubuntu..logical/<version>` should contain no changes to `debian/changelog` at all. We do not consider this part of the logical delta. So, any commits that contain only changes to `debian/changelog` should be dropped.

:::{note}
If you {command}`diff` your final logical tag against the Ubuntu package it analyses, the diff should be empty, except:

1. All changes to `debian/changelog`:

   We deliberately exclude these from the logical tag, relying on commit messages instead.

1. The change that `update-maintainer` introduced, and (rarely) similar changes like a change to `Vcs-Git` headers to point to an Ubuntu VCS instead.

   For the purposes of this workflow, these are not considered part of our "logical delta", and instead are re-added at the end.
:::

:::{tip}
You can use the {command}`execsnoop-bpfcc` tool from the {pkg}`bpfcc-tools` package to find what `debhelper` scripts were called for a certain package. This is helpful for debugging what scripts were called, and what parameters were passed to them.

For example:

```none
$ sudo execsnoop-bpfcc -n multipath
```

Now in another shell run:

```none
$ sudo apt install --reinstall multipath-tools
```

In the original shell, you should see something like:

```none
PCOMM            PID     PPID    RET ARGS
multipath-tools  13939   13931     0 /var/lib/dpkg/info/multipath-tools.prerm upgrade 0.9.4-5ubuntu3
multipath-tools  13951   13931     0 /var/lib/dpkg/info/multipath-tools.postrm upgrade 0.9.4-5ubuntu3
multipath-tools  13959   13956     0 /var/lib/dpkg/info/multipath-tools.postinst configure 0.9.4-5ubuntu3
multipathd       14009   1         0 /sbin/multipathd -d -s
```
:::


(merge-cheat-sheet)=
## A brief summary of this phase (cheat sheet)

1. `rmadison <package_name>`
1. `rmadison -u debian <package_name>`
1. `git ubuntu clone <package_name> <package_name>-gu`
1. `cd <package_name>-gu`
1. `git ubuntu merge start pkg/ubuntu/devel`
1. `git checkout -b merge-<version_of_debian_unstable>-<current_ubuntu_devel_name>`
1. `git log --stat old/debian..`
1. `git ubuntu tag --split` (if there's nothing to split, type that command straight away)
1. `git rebase -i old/debian`
1. Drop metadata changes and reorder/merge/split commits.
1. `git diff split/`
1. `git ubuntu tag --logical`
1. `git show logical/<version>` (check if the new tag exists)
1. `git rebase -i --onto new/debian old/debian`
1. `quilt push -a --fuzz=0`
1. `quilt pop -a`
1. `git ubuntu merge finish pkg/ubuntu/devel`


(merge-upload-a-ppa)=
## Upload a PPA


(merge-get-the-orig-tarball)=
### Get the orig tarball

Ubuntu doesn't know about the new tarball yet, so we must create it.

```none
$ git ubuntu export-orig
```

If the upstream version does not yet exist in Ubuntu, that is, the new package from Debian also includes a new upstream version, you should add the `--for-merge` option:

```none
$ git ubuntu export-orig --for-merge
```

If this fails, {ref}`do it manually <merge-get-the-orig-tarball-manually>`.


(merge-build-source-package)=
### Build source package

```none
$ dpkg-buildpackage \
    --build=source \
    --no-pre-clean \
    --no-check-builddeps \
    -sa \
    -v3.1.20-3.1ubuntu2
```

The switches are:

`-sa`
: include orig tarball (required on a merge)

`-vXYZ`
: include changelog since `XYZ`

As the merge upload represents all changes that happened in Debian since the last merge plus anything added as part of the merge itself, `-v` should usually point to the last published Ubuntu version. For example:

1. Ubuntu merged as `1.3-1ubuntu1`.
1. Then Ubuntu had a fix in `1.3-1ubuntu2`.
1. But in the meantime, Debian merged upstream as `1.4-1`.
1. And then Debian added a fix in `1.4-2`.
1. New Ubuntu will be `1.4-2ubuntu1`.
1. `-v` should be set to `1.3-1ubuntu2`.
   1. Thereby the `.changes` file will include `1.4-1`, `1.4-2`, and `1.4-2ubuntu1`.
   1. That represents all the changes that happened from the perspective of an Ubuntu user upgrading from `1.3-1ubuntu2` to `1.4-2ubuntu1`.

:::{note}
If sponsoring a merge or any other upload for someone else, remember the need to sign their upload with your key. See {ref}`Sponsor a package <sponsor-a-package>` for more information about that.

Furthermore just like you, the sponsor needs to know about setting `-v` right and using `-sa` when needed. If in doubt, coordinating with them is helpful.
:::


(merge-push-to-your-launchpad-repository)=
### Push to your Launchpad repository

Now that the package builds successfully, push it to your Launchpad repository:

```none
git push <your-lp-username>
```

You get an error message and a suggestion for how to set an `upstream` branch. For example:

```none
$ git push kstenerud
fatal: The current branch merge-lp1802914-disco has no upstream branch.
To push the current branch and set the remote as upstream, use

    git push --set-upstream kstenerud merge-lp1802914-disco
```

Run the suggested command to push to your repository.


(merge-push-your-lp-tags)=
#### Push your `lp` tags

```none
$ git push <your-git-remote> old/ubuntu old/debian new/debian \
           reconstruct/<version> logical/<version> split/<version>
```

For example:

```none
$ git push git+ssh://kstenerud@git.launchpad.net/~kstenerud/ubuntu/+source/at \
           old/ubuntu old/debian new/debian \
           reconstruct/3.1.20-3.1ubuntu2 \
           logical/3.1.20-3.1ubuntu2 \
           split/3.1.20-3.1ubuntu2

To ssh://git.launchpad.net/~kstenerud/ubuntu/+source/at
 * [new tag]         split/3.1.20-3.1ubuntu2 -> split/3.1.20-3.1ubuntu2
 * [new tag]         logical/3.1.20-3.1ubuntu2 -> logical/3.1.20-3.1ubuntu2
 * [new tag]         new/debian -> new/debian
 * [new tag]         old/debian -> old/debian
 * [new tag]         old/ubuntu -> old/ubuntu
 * [new tag]         reconstruct/3.1.20-3.1ubuntu2 -> reconstruct/3.1.20-3.1ubuntu2
```


(merge-create-a-ppa)=
### Create a PPA

You need to have a {term}`PPA` for reviewers to test.


(merge-create-a-ppa-repository)=
#### Create a PPA repository

`https://launchpad.net/~<your-username>/+activate-ppa`

Give it a name that identifies the package name, Ubuntu version, and bug number, such as `at-merge-1802914`.

:::{important}
Be sure to enable all architectures to check that it builds (click {guilabel}`Change details` in the top right corner of the newly created PPA page).
:::

The URL of the PPA is formed as follows:

`https://launchpad.net/~<your-username>/+archive/ubuntu/<PPA-name>`

For example:

`https://launchpad.net/~kstenerud/+archive/ubuntu/disco-at-merge-1802914`


(merge-upload-files)=
#### Upload files

```none
$ dput ppa:kstenerud/disco-at-merge-1802914 ../at_3.1.23-1ubuntu1_source.changes
```


(merge-wait-for-packages-to-be-ready)=
#### Wait for packages to be ready

1. Check the PPA page to see when packages are finished building:

   [`https://launchpad.net/~kstenerud/+archive/ubuntu/disco-at-merge-1802914`](https://launchpad.net/~kstenerud/+archive/ubuntu/disco-at-merge-1802914)

2. Look at the package contents to make sure they have actually been published (click {guilabel}`View package details` in the top right corner of the PPA page, or append `+packages` to its URL):

   [`https://launchpad.net/~kstenerud/+archive/ubuntu/disco-at-merge-1802914/+packages`](https://launchpad.net/~kstenerud/+archive/ubuntu/disco-at-merge-1802914/+packages)


(merge-test-the-new-build)=
## Test the new build

Test the following:

1. {ref}`Run package tests (if any) <package-tests>`
1. {ref}`Upgrading from the previous version <merge-test-upgrading-from-the-previous-version>`
1. {ref}`Installing the latest where nothing was installed before <merge-test-installing-the-latest-from-scratch>`
1. {ref}`Other smoke tests <merge-other-smoke-tests>`


(merge-test-upgrading-from-the-previous-version)=
### Test upgrading from the previous version

1. Create and start a new LXD container to test in:

    ```none
    $ lxc launch ubuntu-daily:ubuntu/<ubuntu-codename> tester && lxc exec tester bash
    ```

1. Install the currently available version of the package you've been working on:

    ```none
    $ apt update && apt dist-upgrade -y && apt install -y at
    ```

1. Run the test:

    ```none
    echo "echo xyz > test.txt" | at now + 1 minute && sleep 1m && cat test.txt && rm test.txt
    ```

1. Add your PPA to the virtual system to upgrade the package to the version you want to test:

    ```none
    $ sudo add-apt-repository -y ppa:kstenerud/at-merge-lp1802914
    ```

    If the Ubuntu release for which you've built the package is not yet available, modify the source list entry. For example:

    ```none
    $ vi /etc/apt/sources.list.d/kstenerud-ubuntu-at-merge-lp1802914-cosmic.list
    * change cosmic to disco
    ```

1. Upgrade to the new version of the package from your PPA:

    ```none
    $ apt update && apt dist-upgrade -y
    ```

1. Test the upgraded version:

    ```none
    $ echo "echo abc > test.txt" | at now + 1 minute && sleep 1m && cat test.txt && rm test.txt
    ```


(merge-test-installing-the-latest-from-scratch)=
### Test installing the latest from scratch

1. Create and start a new LXD container to test in:

    ```none
    $ lxc launch ubuntu-daily:ubuntu/<ubuntu-codename> tester && lxc exec tester bash
    ```

1. Add your PPA to the virtual system to upgrade the package to the version you want to test:

    ```none
    $ sudo add-apt-repository -y ppa:kstenerud/at-merge-lp1802914
    ```

1. Install the new version of the package from your PPA:

    ```none
    $ apt update && apt dist-upgrade -y && apt install -y at
    ```

1. Run the test:

    ```none
    echo "echo xyz > test.txt" | at now + 1 minute && sleep 1m && cat test.txt && rm test.txt
    ```


(merge-other-smoke-tests)=
### Other smoke tests

* Run various basic commands.

* Run [regression tests](https://git.launchpad.net/qa-regression-testing).

* For a package that `Build-Depends` on itself (`openjdk`, `jruby`, `kotlin`, etc.), build it using the new version.


(merge-submit-merge-proposal)=
## Submit Merge Proposal (MP)

:::{note}
Git branches with `%` in their name don't work. Use something like `_`.
:::

```none
$ git ubuntu submit --reviewer $REVIEWER --target-branch debian/sid
Your merge proposal is now available at: https://code.launchpad.net/~kstenerud/ubuntu/+source/at/+git/at/+merge/358655
If it looks OK, please move it to the 'Needs Review' state.
```

Set `--reviewer` to the team (or user) on Launchpad that should look at your change -- by default it is `--reviewer ubuntu-sponsors`.

* If you do not have upload rights for this package, use `ubuntu-sponsors` here. That adds your Merge Proposal to the
  [Ubuntu sponsoring queue](http://sponsoring-reports.ubuntu.com/general.html), so people with upload rights for that package may eventually review it for you.

* To notify a specific team, use, e.g. `canonical-foundations`, `canonical-public-cloud`, or `ubuntu-server`.

To avoid having to specify the `--reviewer` flag, configure the reviewers for {command}`git-ubuntu`. Include a section like the following either globally in `~/.gitconfig`, or in individual repositories in `.git/config`:

```ini
[gitubuntu.submit]
    defaultReviewer = <your-ubuntu-teamname>, \
                      <canonical-more-reviewers>, \
                      <canonical-otherteam>
```

The equivalent `git config` command is:

```none
$ git config [--global] gitubuntu.submit.defaultReviewer <launchpad-reviewer>
```

:::{note}
Using a target branch of `debian/sid` may seem wrong, but is a workaround for {lpbug}`1976112`.
:::

If this fails, {ref}`do it manually <merge-submit-merge-proposal-manually>`.


(merge-update-the-merge-proposal)=
### Update the merge proposal

* Link the PPA.

* Add any other info (as a comment) that can help the reviewer.

  Example:

  ```
  PPA: https://launchpad.net/~kstenerud/+archive/ubuntu/disco-at-merge-1802914

  Basic test:
  $ echo "echo abc >test.txt" | at now + 1 minute && sleep 1m && cat test.txt && rm test.txt

  Package tests:
  This package contains no tests.
  ```

(merge-open-the-review)=
### Open the review

Change the MP status from {guilabel}`work in progress` to {guilabel}`needs review`.


(merge-follow-the-migration)=
## Follow the migration

Once the merge proposal goes through, you must follow the package to make sure it gets to its destination.


(merge-package-tests)=
### Package tests

The results from the latest package tests is published for each Ubuntu release. For example: [autopkgtest.ubuntu.com/packages/o/openssh/questing/amd64](http://autopkgtest.ubuntu.com/packages/o/openssh/questing/amd64).


(merge-proposed-migration)=
### Proposed migration

The status of all packages is available from the [Ubuntu archive](https://ubuntu-archive-team.ubuntu.com/proposed-migration/) or one of its subdirectories. The top level directory is for the current dev release. Previous releases are in subdirectories.

-----------------------------------------------------------------------------


(merge-start-a-merge-manually)=
## Start a merge manually


(merge-generate-the-merge-branch)=
### Generate the merge branch

Create a branch to do the merge work in:

```none
$ git checkout -b merge-lp1802914-disco
```


(merge-create-tags)=
### Create tags

| Tag          | Source                                                                   |
| ------------ | ------------------------------------------------------------------------ |
| `old/ubuntu` | `ubuntu/<Ubuntu_release>-devel`                                          |
| `old/debian` | Last import tag prior to `old/ubuntu` without `ubuntu` suffix in version |
| `new/debian` | `debian/sid`                                                             |

As per [Debian releases](https://www.debian.org/releases/), `debian/sid` always matches Debian "unstable".

Find the last import tag using {command}`git log`:

```none
git log | grep "tag: pkg/import" | grep -v ubuntu | head -1

commit 9c3cf29c05c3fddd7359e71c978ff9a9a76e4404 (tag: pkg/import/3.1.20-3.1)
```

Based on that, create the following tags:

```none
$ git tag old/ubuntu pkg/ubuntu/disco-devel
$ git tag old/debian 9c3cf29c05c3fddd7359e71c978ff9a9a76e4404
$ git tag new/debian pkg/debian/sid
```


(merge-start-a-rebase)=
### Start a rebase

```none
$ git rebase -i old/debian
```


(merge-clear-any-history)=
### Clear any history, up to and including the last Debian version

Clear any history, up to and including the last Debian version. If the package hasn't been updated since the Git repository structure changed, it grabs all changes throughout time rather than since the last Debian version. Delete the older lines from the interactive rebase.

In this case, up to, and including the import of `3.1.20-3.1`.


(merge-create-reconstruct-tag)=
### Create reconstruct tag

```none
$ git ubuntu tag --reconstruct
```

Next step: {ref}`merge-split-commits`.


(merge-create-logical-tag-manually)=
### Create logical tag manually

Use the version number of the last ubuntu change. So, if there are:

* `3.1.20-3.1ubuntu1`
* `3.1.20-3.1ubuntu2`
* `3.1.20-3.1ubuntu2`

Run:

```none
$ git tag -a -m "Logical delta of 3.1.20-3.1ubuntu2" logical/3.1.20-3.1ubuntu2
```

:::{note}
Certain characters aren't allowed in Git. For example, replace colons (`:`) with percentage signs (`%`).
:::

Next step: {ref}`merge-rebase-onto-new-debian`.


(merge-finish-the-merge-manually)=
### Finish the merge manually

1. Merge the changelogs of old Ubuntu and new Debian:

    ```none
    $ git show new/debian:debian/changelog > /tmp/debnew.txt
    $ git show old/ubuntu:debian/changelog > /tmp/ubuntuold.txt
    $ merge-changelog /tmp/debnew.txt /tmp/ubuntuold.txt > debian/changelog
    $ git commit -m "Merge changelogs" debian/changelog
    ```

1. Create a new changelog entry for the merge:

    ```none
    $ dch -i
    ```

    Which creates, for example:

    ```none
    at (3.1.23-1ubuntu1) disco; urgency=medium

    * Merge with Debian unstable (LP: #1802914). Remaining changes:
        - Suggest an MTA rather than Recommending one.

    -- Karl Stenerud <karl.stenerud@canonical.com>  Mon, 12 Nov 2018 18:11:53 +0100
    ```

1. Commit the changelog:

    ```none
    $ git commit -m "changelog: Merge of 3.1.23-1" debian/changelog
    ```

1. Update maintainer:

    ```none
    $ update-maintainer
    $ git commit -m "Update maintainer" debian/control
    ```

Next step: {ref}`merge-fix-the-changelog`


(merge-get-the-orig-tarball-manually)=
### Get the orig tarball manually

Use the {manpage}`pristine-tar(1)` tool to regenerate the orig (upstream) tarball:

1. Create a new branch for the orig tarball:

    ```none
    $ git checkout -b pkg/importer/debian/pristine-tar
    ```

1. Regenerate the pristine tarball:

    ```none
    $ pristine-tar checkout at_3.1.23.orig.tar.gz
    ```

1. Switch to the merge branch:

    ```none
    $ git checkout merge-3.1.23-1-disco
    ```

    TODO: Is this ^ branch name correct?


(merge-if-git-checkout-also-fails)=
#### If git checkout also fails

```none
$ git checkout merge-lp1802914-disco
$ cd /tmp
$ pull-debian-source at
$ mv at_3.1.23.orig.tar.gz{,.asc} ~/work/packages/ubuntu/
$ cd -
```

TODO: This step needs context/explanation.

Next step: Check the source for errors.


(merge-submit-merge-proposal-manually)=
### Submit merge proposal manually

```none
$ git push kstenerud merge-lp1802914-disco
```

Then create a MP manually in Launchpad, and save the URL.

Next step: {ref}`merge-update-the-merge-proposal`.


(merge-known-issues)=
## Known issues


(merge-empty-directories)=
### Empty directories

Use the [{command}`emptydirfixup.py`](https://git.launchpad.net/~racb/git-ubuntu/plain/wip/emptydirfixup.py?h=emptydirfixup) Python script (by Robie Basak, [@racb](https://launchpad.net/~racb)) to locally restore empty directories (see the script for a detailed explanation of why empty directories are a problem).

Example use:

```none
$ git ubuntu clone apache2
$ cd apache2
$ git tag -f base
  <add commits>
$ python3 emptydirfixup.py fix-many base
$ git ubuntu tag --upload
```

For an entire real case, follow this workflow:

1. Get the {command}`emptydirfixup.py` script:

    ```none
    $ wget -O ../emptydirfixup.py \
      "https://git.launchpad.net/~racb/usd-importer/plain/wip/emptydirfixup.py?h=emptydirfixup"
    ```

1. Clone as usual:

    ```none
    $ git ubuntu clone "<source_package>" "<source_package>-gu"
    $ cd "<source_package>-gu/"
    ```

1. Create the merge branch (here you see the warning message):

    ```none
    $ git checkout "<last_remote>" -b "<branch_name>"
    ```

1. Tag the base and rebase on the `ubuntu/devel` branch:

    ```none
    $ git tag -f base
    $ git checkout ubuntu/devel
    $ git rebase base
    ```

1. Start the merge:

    ```none
    $ git ubuntu merge -f start
    ```

1. Merge work as usual...

1. Workaround for `ERROR: Empty directories exist...` (see {lpbug}`1939747`):

    ```none
    $ rm .git/hooks/pre-commit
    ```

1. Finish the merge:

    ```none
    $ git ubuntu merge finish pkg/ubuntu/devel
    ```

1. Create a MP as usual, get reviewed/approved, etc.

1. Fix the set of commits with empty directories:

    ```none
    $ python3 ../emptydirfixup.py fix-many base
    ```

1. Build the package:

    ```none
    $ debuild -S $(git ubuntu push-for-upload)
    ```

1. Upload:

    ```none
    $ git push pkg "upload/<version>"
    $ dput ubuntu "<changes_file>"
    ```

1. Done!
