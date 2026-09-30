# Handoff

## 2026-06-12

- `README.md` now covers the item detail behavior introduced by commit `122ac2a`.
- `--detail` values correspond to `--item` values by index and are optional.
- Actual newlines and escaped `\n` sequences are both supported.
- Verification: run `GOCACHE=/tmp/go-build-cache go test ./...`.
