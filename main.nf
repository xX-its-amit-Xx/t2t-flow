#!/usr/bin/env nextflow
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    t2t-flow
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Telomere-to-telomere de novo genome assembly of non-model organisms from
    long reads.

    Github : https://github.com/t2t-flow/t2t-flow
    License: GPL-3.0-or-later
----------------------------------------------------------------------------------
*/

nextflow.enable.dsl = 2

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT PLUGIN FUNCTIONS / SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { validateParameters; paramsSummaryMap; paramsSummaryLog } from 'plugin/nf-schema'

include { INPUT_CHECK           } from './subworkflows/local/input_check'
include { READ_QC               } from './subworkflows/local/read_qc'
include { CONTAMINATION_SCREEN  } from './subworkflows/local/contamination_screen'
include { ASSEMBLY              } from './subworkflows/local/assembly'
include { PURGE_DUPS            } from './subworkflows/local/purge_dups'
include { SCAFFOLDING           } from './subworkflows/local/scaffolding'
include { POLISHING             } from './subworkflows/local/polishing'
include { QC_BENCHMARK          } from './subworkflows/local/qc_benchmark'
include { RELEASE               } from './subworkflows/local/release'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    HELPERS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// Print a startup banner.
//
def printBanner() {
    def banner = """
    ==========================================================================
      t2t-flow  v${workflow.manifest.version}
      Telomere-to-telomere de novo genome assembly from long reads
    --------------------------------------------------------------------------
      input        : ${params.input}
      outdir       : ${params.outdir}
      assembler    : ${params.assembler}
      scaffolder   : ${params.scaffolder}
      ploidy       : ${params.ploidy}    kmer_size : ${params.kmer_size}
      busco_lineage: ${params.busco_lineage}
    ==========================================================================
    """.stripIndent()
    log.info(banner)
}

