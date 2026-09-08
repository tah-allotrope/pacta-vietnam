from __future__ import annotations

from pathlib import Path

import pandas as pd
import streamlit as st

from dashboard.lib.branding import apply_page_frame, footer_note, public_demo_banner
from dashboard.lib.charts import alignment_bar, trajectory_line
from dashboard.lib.loaders import load_markdown_text, load_pacta_alignment_tables, pacta_dir


SECTOR_LABELS = {
    "power": "Power",
    "automotive": "Automotive",
    "cement": "Cement",
    "steel": "Steel",
    "coal": "Coal",
}

SECTOR_IMAGE_MAP = {
    "power": [
        ("05_vn_power_techmix.png", "Power technology mix snapshot"),
        ("06_vn_coal_trajectory.png", "Coal capacity trajectory snapshot"),
        ("07_vn_renewables_trajectory.png", "Renewables buildout snapshot"),
    ],
    "automotive": [
        ("08_vn_auto_techmix.png", "Automotive technology mix snapshot"),
        ("09_vn_ev_trajectory.png", "EV production trajectory snapshot"),
    ],
    "cement": [("10_vn_cement_sda.png", "Cement emission-intensity snapshot")],
    "steel": [("11_vn_steel_sda.png", "Steel emission-intensity snapshot")],
    "coal": [("13_vn_coal_stranded_risk.png", "Coal stranded-risk snapshot")],
}


def _caption_lookup(readme: str, file_name: str) -> str:
    marker = f"`{file_name}`"
    for line in readme.splitlines():
        if marker in line:
            parts = [part.strip() for part in line.split("|") if part.strip()]
            if len(parts) >= 3:
                return parts[1]
    return file_name


def _format_kpi_inputs(tables: dict[str, pd.DataFrame]) -> tuple[int, int, int, float]:
    matches = tables["matches"]
    ms_alignment = tables["ms_alignment"]
    sda_alignment = tables["sda_alignment"]
    total_sectors = int(matches["sector"].nunique())
    aligned_rows = int((ms_alignment["aligned"] == "Aligned").sum() + (sda_alignment["aligned"] == "Aligned").sum())
    total_rows = int(len(ms_alignment) + len(sda_alignment))
    avg_score = float(matches["score"].mean())
    return total_sectors, aligned_rows, total_rows, avg_score


def _portfolio_chart_df(ms_portfolio: pd.DataFrame, selected_sector: str) -> pd.DataFrame:
    df = ms_portfolio[(ms_portfolio["sector"] == selected_sector) & (ms_portfolio["year"] == 2030)].copy()
    if df.empty:
        return df
    df["metric_label"] = df["metric"].replace(
        {
            "projected": "Projected",
            "target_pdp8_ndc": "Target: PDP8 / NDC",
            "target_nze_global": "Target: NZE",
            "target_steps": "Target: STEPS",
        }
    )
    df["technology_label"] = df["technology"].str.replace("cap", "", regex=False).str.title()
    return df


def _trajectory_df(ms_portfolio: pd.DataFrame, selected_sector: str, selected_technology: str) -> pd.DataFrame:
    df = ms_portfolio[(ms_portfolio["sector"] == selected_sector) & (ms_portfolio["technology"] == selected_technology)].copy()
    if df.empty:
        return df
    df["metric_label"] = df["metric"].replace(
        {
            "projected": "Projected",
            "target_pdp8_ndc": "Target: PDP8 / NDC",
            "target_nze_global": "Target: NZE",
            "target_steps": "Target: STEPS",
        }
    )
    return df


apply_page_frame(
    "PACTA Alignment",
    "Interactive alignment story for the synthetic Vietnam bank book.",
)
public_demo_banner()

tables = load_pacta_alignment_tables()
readme = load_markdown_text(Path(__file__).resolve().parents[1] / "data" / "README.md")

st.markdown(
    "This page keeps the bank-facing story simple: where the portfolio is aligned, where it is not, "
    "and which sector snapshots deserve follow-up attention. Interactive tables are paired with static PACTA charts generated upstream."
)

