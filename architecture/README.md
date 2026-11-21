# Architecture Documentation

Reference material for maintainers and new contributors. It explains how `logging.sh` and the test suite are put together. It is not user documentation.

This directory is deliberately outside `docs/`. The `docs/` directory is user-facing: it is what the [shelltools.pro](https://shelltools.pro) documentation site
publishes. Keep contributor material out of it.

**Version:** these documents describe **bash-logger 3.0.3**. Function lists, counts and line numbers drift as the code changes.

## Contents

* [logging-sh-reference.md](logging-sh-reference.md): layers, public interface, every internal function by subsystem, lifecycle walkthroughs, design patterns, global state
  and the call graph.
* [tests-reference.md](tests-reference.md): the runner, the helper library, the life of one test, the suite catalogue, the cross-shell machinery, the coverage map and CI.
* [logging-sh-architecture.drawio](logging-sh-architecture.drawio): editable diagrams for the `logging.sh` reference (7 pages).
* [tests-architecture.drawio](tests-architecture.drawio): editable diagrams for the test reference (6 pages).
* [images/](images/): SVG previews of every diagram page.

To change a diagram, edit the `.drawio` file in [draw.io](https://www.drawio.com/) and export the page again to `images/`.

For the day-to-day workflow, see [docs/testing.md](../docs/testing.md) and [docs/writing-tests.md](../docs/writing-tests.md).
