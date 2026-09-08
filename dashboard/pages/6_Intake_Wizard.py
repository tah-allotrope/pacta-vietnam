from __future__ import annotations

import io
import tempfile
import zipfile
from pathlib import Path

import pandas as pd
import streamlit as st

from dashboard.lib.branding import apply_page_frame, footer_note
from dashboard.lib.intake import (
    cleanup_temp_files,
    convert_xlsx_to_csv,
    is_intake_enabled,
    run_intake_validation,
)

if not is_intake_enabled():
    st.info(
        "Intake Wizard is disabled. Set the environment variable "
        "`BYOL_INTAKE=1` to enable this page."
    )
    st.stop()

apply_page_frame(
    "Intake Wizard",
    "Upload a client loanbook, validate, and download the normalized output.",
)

st.markdown(
    """
    <div style="padding:0.9rem 1rem;border:1px solid rgba(57,255,20,0.28);
    border-radius:14px;background:linear-gradient(135deg,rgba(57,255,20,0.09),
    rgba(0,229,255,0.05));margin-bottom:1rem;">
    <strong>Operator mode — synthetic data disclaimer.</strong>
    This page processes real bank data. No raw client data is committed to git
    or displayed on the public dashboard.
    See <code>docs/intake_privacy.md</code> for the full privacy posture.
    <span style="display:inline-block;padding:0.18rem 0.55rem;border-radius:999px;
    background:rgba(248,81,73,0.16);color:#ffd7d4;border:1px solid rgba(248,81,73,0.35);
    font-size:0.8rem;margin-left:0.5rem;">Operator only</span>
    </div>
    """,
    unsafe_allow_html=True,
)

uploaded_file = st.file_uploader(
    "Choose a loanbook file",
    type=["csv", "xlsx"],
    help="Upload a CSV or XLSX file conforming to the intake schema (see intake/SCHEMA.md).",
)

if uploaded_file is not None:
    file_bytes = uploaded_file.read()
    file_name = uploaded_file.name

    with tempfile.NamedTemporaryFile(
        suffix=f"_{file_name}", delete=False
    ) as tmp:
        tmp.write(file_bytes)
        upload_path = Path(tmp.name)
    # The converted CSV (XLSX path) is a second temp file; both are removed
    # in the finally block below, which also runs past st.stop().
    input_path = upload_path

    try:
        st.success(f"File uploaded: {file_name} ({len(file_bytes):,} bytes)")

        # Convert XLSX to CSV if needed
        if file_name.endswith(".xlsx"):
            with st.spinner("Converting XLSX to CSV ..."):
                try:
                    input_path = convert_xlsx_to_csv(upload_path)
                    st.info("XLSX converted to CSV. Data sheet extracted.")
                except Exception as e:
                    st.error(f"XLSX conversion failed: {e}")
                    st.stop()

        if st.button("Validate & Map", type="primary"):
            with st.spinner("Running intake validation (this may take up to 60 seconds) ..."):
                try:
                    results = run_intake_validation(input_path)
                except RuntimeError as e:
                    st.error(f"Validation failed: {e}")
                    st.stop()

            st.success("Validation complete!")

            # Display validation summary
            summary = results.get("summary", {})
            if summary and summary.get("raw_text"):
                with st.expander("Validation Summary", expanded=True):
                    st.text(summary["raw_text"])

                col1, col2, col3 = st.columns(3)
                col1.metric("Total rows", summary.get("total_rows", "N/A"))
                col2.metric("Passing", summary.get("passing_rows", "N/A"))
                col3.metric("Errors", summary.get("error_rows", "N/A"))

            # Display validation errors table
            errors_df = results.get("validation_errors")
            if errors_df is not None and not errors_df.empty:
                with st.expander("Validation Errors", expanded=True):
                    st.dataframe(errors_df, use_container_width=True)
                    st.download_button(
                        "Download validation_errors.csv",
                        data=errors_df.to_csv(index=False),
                        file_name="validation_errors.csv",
                        mime="text/csv",
                    )
            else:
                st.info("No validation errors detected.")

            # Display match preview
            match_df = results.get("match_preview")
            if match_df is not None and not match_df.empty:
                with st.expander("Match Preview", expanded=False):
                    # Color rows by score
                    def color_score(val):
                        if val >= 1.0:
                            return "background-color: rgba(57, 255, 20, 0.15)"
                        elif val >= 0.9:
                            return "background-color: rgba(255, 255, 0, 0.12)"
                        return "background-color: rgba(248, 81, 73, 0.12)"

                    styled = match_df.style.applymap(
                        color_score, subset=["score"]
                    )
                    st.dataframe(styled, use_container_width=True)
                    st.download_button(
                        "Download match_preview.csv",
                        data=match_df.to_csv(index=False),
                        file_name="match_preview.csv",
                        mime="text/csv",
                    )

            # Display normalized loanbook preview
            norm_df = results.get("normalized_loanbook")
            if norm_df is not None:
                with st.expander("Normalized Loanbook Preview", expanded=False):
                    st.dataframe(norm_df.head(20), use_container_width=True)
                    st.caption(
                        f"Showing {min(20, len(norm_df))} of {len(norm_df)} rows. "
                        f"Full file available for download below."
                    )

                # Download normalized loanbook
                csv_bytes = norm_df.to_csv(index=False).encode("utf-8")
                st.download_button(
                    "Download normalized_loanbook.csv",
                    data=csv_bytes,
                    file_name="normalized_loanbook.csv",
                    mime="text/csv",
                )

                # Download full bundle as ZIP
                zip_buffer = io.BytesIO()
                with zipfile.ZipFile(zip_buffer, "w", zipfile.ZIP_DEFLATED) as zf:
                    zf.writestr("normalized_loanbook.csv", csv_bytes)
                    if errors_df is not None and not errors_df.empty:
                        zf.writestr(
                            "validation_errors.csv", errors_df.to_csv(index=False)
                        )
                    if match_df is not None and not match_df.empty:
                        zf.writestr(
                            "match_preview.csv", match_df.to_csv(index=False)
                        )
                    if summary and summary.get("raw_text"):
                        zf.writestr("validation_summary.txt", summary["raw_text"])

                st.download_button(
                    "Download full bundle (ZIP)",
                    data=zip_buffer.getvalue(),
                    file_name="intake_output_bundle.zip",
                    mime="application/zip",
                )

    finally:
        cleanup_temp_files(upload_path, input_path)

footer_note()
