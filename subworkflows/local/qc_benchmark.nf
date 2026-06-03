//
// QC_BENCHMARK: assembly evaluation and telomere/centromere annotation.
//
// Runs on the final (scaffolded/polished) assembly:
//   GFASTATS                       - contiguity stats
//   QUAST                          - assembly metrics
//   BUSCO                          - gene completeness
//   MERQURY                        - k-mer QV + completeness (needs meryl db)
//   TIDK_EXPLORE/SEARCH/PLOT       - telomeric repeat search
//   SAMTOOLS_FAIDX + TELOMERE_TABLE- per-scaffold telomere/centromere table
//

include { GFASTATS       } from '../../modules/local/gfastats.nf'
include { QUAST          } from '../../modules/local/quast.nf'
include { BUSCO          } from '../../modules/local/busco.nf'
include { MERQURY        } from '../../modules/local/merqury.nf'
include { TIDK_EXPLORE   } from '../../modules/local/tidk.nf'
include { TIDK_SEARCH    } from '../../modules/local/tidk.nf'
include { TIDK_PLOT      } from '../../modules/local/tidk.nf'
include { SAMTOOLS_FAIDX } from '../../modules/local/samtools_faidx.nf'
include { TELOMERE_TABLE } from '../../modules/local/telomere_table.nf'

workflow QC_BENCHMARK {

    take:
    ch_assembly  // channel: [ val(meta), path(fasta) ]
    ch_meryl_db  // channel: [ val(meta), path(*.meryldb) ]

    main:

    ch_versions      = Channel.empty()
    ch_multiqc_files = Channel.empty()

    //
    // Contiguity statistics (no genome size hint).
    //
    GFASTATS ( ch_assembly, '' )
    ch_versions      = ch_versions.mix(GFASTATS.out.versions)
    ch_multiqc_files = ch_multiqc_files.mix(GFASTATS.out.stats.map { meta, f -> f })

    //
    // QUAST metrics.
    //
    QUAST ( ch_assembly )
    ch_versions      = ch_versions.mix(QUAST.out.versions)
    ch_multiqc_files = ch_multiqc_files.mix(QUAST.out.tsv.map { meta, f -> f })

    //
    // BUSCO gene completeness (skippable via --skip_busco). busco_db may be null
    // (auto-download / lineage by name); pass an empty list when unset so the
    // optional path input is happy.
    //
    ch_busco_summary = Channel.empty()
    ch_busco_json    = Channel.empty()
    if (!params.skip_busco) {
        def busco_db = params.busco_db ? file(params.busco_db, checkIfExists: true) : []

        BUSCO (
            ch_assembly,
            params.busco_lineage,
            params.busco_mode,
            busco_db
        )
        ch_versions      = ch_versions.mix(BUSCO.out.versions)
        ch_multiqc_files = ch_multiqc_files.mix(BUSCO.out.short_summary_txt.map { meta, f -> f })
        ch_busco_summary = BUSCO.out.short_summary_txt
        ch_busco_json    = BUSCO.out.short_summary_json
    }

    //
    // MERQURY: join the meryl db with the assembly by meta.
    //
    ch_merqury_in = ch_meryl_db
        .join(ch_assembly, by: 0)
        .map { meta, meryl, asm -> tuple(meta, meryl, asm) }

    MERQURY ( ch_merqury_in )
    ch_versions      = ch_versions.mix(MERQURY.out.versions)
    ch_multiqc_files = ch_multiqc_files.mix(MERQURY.out.qv.map { meta, f -> f })

    //
    // Telomeric repeat search.
    //
    TIDK_EXPLORE ( ch_assembly )
    ch_versions = ch_versions.mix(TIDK_EXPLORE.out.versions)

    TIDK_SEARCH ( ch_assembly, params.telomere_motif )
    ch_versions = ch_versions.mix(TIDK_SEARCH.out.versions)

    TIDK_PLOT ( TIDK_SEARCH.out.search_tsv )
    ch_versions = ch_versions.mix(TIDK_PLOT.out.versions)

    //
    // Telomere/centromere table. Needs a .fai of the assembly; AGP is optional
    // here (scaffolding AGP is wired from main.nf via ASSEMBLY_STATS, so pass an
    // empty list as the optional AGP slot at this stage).
    //
    SAMTOOLS_FAIDX ( ch_assembly )
    ch_versions = ch_versions.mix(SAMTOOLS_FAIDX.out.versions)

    ch_telomere_in = TIDK_SEARCH.out.search_tsv
        .join(SAMTOOLS_FAIDX.out.fai, by: 0)
        .map { meta, search, fai -> tuple(meta, search, fai, []) }

    TELOMERE_TABLE ( ch_telomere_in )
    ch_versions = ch_versions.mix(TELOMERE_TABLE.out.versions)

    emit:
    gfastats             = GFASTATS.out.stats              // channel: [ val(meta), path(*.gfastats.txt) ]
    busco_summary        = ch_busco_summary                // channel: [ val(meta), path(*short_summary*.txt) ]
    busco_json           = ch_busco_json                   // channel: [ val(meta), path(*short_summary*.json) ]
    quast                = QUAST.out.tsv                   // channel: [ val(meta), path(*report.tsv) ]
    merqury_qv           = MERQURY.out.qv                  // channel: [ val(meta), path(*.qv) ]
    tidk_search          = TIDK_SEARCH.out.search_tsv      // channel: [ val(meta), path(*.tidk.search.tsv) ]
    telomere_table_json  = TELOMERE_TABLE.out.table_json   // channel: [ val(meta), path(*.telomere_centromere.json) ]
    multiqc_files        = ch_multiqc_files                // channel: [ path(...) ]
    versions             = ch_versions                     // channel: [ path(versions.yml) ]
}
