# Third-party components

Nothing third-party is vendored in this repository. The following are used at build or test time and come from
[Charon](https://github.com/kern0x1b/charon) packages or from their own upstreams.

| Component | Version | Licence | Where it comes from |
| --- | --- | --- | --- |
| [Styx](https://github.com/kern0x1b/styx) | 2026.09.20 (`f5fe651`) | MIT | the `charon@styx` package, a fork of [OpenCombine](https://github.com/OpenCombine/OpenCombine) (MIT, Copyright its authors; the licence text is kept in the fork); the Combine implementation the module re-exports as module `Combine`. `combine/` runs the upstream OpenCombine tests, cloned into `src/`, and is kept as the record of that ancestor |
| Swift runtime and standard library | 6.4 | Apache-2.0 with Runtime Library Exception | the `charon@swift-runtime` package; the runtime an app built with Eidolon carries |
| libc++ / libc++abi | 23.1.1 | Apache-2.0 with LLVM exceptions | the `charon@libcxx` package |

Eidolon re-implements the shape of Apple's public SwiftUI API and contains no code or assets of Apple's. The lists of
public type and modifier names in `bridge/` are identifiers only. `bridge/prepare-fw.sh` makes a local, git-ignored copy
of a framework from the reader's own iOS SDK to compare against; that copy is not part of this repository and must not
be committed or passed on.
