//
// RELEASE: per-sample assembly stats JSON + a single aggregated MultiQC report.
//
// ASSEMBLY_STATS_JSON runs once per sample over its QC artifact bundle (already
// assembled by main.nf into one tuple per sample:
//   [ meta, gfastats, busco_json, merqury_qv, tidk_search, telomere_json ]
// with any missing optional artifact filled with [] ). MULTIQC runs once over
// every collected report file plus the per-sample stats JSONs.
//
// ch_assembly / ch_agp are carried in for release packaging context (their
// publishing is handled by publishDir in conf/modules.config).
//

include { ASSEMBLY_STATS_JSON } from '../../modules/local/assembly_stats_json.nf'
include { MULTIQC             } from '../../modules/local/multiqc.nf'

workflow RELEASE {

    take:
    ch_assembly       // channel: [ val(meta), path(fasta) ]
    ch_agp            // channel: [ val(meta), path(agp) ]  (may be empty)
    ch_qc             // channel: [ val(meta), gfastats, busco_json, merqury_qv, tidk_search, telomere_json ]
    ch_multiqc_files  // channel: [ path(...) ]            collected QC/log files (queue, not pre-collected)
    ch_multiqc_config // channel: [ path(config) ]         (may be empty)

    main:

    ch_versions = Channel.empty()

    //
    // Per-sample machine-readable assembly_stats.json. ch_qc already matches the
    // module's (meta, gfastats, busco, qv, tidk, telomere) input tuple.
    //
    ASSEMBLY_STATS_JSON ( ch_qc )
    ch_versions = ch_versions.mix(ASSEMBLY_STATS_JSON.out.versions)

    //
    // MULTIQC over every collected file plus the per-sample assembly stats JSONs.
    //
    ch_multiqc_all = ch_multiqc_files
        .mix( ASSEMBLY_STATS_JSON.out.json.map { meta, f -> f } )
        .collect()
        .ifEmpty([])

    ch_config = ch_multiqc_config.collect().ifEmpty([])

    MULTIQC (
        ch_multiqc_all,
        ch_config,
        []                 // optional logo
    )
    ch_versions = ch_versions.mix(MULTIQC.out.versions)

    emit:
    multiqc_report      = MULTIQC.out.report            // channel: [ path(*multiqc_report.html) ]
    assembly_stats_json = ASSEMBLY_STATS_JSON.out.json  // channel: [ val(meta), path(*.assembly_stats.json) ]
    versions            = ch_versions                   // channel: [ path(versions.yml) ]
}