//
// Collate a list of version YAML channel items into a single channel suitable
// for publishing (one combined software_versions.yml). Minimal & robust:
// dedupe identical blocks and concatenate.
//
def collateVersions(ch_versions) {
    return ch_versions
        .unique()
        .collectFile(
            name: 'collated_versions.yml',
            storeDir: "${params.outdir}/pipeline_info",
            sort: true,
            newLine: false
        )
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    NAMED WORKFLOW FOR PIPELINE
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow T2TFLOW {

    main:

    // Accumulators carried through the whole pipeline.
    ch_versions      = Channel.empty()
    ch_multiqc_files = Channel.empty()

    //
    // SUBWORKFLOW: parse the samplesheet into read channels.
    //
    INPUT_CHECK ( params.input )
    ch_versions = ch_versions.mix( INPUT_CHECK.out.versions )

    ch_hifi = INPUT_CHECK.out.hifi   // (meta, hifi_path)
    ch_ont  = INPUT_CHECK.out.ont    // (meta, ont_path)
    ch_hic  = INPUT_CHECK.out.hic    // (meta, [hic1, hic2])

    //
    // Build the "primary long reads" channel: prefer HiFi, fall back to ONT for
    // any sample that has no HiFi. We branch the ONT channel on whether the
    // same meta is present in HiFi, then mix the HiFi-less ONT entries in.
    //
    ch_hifi_ids = ch_hifi.map { meta, reads -> meta.id }.collect().ifEmpty( [] )

    ch_ont_only = ch_ont
        .combine( ch_hifi_ids.map { ids -> [ ids ] } )
        .filter  { meta, reads, ids -> !( meta.id in ids ) }
        .map     { meta, reads, ids -> [ meta, reads ] }

    ch_primary_reads = ch_hifi.mix( ch_ont_only )   // (meta, reads) one per sample

    //
    // SUBWORKFLOW: read QC + k-mer profiling. Provides meryl_db for MERQURY.
    //
    ch_meryl_db = Channel.empty()
    if ( !params.skip_readqc ) {
        READ_QC ( ch_hifi, ch_ont )
        ch_versions      = ch_versions.mix( READ_QC.out.versions )
        ch_multiqc_files = ch_multiqc_files.mix( READ_QC.out.multiqc_files )
        ch_meryl_db      = READ_QC.out.meryl_db
    }

    //
    // SUBWORKFLOW: contamination screen on the primary long reads (optional).
    // Only runs when both enabled and a kraken2 DB is supplied; otherwise the
    // reads pass through unchanged.
    //
    if ( !params.skip_contamination && params.kraken2_db ) {
        CONTAMINATION_SCREEN ( ch_primary_reads )
        ch_versions          = ch_versions.mix( CONTAMINATION_SCREEN.out.versions )
        ch_multiqc_files     = ch_multiqc_files.mix( CONTAMINATION_SCREEN.out.multiqc_files )
        ch_reads_for_assembly = CONTAMINATION_SCREEN.out.clean_reads
    } else {
        ch_reads_for_assembly = ch_primary_reads
    }

    //
    // For the assembler, the HiFi-aware path needs the (possibly cleaned) HiFi
    // reads specifically. We re-split the cleaned/primary reads back into a
    // HiFi-style channel: any sample that had HiFi keeps its (cleaned) reads as
    // HiFi input; ONT stays on the ONT channel.
    //
    ch_hifi_for_assembly = ch_reads_for_assembly
        .combine( ch_hifi_ids.map { ids -> [ ids ] } )
        .filter  { meta, reads, ids -> meta.id in ids }
        .map     { meta, reads, ids -> [ meta, reads ] }

    //
    // SUBWORKFLOW: assembly (hifiasm | verkko | flye).
    //
    ASSEMBLY ( ch_hifi_for_assembly, ch_ont, ch_hic )
    ch_versions      = ch_versions.mix( ASSEMBLY.out.versions )
    ch_multiqc_files = ch_multiqc_files.mix( ASSEMBLY.out.multiqc_files )

    //
    // SUBWORKFLOW: purge duplicates (optional; not called at all when skipped).
    //
    if ( !params.skip_purgedups ) {
        PURGE_DUPS ( ASSEMBLY.out.assembly, ch_primary_reads )
        ch_versions      = ch_versions.mix( PURGE_DUPS.out.versions )
        ch_multiqc_files = ch_multiqc_files.mix( PURGE_DUPS.out.multiqc_files )
        ch_asm = PURGE_DUPS.out.purged_assembly
    } else {
        ch_asm = ASSEMBLY.out.assembly
    }

    //
    // SUBWORKFLOW: Hi-C scaffolding (optional). Emits scaffolds + AGP.
    // When skipped, the AGP channel is left empty and the contigs pass through.
    //
    ch_agp = Channel.empty()
    if ( !params.skip_scaffolding ) {
        SCAFFOLDING ( ch_asm, ch_hic )
        ch_versions      = ch_versions.mix( SCAFFOLDING.out.versions )
        ch_multiqc_files = ch_multiqc_files.mix( SCAFFOLDING.out.multiqc_files )
        ch_scaffolded = SCAFFOLDING.out.scaffolds
        ch_agp        = SCAFFOLDING.out.agp
    } else {
        ch_scaffolded = ch_asm
    }

    //
    // SUBWORKFLOW: long-read polishing (optional). Pass-through otherwise.
    //
    if ( params.run_polishing ) {
        POLISHING ( ch_scaffolded, ch_primary_reads )
        ch_versions   = ch_versions.mix( POLISHING.out.versions )
        ch_final_asm  = POLISHING.out.polished
    } else {
        ch_final_asm = ch_scaffolded
    }

    //
    // SUBWORKFLOW: QC & benchmark the final assembly.
    //
    QC_BENCHMARK ( ch_final_asm, ch_meryl_db )
    ch_versions      = ch_versions.mix( QC_BENCHMARK.out.versions )
    ch_multiqc_files = ch_multiqc_files.mix( QC_BENCHMARK.out.multiqc_files )

    //
    // Assemble the per-sample QC artifact bundle for the release report. Each
    // channel is (meta, file); join them by meta so RELEASE gets one tuple per
    // sample. Optional artifacts use a permissive left-join with [] fallback.
    //
    ch_qc = QC_BENCHMARK.out.gfastats
        .join( QC_BENCHMARK.out.busco_json,          remainder: true )
        .join( QC_BENCHMARK.out.merqury_qv,          remainder: true )
        .join( QC_BENCHMARK.out.tidk_search,         remainder: true )
        .join( QC_BENCHMARK.out.telomere_table_json, remainder: true )
        .map { items ->
            def meta = items[0]
            def rest = items[1..-1].collect { it ?: [] }
            [ meta ] + rest
        }

    //
    // Optional MultiQC config supplied by the user.
    //
    ch_multiqc_config = params.multiqc_config
        ? Channel.fromPath( params.multiqc_config, checkIfExists: true )
        : Channel.empty()

    //
    // SUBWORKFLOW: release -- per-sample assembly_stats.json + a single MultiQC.
    //
    RELEASE (
        ch_final_asm,
        ch_agp,
        ch_qc,
        ch_multiqc_files,
        ch_multiqc_config
    )
    ch_versions = ch_versions.mix( RELEASE.out.versions )

    //
    // Collate software versions into a single YAML under pipeline_info/.
    //
    collateVersions ( ch_versions )

    emit:
    multiqc_report = RELEASE.out.multiqc_report
    versions       = ch_versions
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow {

    //
    // Validate parameters against nextflow_schema.json before doing anything.
    //
    if ( params.validate_params ) {
        validateParameters()
    }

    printBanner()

    // Concise params summary to the log (and to pipeline_info via summary map).
    log.info( paramsSummaryLog(workflow) )

    // Persist a params summary for provenance.
    def summary = paramsSummaryMap(workflow)
    def summaryFile = file("${params.outdir}/pipeline_info/params_summary.json")
    summaryFile.parent.mkdirs()
    summaryFile.text = groovy.json.JsonOutput.prettyPrint(groovy.json.JsonOutput.toJson(summary))

    T2TFLOW ()
}
