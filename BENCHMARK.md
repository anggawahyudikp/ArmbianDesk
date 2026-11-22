# ArmbianDesk Benchmark Report (`T12`)

## Collector Status
- **Collector Verification**: `./bin/armbiandesk benchmark --duration 2 --interval 1` executed and verified (`PASS` on x86_64 development host).
- **Controlled ARM64 Hardware A/B Benchmark (`T12` Workloads A–E)**: **`NOT RUN`**
  - **Reason**: No separate authorized non-production ARM64 test STB was provisioned for controlled idle/browser/video settle-and-sample runs, and the operational STB must not be restarted, altered, or stressed.

## How to Run Controlled Benchmarks on Test Hardware
On an authorized ARM64 test unit (e.g. ZTE B860H running Armbian), run read-only measurements after a 120-second settle window for each workload:

1. **Workload A (`minimal` desktop only, no browser)**:
   ```bash
   ./bin/armbiandesk benchmark --duration 60 --interval 2 --output ./benchmarks/workload-a-minimal
   ```
2. **Workload B (`desktop` profile, no browser)**:
   ```bash
   ./bin/armbiandesk benchmark --duration 60 --interval 2 --output ./benchmarks/workload-b-desktop
   ```
3. **Workload C (`minimal` + fresh Chromium profile on static demo page)**:
   ```bash
   ./bin/armbiandesk benchmark --duration 60 --interval 2 --output ./benchmarks/workload-c-static
   ```
4. **Workload D & E (Representative multi-tab / 360p–480p video)**:
   Record actual player stats, `MemAvailable`, `PSI memory full avg10`, `zram` compressed physical cost (`mm_stat`), `pswpin`/`pswpout` deltas, and component `PSS` from the JSON output.

## Engineering Targets (Not Pre-Claimed Passes)
- Desktop-only idle CPU median: `<= 5%`
- Minimal desktop component overhead (`PSS`): `<= 80 MiB` (`desktop` profile: `<= 150 MiB`)
- Sustained `PSI memory full avg10 <= 5%` without OOM or UI hang during dual-tab workload.
