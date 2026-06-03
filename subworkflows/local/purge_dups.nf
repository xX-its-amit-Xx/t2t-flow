//
// PURGE_DUPS: remove haplotypic duplication from a contig assembly.
//
// Pipeline (nf-core style split processes):
//   1. MINIMAP2_ALIGN reads vs assembly (preset map-hifi) -> coverage PAF
//   2. PURGEDUPS_PBCSTAT -> PB.stat + PB.base.cov
//   3. PURGEDUPS_CALCUTS -> coverage cutoffs
//   4. PURGEDUPS_SPLITFA (assembly) -> split fasta
//   5. MINIMAP2_ALIGN split vs split (preset asm5) -> self PAF
//   6. PURGEDUPS_PURGEDUPS (basecov, cutoff, self PAF) -> dups bed
//   7. PURGEDUPS_GETSEQS (assembly, bed) -> purged fasta + haplotigs
// GFASTATS is run before and after for reporting.
//
// This subworkflow is only invoked by main.nf when !params.skip_purgedups, so
// there is no internal skip branch.
//

include { MINIMAP2_ALIGN as MINIMAP2_READS } from '../../modules/local/minimap2_align.nf'
include { MINIMAP2_ALIGN as MINIMAP2_SELF  } from '../../modules/local/minimap2_align.nf'
include { PURGEDUPS_PBCSTAT                 } from '../../modules/local/purgedups_pbcstat.nf'
include { PURGEDUPS_CALCUTS                 } from '../../modules/local/purgedups_calcuts.nf'
include { PURGEDUPS_SPLITFA                 } from '../../modules/local/purgedups_splitfa.nf'
include { PURGEDUPS_PURGEDUPS               } from '../../modules/local/purgedups_purgedups.nf'
include { PURGEDUPS_GETSEQS                 } from '../../modules/local/purgedups_getseqs.nf'
include { GFASTATS as GFASTATS_BEFORE       } from '../../modules/local/gfastats.nf'
include { GFASTATS as GFASTATS_AFTER        } from '../../modules/local/gfastats.nf'

workflow PURGE_DUPS {

    take:
    ch_assembly // channel: [ val(meta), path(fasta) ]
    ch_reads    // channel: [ val(meta), path(reads) ]

    main:

    ch_versions      = Channel.empty()
    ch_multiqc_files = Channel.empty()

    //
    // Stats on the input assembly (before purging).
    //
    GFASTATS_BEFORE ( ch_assembly, '' )
    ch_versions      = ch_versions.mix(GFASTATS_BEFORE.out.versions)
    ch_multiqc_files = ch_multiqc_files.mix(GFASTATS_BEFORE.out.stats.map { meta, f -> f })

    //
    // 1. Align reads to the assembly for coverage. Join reads+assembly by meta
    //    and provide the reference as a (meta2, reference) tuple.
    //
    ch_reads_vs_asm = ch_reads
        .join(ch_assembly, by: 0)
        .multiMap { meta, reads, asm ->
            reads     : tuple(meta, reads)
            reference : tuple(meta, asm)
        }

    MINIMAP2_READS (
        ch_reads_vs_asm.reads,
        ch_reads_vs_asm.reference,
        false,        // bam_format = false -> emit PAF
        'map-hifi'    // preset
    )
    ch_versions = ch_versions.mix(MINIMAP2_READS.out.versions)

    //
    // 2. Coverage statistics.
    //
    PURGEDUPS_PBCSTAT ( MINIMAP2_READS.out.paf )
    ch_versions = ch_versions.mix(PURGEDUPS_PBCSTAT.out.versions)

    //
    // 3. Coverage cutoffs.
    //
    PURGEDUPS_CALCUTS ( PURGEDUPS_PBCSTAT.out.stat )
    ch_versions = ch_versions.mix(PURGEDUPS_CALCUTS.out.versions)

    //
    // 4. Split the assembly for the self-alignment.
    //
    PURGEDUPS_SPLITFA ( ch_assembly )
    ch_versions = ch_versions.mix(PURGEDUPS_SPLITFA.out.versions)

    //
    // 5. Self-align the split assembly (asm5).
    //
    ch_self_in = PURGEDUPS_SPLITFA.out.split_fasta
        .multiMap { meta, split ->
            reads     : tuple(meta, split)
            reference : tuple(meta, split)
        }

    MINIMAP2_SELF (
        ch_self_in.reads,
        ch_self_in.reference,
        false,    // bam_format = false -> emit PAF
        'asm5'    // preset
    )
    ch_versions = ch_versions.mix(MINIMAP2_SELF.out.versions)

    //
    // 6. Purge: combine basecov + cutoff + self-PAF by meta.
    //
    ch_purge_in = PURGEDUPS_PBCSTAT.out.basecov
        .join(PURGEDUPS_CALCUTS.out.cutoff, by: 0)
        .join(MINIMAP2_SELF.out.paf, by: 0)
        .map { meta, basecov, cutoff, self_paf ->
            tuple(meta, basecov, cutoff, self_paf)
        }

    PURGEDUPS_PURGEDUPS ( ch_purge_in )
    ch_versions = ch_versions.mix(PURGEDUPS_PURGEDUPS.out.versions)

    //
    // 7. Extract purged sequences: assembly + dups bed joined by meta.
    //
    ch_getseqs_in = ch_assembly
        .join(PURGEDUPS_PURGEDUPS.out.bed, by: 0)
        .map { meta, asm, bed -> tuple(meta, asm, bed) }

    PURGEDUPS_GETSEQS ( ch_getseqs_in )
    ch_versions = ch_versions.mix(PURGEDUPS_GETSEQS.out.versions)

    //
    // Stats on the purged assembly (after purging).
    //
    GFASTATS_AFTER ( PURGEDUPS_GETSEQS.out.purged, '' )
    ch_versions      = ch_versions.mix(GFASTATS_AFTER.out.versions)
    ch_multiqc_files = ch_multiqc_files.mix(GFASTATS_AFTER.out.stats.map { meta, f -> f })

    emit:
    purged_assembly = PURGEDUPS_GETSEQS.out.purged     // channel: [ val(meta), path(*.purged.fa) ]
    haplotigs       = PURGEDUPS_GETSEQS.out.haplotigs  // channel: [ val(meta), path(*.hap.fa) ]
    before_stats    = GFASTATS_BEFORE.out.stats        // channel: [ val(meta), path(*.gfastats.txt) ]
    after_stats     = GFASTATS_AFTER.out.stats         // channel: [ val(meta), path(*.gfastats.txt) ]
    multiqc_files   = ch_multiqc_files                 // channel: [ path(...) ]
    versions        = ch_versions                      // channel: [ path(versions.yml) ]
}