total_sectors, aligned_rows, total_rows, avg_score = _format_kpi_inputs(tables)
matches = tables["matches"]
ms_alignment = tables["ms_alignment"].copy()
sda_alignment = tables["sda_alignment"].copy()
ms_portfolio = tables["ms_portfolio"].copy()
ms_company = tables["ms_company"].copy()
sda_portfolio = tables["sda_portfolio"].copy()

col1, col2, col3, col4 = st.columns(4)
col1.metric("Matched sectors", total_sectors)
col2.metric("Aligned rows", f"{aligned_rows}/{total_rows}")
col3.metric("Average match score", f"{avg_score:.2f}")
col4.metric("Matched borrowers", int(matches["name_direct_loantaker"].nunique()))

st.subheader("Portfolio overview")
c1, c2 = st.columns([1.4, 1])
with c1:
    overview_df = pd.concat(
        [
            ms_alignment.assign(view="Market share").rename(columns={"share_gap_pp": "gap_value"}),
            sda_alignment.assign(view="Emission intensity").rename(columns={"gap_pct": "gap_value"}),
        ],
        ignore_index=True,
        sort=False,
    )
    overview_df["technology"] = overview_df.get("technology", pd.Series(dtype=str)).fillna("portfolio")
    overview_df["sector_label"] = overview_df["sector"].map(SECTOR_LABELS).fillna(overview_df["sector"].str.title())
    st.plotly_chart(
        alignment_bar(
            overview_df,
            x="sector_label",
            y="gap_value",
            color="view",
            title="2030 alignment gaps across sectors",
        ),
        use_container_width=True,
    )
with c2:
    exposure_summary = (
        matches.groupby("sector", as_index=False)["loan_size_outstanding"]
        .sum()
        .assign(sector=lambda d: d["sector"].map(SECTOR_LABELS).fillna(d["sector"].str.title()))
        .sort_values("loan_size_outstanding", ascending=False)
    )
    st.dataframe(exposure_summary, use_container_width=True, hide_index=True)
    st.download_button(
        "Download matched exposures CSV",
        matches.to_csv(index=False).encode("utf-8"),
        file_name="vn_matches_snapshot.csv",
        mime="text/csv",
    )

st.subheader("Sector drilldown")
sector_options = ["power", "automotive", "cement", "steel", "coal"]
selected_sector = st.selectbox(
    "Sector",
    sector_options,
    format_func=lambda value: SECTOR_LABELS.get(value, value.title()),
)

technology_candidates = sorted(ms_portfolio.loc[ms_portfolio["sector"] == selected_sector, "technology"].unique().tolist())
selected_technology = technology_candidates[0] if technology_candidates else None
if technology_candidates:
    selected_technology = st.selectbox(
        "Technology",
        technology_candidates,
        format_func=lambda value: value.replace("cap", "").title(),
    )

