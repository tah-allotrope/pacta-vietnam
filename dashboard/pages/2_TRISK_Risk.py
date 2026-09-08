from __future__ import annotations

from io import BytesIO
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile

import pandas as pd
import streamlit as st

from dashboard.lib.branding import apply_page_frame, footer_note, public_demo_banner
from dashboard.lib.charts import npv_var_scatter, ranked_bar, trajectory_line
from dashboard.lib.loaders import load_trisk_sector_tables, load_trisk_tables, trisk_dir


DISCLAIMER = (
    "PD changes shown here are scenario-horizon shock summaries from the synthetic TRISK setup, "
    "not 1-year regulatory PDs or production credit model outputs."
)


def _build_sector_zip(sector: str) -> bytes:
    buffer = BytesIO()
    sector_dir = trisk_dir() / sector
    with ZipFile(buffer, mode="w", compression=ZIP_DEFLATED) as zf:
        for path in sorted(sector_dir.iterdir()):
            if path.is_file():
                zf.write(path, arcname=f"{sector}/{path.name}")
    buffer.seek(0)
    return buffer.read()


def _build_full_zip(sectors: list[str]) -> bytes:
    # Bounded to the manifest-listed sector folders (flat files) plus the
    # manifest itself — never a recursive walk of the whole snapshot tree.
    buffer = BytesIO()
    with ZipFile(buffer, mode="w", compression=ZIP_DEFLATED) as zf:
        manifest_path = trisk_dir() / "manifest.csv"
        if manifest_path.is_file():
            zf.write(manifest_path, arcname="manifest.csv")
        for sector in sectors:
            sector_dir = trisk_dir() / sector
            if not sector_dir.is_dir():
                continue
            for path in sorted(sector_dir.iterdir()):
                if path.is_file():
                    zf.write(path, arcname=f"{sector}/{path.name}")
    buffer.seek(0)
    return buffer.read()


apply_page_frame("TRISK Risk", "Firm-level transition-stress view across the Vietnam synthetic power, cement, and steel books.")
public_demo_banner()
st.error(DISCLAIMER)

base_tables = load_trisk_tables()
manifest = base_tables["manifest"].copy()
sector_options = manifest["sector"].tolist()
default_sector = base_tables["default_sector"].iloc[0]["sector"]

selected_sector = st.selectbox(
    "Sector",
    sector_options,
    index=sector_options.index(default_sector),
    key="trisk_sector",
    format_func=lambda value: manifest.loc[manifest["sector"] == value, "label"].iloc[0],
)

tables = load_trisk_sector_tables(selected_sector)
sector_row = manifest.loc[manifest["sector"] == selected_sector].iloc[0]

company_summary = tables["company_summary"].copy()
pd_summary = tables["pd_summary"].copy()
sensitivity = tables["sensitivity_results"].copy()
sensitivity_summary = tables["sensitivity_summary"].copy()
combined = tables["combined"].copy()
trajectories = tables["company_trajectories_latest"].copy() if "company_trajectories_latest" in tables else tables["npv_results"].copy()
assets = tables["assets"].copy()
financial = tables["financial_features"].copy()
scenarios = tables["scenarios"].copy()
carbon_price = tables["carbon_price"].copy()

company_summary["technology_mix"] = company_summary["company_id"].map(
    assets.groupby("company_id")["technology"].agg(lambda values: ", ".join(sorted(set(values.str.replace("Cap", "", regex=False)))))
)
company_summary["npv_change_pct"] = company_summary["npv_change"] * 100
company_summary["pd_change_bp"] = company_summary["pd_change"] * 10000

valid_rows = company_summary[company_summary["npv_change"].notna()].copy()

st.info(sector_row["disclaimer"])

col1, col2, col3, col4 = st.columns(4)
col1.metric("Borrowers in view", int(valid_rows["company_name"].nunique()))
col2.metric("Worst NPV change", f"{valid_rows['npv_change_pct'].min():.1f}%")
col3.metric("Largest PD change", f"{valid_rows['pd_change_bp'].max():.0f} bp")
col4.metric("Top-ranked name", combined["company_name"].iloc[0])

st.subheader("Company ranking")
left, right = st.columns([1.1, 1])
with left:
    ranking_df = valid_rows.sort_values("npv_change_pct").copy()
    st.plotly_chart(
        ranked_bar(
            ranking_df,
            x="npv_change_pct",
            y="company_name",
            color="technology_mix",
            title=f"NPV change ranking under stress scenario ({sector_row['label']})",
        ),
        use_container_width=True,
    )
