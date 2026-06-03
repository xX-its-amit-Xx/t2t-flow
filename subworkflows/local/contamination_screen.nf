//
// CONTAMINATION_SCREEN: optional read-level decontamination with Kraken2.
//
// When params.kraken2_db is provided, classify reads with KRAKEN2 and use
// KRAKENTOOLS_EXTRACT (exclude mode) to drop reads assigned to the configured
// contaminant taxids, returning cleaned reads. Otherwise the reads pass through
// unchanged so the DAG always produces a clean_reads channel.
//

include { KRAKEN2              } from '../../modules/local/kraken2.nf'
include { KRAKENTOOLS_EXTRACT  } from '../../modules/local/krakentools_extract.nf'

workflow CONTAMINATION_SCREEN {

    take:
    ch_reads // channel: [ val(meta), path(reads) ]

    main:

    ch_versions      = Channel.empty()
    ch_multiqc_files = Channel.empty()
    ch_reports       = Channel.empty()

    if (params.kraken2_db) {

        ch_db = file(params.kraken2_db, checkIfExists: true)

        //
        // Classify reads. save_output_reads = true so classified/unclassified
        // FASTQs and the per-read assignment file are produced.
        //
        KRAKEN2 ( ch_reads, ch_db, true )
        ch_versions      = ch_versions.mix(KRAKEN2.out.versions)
        ch_multiqc_files = ch_multiqc_files.mix(KRAKEN2.out.report.map { meta, f -> f })
        ch_reports       = ch_reports.mix(KRAKEN2.out.report)

        //
        // Join the original reads with the Kraken assignment + report by meta so
        // KRAKENTOOLS_EXTRACT receives (meta, reads, assignment, report).
        //
        ch_extract_in = ch_reads
            .join(KRAKEN2.out.classified_assignment, by: 0)
            .join(KRAKEN2.out.report, by: 0)
            .map { meta, reads, assignment, report ->
                tuple(meta, reads, assignment, report)
            }

        // exclude = true -> remove the contaminant taxids from the read set.
        KRAKENTOOLS_EXTRACT ( ch_extract_in, params.contaminant_taxids, true )
        ch_versions = ch_versions.mix(KRAKENTOOLS_EXTRACT.out.versions)

        ch_clean_reads = KRAKENTOOLS_EXTRACT.out.extracted_reads

    }
    else {
        // No database configured: pass the reads through untouched.
        ch_clean_reads = ch_reads
    }

    emit:
    clean_reads   = ch_clean_reads    // channel: [ val(meta), path(reads) ]
    reports       = ch_reports        // channel: [ val(meta), path(*.report.txt) ]
    multiqc_files = ch_multiqc_files  // channel: [ path(...) ]
    versions      = ch_versions       // channel: [ path(versions.yml) ]
}