left, right = st.columns([1.15, 1])
with left:
    st.markdown("**Interactive table + chart**")
    if selected_sector in {"power", "automotive"}:
        sector_company_df = ms_company[ms_company["sector"] == selected_sector].copy()
        sector_alignment_df = ms_alignment[ms_alignment["sector"] == selected_sector].copy()
        chart_df = _portfolio_chart_df(ms_portfolio, selected_sector)
        if not chart_df.empty:
            st.plotly_chart(
                alignment_bar(
                    chart_df,
                    x="technology_label",
                    y="technology_share",
                    color="metric_label",
                    title=f"2030 {SECTOR_LABELS[selected_sector]} technology shares",
                ),
                use_container_width=True,
            )
        if selected_technology is not None:
            trajectory_df = _trajectory_df(ms_portfolio, selected_sector, selected_technology)
            if not trajectory_df.empty:
                st.plotly_chart(
                    trajectory_line(
                        trajectory_df,
                        x="year",
                        y="technology_share",
                        color="metric_label",
                        title=f"{SECTOR_LABELS[selected_sector]} {selected_technology.replace('cap', '').title()} trajectory",
                    ),
                    use_container_width=True,
                )
        st.dataframe(sector_alignment_df, use_container_width=True, hide_index=True)
        st.download_button(
            f"Download {SECTOR_LABELS[selected_sector]} alignment CSV",
            sector_alignment_df.to_csv(index=False).encode("utf-8"),
            file_name=f"{selected_sector}_alignment_2030.csv",
            mime="text/csv",
        )
        with st.expander("Company-level production table"):
            st.dataframe(
                sector_company_df[["name_abcd", "technology", "year", "metric", "production", "technology_share"]],
                use_container_width=True,
                hide_index=True,
            )
            st.download_button(
                f"Download {SECTOR_LABELS[selected_sector]} company table",
                sector_company_df.to_csv(index=False).encode("utf-8"),
                file_name=f"{selected_sector}_company_snapshot.csv",
                mime="text/csv",
                key=f"company_download_{selected_sector}",
            )
    else:
        sector_sda_df = sda_alignment[sda_alignment["sector"] == selected_sector].copy()
        sector_sda_portfolio = sda_portfolio[sda_portfolio["sector"] == selected_sector].copy()
        if not sector_sda_portfolio.empty:
            sector_sda_portfolio["metric_label"] = sector_sda_portfolio["emission_factor_metric"].replace(
                {
                    "projected": "Projected",
                    "target_pdp8_ndc": "Target: PDP8 / NDC",
                    "target_nze_global": "Target: NZE",
                    "target_steps": "Target: STEPS",
                }
            )
            st.plotly_chart(
                trajectory_line(
                    sector_sda_portfolio,
                    x="year",
                    y="emission_factor_value",
                    color="metric_label",
                    title=f"{SECTOR_LABELS[selected_sector]} emission-intensity trajectory",
                ),
                use_container_width=True,
            )
        if not sector_sda_df.empty:
            st.dataframe(sector_sda_df, use_container_width=True, hide_index=True)
            st.download_button(
                f"Download {SECTOR_LABELS[selected_sector]} alignment CSV",
                sector_sda_df.to_csv(index=False).encode("utf-8"),
                file_name=f"{selected_sector}_sda_alignment_2030.csv",
                mime="text/csv",
            )
        else:
            st.info("Coal currently uses the stranded-risk snapshot rather than an SDA table in this phase.")

with right:
    st.markdown("**Static PACTA snapshot charts**")
    for file_name, fallback_caption in SECTOR_IMAGE_MAP[selected_sector]:
        path = pacta_dir() / file_name
        if path.exists():
            st.image(str(path), caption=_caption_lookup(readme, file_name) or fallback_caption, use_container_width=True)
    st.caption("Static image panels are upstream PACTA outputs. The table and Plotly views next to them are the interactive layer for v1.")

st.subheader("Closing figures")
closing1, closing2 = st.columns(2)
with closing1:
    st.image(str(pacta_dir() / "12_vn_alignment_overview.png"), caption=_caption_lookup(readme, "12_vn_alignment_overview.png"), use_container_width=True)
with closing2:
    st.image(str(pacta_dir() / "13_vn_coal_stranded_risk.png"), caption=_caption_lookup(readme, "13_vn_coal_stranded_risk.png"), use_container_width=True)

with st.expander("Methodology footnote"):
    st.markdown(
        "PACTA for Banks measures portfolio alignment across climate-relevant sectors using granular physical-asset data. "
        "The repo research notes emphasize two accounting levels: portfolio-weighted analysis for overall bank contribution and company-level unweighted analysis for identifying leading emitters. "
        "This page uses both views side-by-side so a bank reader can see both portfolio trajectory and borrower-specific drivers."
    )
    st.markdown(
        "Source note: `research/PACTA for BANKS - TRISK overview.pptx.txt` states that PACTA provides useful inputs to later risk assessment and stress testing. "
        "That framing is why this dashboard leads with alignment before showing TRISK in later phases."
    )

footer_note()