with right:
    ranking_columns = ["company_name", "assets", "technology_mix", "npv_baseline", "npv_shock", "npv_change_pct", "pd_change_bp"]
    if "alignment_context" in combined.columns:
        ranking_columns.append("alignment_context")
    ranking_table = valid_rows.merge(
        combined[[column for column in ["company_id", "alignment_context"] if column in combined.columns]],
        on="company_id",
        how="left",
    )[ranking_columns].sort_values("npv_change_pct")
    st.dataframe(ranking_table, use_container_width=True, hide_index=True)
    st.download_button(
        f"Download {selected_sector} TRISK company summary CSV",
        valid_rows.to_csv(index=False).encode("utf-8"),
        file_name=f"trisk_{selected_sector}_company_summary.csv",
        mime="text/csv",
    )

st.subheader("Cross-borrower risk map")
scatter_df = valid_rows.copy()
scatter_df["technology_group"] = scatter_df["technology_mix"].fillna("Unknown")
st.plotly_chart(
    npv_var_scatter(
        scatter_df,
        x="npv_change_pct",
        y="pd_change_bp",
        color="technology_group",
        hover_name="company_name",
        title=f"NPV deterioration vs PD change ({sector_row['label']})",
    ),
    use_container_width=True,
)

st.subheader("Sensitivity explorer")
parameter_options = ["shock_year", "discount_rate", "risk_free_rate", "market_passthrough"]
parameter = st.selectbox("Parameter", parameter_options)
parameter_rows = sensitivity[sensitivity["parameter_name"] == parameter].copy()
parameter_values = sorted(parameter_rows["parameter_value"].dropna().astype(str).unique().tolist())
parameter_value = st.select_slider("Scenario setting", options=parameter_values)
selected_sensitivity = parameter_rows[parameter_rows["parameter_value"].astype(str) == parameter_value].copy()
selected_sensitivity["npv_change_pct"] = selected_sensitivity["npv_change"] * 100
selected_sensitivity["pd_change_bp"] = selected_sensitivity["pd_change"] * 10000

s1, s2 = st.columns([1.1, 1])
with s1:
    st.plotly_chart(
        ranked_bar(
            selected_sensitivity.sort_values("stress_priority_score", ascending=True),
            x="stress_priority_score",
            y="company_name",
            color="parameter_name",
            title=f"Stress priority scores: {parameter} = {parameter_value}",
        ),
        use_container_width=True,
    )
with s2:
    sensitivity_columns = [
        "company_name",
        "npv_change_pct",
        "pd_change_bp",
        "stress_priority_score",
        "delta_priority_vs_base",
    ]
    if "alignment_context" in selected_sensitivity.columns:
        sensitivity_columns.append("alignment_context")
    st.dataframe(
        selected_sensitivity[sensitivity_columns].sort_values("stress_priority_score", ascending=False),
        use_container_width=True,
        hide_index=True,
    )

st.subheader("Trajectory detail")
company_name = st.selectbox("Borrower", sorted(valid_rows["company_name"].unique().tolist()))
company_slice = trajectories[trajectories["company_name"] == company_name].copy()
company_slice["scenario_pathway_delta"] = company_slice["production_shock_scenario"] - company_slice["production_baseline_scenario"]
company_slice["series"] = company_slice["technology"].str.replace("Cap", "", regex=False)
st.plotly_chart(
    trajectory_line(
        company_slice,
        x="year",
        y="production_shock_scenario",
        color="series",
        title=f"Stress production path by technology: {company_name}",
    ),
    use_container_width=True,
)

st.subheader("Inputs used in the pilot")
in1, in2, in3 = st.columns(3)
with in1:
    st.markdown("**Financial features**")
    st.dataframe(financial, use_container_width=True, hide_index=True)
with in2:
    st.markdown("**Scenario excerpts**")
    st.dataframe(
        scenarios[["scenario", "technology", "scenario_year", "scenario_price", "scenario_pathway", "scenario_capacity_factor"]].head(18),
        use_container_width=True,
        hide_index=True,
    )
with in3:
    st.markdown("**Carbon price curve**")
    st.dataframe(carbon_price, use_container_width=True, hide_index=True)

download_left, download_right = st.columns(2)
with download_left:
    st.download_button(
        f"Download {selected_sector} TRISK results (zip)",
        _build_sector_zip(selected_sector),
        file_name=f"trisk_{selected_sector}_results_bundle.zip",
        mime="application/zip",
    )
with download_right:
    st.download_button(
        "Download full TRISK multisector snapshot (zip)",
        _build_full_zip(sector_options),
        file_name="trisk_multisector_results_bundle.zip",
        mime="application/zip",
    )

with st.expander("How to interpret this page"):
    st.markdown(
        "The top of the page shows which borrowers deteriorate most under the synthetic stress scenario for the selected sector. "
        "The sensitivity section then shows how that ranking moves when one model setting changes at a time. "
        "The inputs panel makes the synthetic assumptions explicit so a bank audience can see what drives the results."
    )

footer_note()
