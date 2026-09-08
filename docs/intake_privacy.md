# Intake Privacy Posture

## Rules

1. **No raw client data is committed to git.** The `intake/.gitignore` blocks all CSV and XLSX files except templates. The `intake/output/` directory is gitignored. The wizard deletes both the uploaded file and any converted CSV automatically (a `finally` block, so validation errors cannot skip cleanup).

2. **No raw counterparty names appear on the public dashboard.** The intake wizard runs only behind the `BYOL_INTAKE=1` environment-variable gate. The public deployment at `pactavn.streamlit.app` never exposes the upload page.

3. **The intake wizard runs behind `BYOL_INTAKE=1` env flag only.** Follows the same gating pattern as `TRISK_LIVE_RERUN` in `dashboard/lib/live_rerun.py`. Without this flag, the Intake Wizard page is invisible and unreachable.

4. **Optional pre-anonymization.** Banks may anonymize borrower names before sending. The template README documents this option. The intake script also supports `--anonymize` to replace counterparty names with stable pseudonyms (`Counterparty 001`, ...) in the normalized output. This is the default `{{ANONYMIZATION_APPROACH}}` for the real-data phase.

5. **Aggregated views only in dashboard output.** The dashboard shows sector-level alignment and risk metrics. No individual loan rows or counterparty names appear in the public dashboard.

## Operator Responsibilities

- Store received client files in a secure location outside the repo
- Run the intake wizard on a local machine, not on the public Streamlit Cloud deployment
- The wizard deletes its own temp files automatically; the operator's remaining responsibility is the file they received out-of-band (securely delete it after processing)
- Review `validation_errors.csv` and `match_preview.csv` for any inadvertently exposed counterparty information before sharing outputs
