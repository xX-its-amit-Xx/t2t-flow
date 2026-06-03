//
// READ_QC: read-level QC and k-mer profiling.
//
// Runs SEQKIT_STATS + NANOPLOT on every read set (HiFi and ONT) and builds a
// meryl k-mer database + histogram + GenomeScope2 profile on the primary long
// reads (HiFi when present, otherwise ONT). The meryl db is emitted for later
// use by MERQURY in QC_BENCHMARK.
//

include { SEQKIT_STATS     } from '../../modules/local/seqkit_stats.nf'
include { NANOPLOT         } from '../../modules/local/nanoplot.nf'
include { MERYL_COUNT      } from '../../modules/local/meryl_count.nf'
include { MERYL_HISTOGRAM  } from '../../modules/local/meryl_histogram.nf'
include { GENOMESCOPE2     } from '../../modules/local/genomescope2.nf'

workflow READ_QC {

    take:
    ch_hifi // channel: [ val(meta), path(hifi) ]
    ch_ont  // channel: [ val(meta), path(ont)  ]

    main:

    ch_versions       = Channel.empty()
    ch_multiqc_files  = Channel.empty()

    //
    // All read sets get per-read statistics and NanoPlot QC.
    //
    ch_all_reads = ch_hifi.mix(ch_ont)

    SEQKIT_STATS ( ch_all_reads )
    ch_versions      = ch_versions.mix(SEQKIT_STATS.out.versions)
    ch_multiqc_files = ch_multiqc_files.mix(SEQKIT_STATS.out.stats.map { meta, f -> f })

    NANOPLOT ( ch_all_reads )
    ch_versions      = ch_versions.mix(NANOPLOT.out.versions)
    ch_multiqc_files = ch_multiqc_files.mix(NANOPLOT.out.txt.map { meta, f -> f })

    //
    // Primary long reads for k-mer profiling: prefer HiFi, fall back to ONT for
    // any sample that has no HiFi. Tag each read set by type, group by sample id
    // and pick HiFi when available, otherwise ONT. This is unambiguous and
    // avoids brittle remainder-join edge cases.
    //
    ch_kmer_reads = ch_hifi.map    { meta, reads -> [ meta.id, [ meta: meta, type: 'hifi', reads: reads ] ] }
        .mix( ch_ont.map { meta, reads -> [ meta.id, [ meta: meta, type: 'ont',  reads: reads ] ] } )
        .groupTuple()
        .map { id, entries ->
            def hifi = entries.find { it.type == 'hifi' }
            def chosen = hifi ?: entries.find { it.type == 'ont' }
            tuple( chosen.meta, chosen.reads )
        }

    //
    // k-mer count -> histogram -> GenomeScope2.
    //
    MERYL_COUNT ( ch_kmer_reads, params.kmer_size )
    ch_versions = ch_versions.mix(MERYL_COUNT.out.versions)

    MERYL_HISTOGRAM ( MERYL_COUNT.out.meryl_db )
    ch_versions = ch_versions.mix(MERYL_HISTOGRAM.out.versions)

    GENOMESCOPE2 ( MERYL_HISTOGRAM.out.hist, params.kmer_size, params.ploidy )
    ch_versions      = ch_versions.mix(GENOMESCOPE2.out.versions)
    ch_multiqc_files = ch_multiqc_files.mix(GENOMESCOPE2.out.summary.map { meta, f -> f })

    emit:
    meryl_db            = MERYL_COUNT.out.meryl_db   // channel: [ val(meta), path(*.meryldb) ]
    genomescope_summary = GENOMESCOPE2.out.summary   // channel: [ val(meta), path(*_summary.txt) ]
    multiqc_files       = ch_multiqc_files           // channel: [ path(...) ]
    versions            = ch_versions                // channel: [ path(versions.yml) ]
}
