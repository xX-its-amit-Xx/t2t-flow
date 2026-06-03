//
// SCAFFOLDING: Hi-C scaffolding of a contig assembly.
//
// Steps:
//   1. SAMTOOLS_FAIDX  -> assembly .fai
//   2. CHROMAP_INDEX   -> chromap index
//   3. CHROMAP         -> Hi-C alignments as SAM (chromap image has no samtools)
//   4. SAMTOOLS_SORT   -> sorted/converted BAM (separate process; chromap image
//                         cannot sort, per the module contract)
//   5a. YAHS   -> scaffolds (default scaffolder), OR
//   5b. SALSA2 -> scaffolds (needs a Hi-C BED + restriction enzyme)
//
// Invoked by main.nf only when !params.skip_scaffolding.
//

include { SAMTOOLS_FAIDX } from '../../modules/local/samtools_faidx.nf'
include { CHROMAP_INDEX  } from '../../modules/local/chromap_index.nf'
include { CHROMAP        } from '../../modules/local/chromap.nf'
include { SAMTOOLS_SORT  } from '../../modules/local/samtools_sort.nf'
include { YAHS           } from '../../modules/local/yahs.nf'
include { SALSA2         } from '../../modules/local/salsa2.nf'

workflow SCAFFOLDING {

    take:
    ch_assembly // channel: [ val(meta), path(fasta) ]
    ch_hic      // channel: [ val(meta), [ path(hic1), path(hic2) ] ]

    main:

    ch_versions      = Channel.empty()
    ch_multiqc_files = Channel.empty()

    //
    // 1. Index the assembly for samtools/scaffolders.
    //
    SAMTOOLS_FAIDX ( ch_assembly )
    ch_versions = ch_versions.mix(SAMTOOLS_FAIDX.out.versions)

    //
    // 2. Build the chromap index.
    //
    CHROMAP_INDEX ( ch_assembly )
    ch_versions = ch_versions.mix(CHROMAP_INDEX.out.versions)

    //
    // 3. Align Hi-C reads. Provide reads, the reference and the index, each
    //    joined by meta. Hi-C reads are [r1, r2].
    //
    ch_chromap_reads = ch_hic.map { meta, reads ->
        def r1 = (reads && reads.size() > 0) ? reads[0] : []
        def r2 = (reads && reads.size() > 1) ? reads[1] : []
        tuple(meta, r1, r2)
    }

    CHROMAP (
        ch_chromap_reads,
        ch_assembly,
        CHROMAP_INDEX.out.index
    )
    ch_versions = ch_versions.mix(CHROMAP.out.versions)

    //
    // 4. Sort/convert chromap SAM to BAM (separate process; chromap image has
    //    no samtools). The BAM is read-name-sorted (`samtools sort -n`, set in
    //    conf/modules.config): YaHS prefers name-sorted input (it then counts
    //    Hi-C links between alignment mid-points and applies MAPQ filtering), and
    //    SALSA2 requires name-sorted alignments.
    //
    SAMTOOLS_SORT ( CHROMAP.out.sam )
    ch_versions = ch_versions.mix(SAMTOOLS_SORT.out.versions)

    if (params.scaffolder == 'yahs') {

        //
        // 5a. YAHS: assembly + fai + Hi-C alignments (sorted BAM), joined by meta.
        //
        ch_yahs_in = ch_assembly
            .join(SAMTOOLS_FAIDX.out.fai, by: 0)
            .join(SAMTOOLS_SORT.out.bam, by: 0)
            .map { meta, asm, fai, bam -> tuple(meta, asm, fai, bam) }

        YAHS ( ch_yahs_in )
        ch_versions = ch_versions.mix(YAHS.out.versions)

        ch_scaffolds = YAHS.out.scaffolds_fasta
        ch_agp       = YAHS.out.scaffolds_agp

    }
    else if (params.scaffolder == 'salsa') {

        //
        // 5b. SALSA2: assembly + fai + Hi-C BED + restriction enzyme. SALSA
        //     expects a BED of Hi-C alignments; the sorted BAM stands in here
        //     and the SALSA2 module performs any bam->bed conversion internally.
        //
        ch_salsa_in = ch_assembly
            .join(SAMTOOLS_FAIDX.out.fai, by: 0)
            .join(SAMTOOLS_SORT.out.bam, by: 0)
            .map { meta, asm, fai, bam -> tuple(meta, asm, fai, bam) }

        SALSA2 ( ch_salsa_in, params.hic_enzyme )
        ch_versions = ch_versions.mix(SALSA2.out.versions)

        ch_scaffolds = SALSA2.out.scaffolds_fasta
        ch_agp       = SALSA2.out.scaffolds_agp

    }
    else {
        error "Unknown scaffolder '${params.scaffolder}'. Choose one of: yahs, salsa."
    }

    // =====================================================================
    // TODO: Bionano / optical-map scaffolding hook.
    //
    // When an optical map (Bionano DLE-1 CMAP) is supplied, a hybrid
    // scaffolding step can be inserted AFTER Hi-C scaffolding to bridge and
    // orient super-scaffolds. The process is intentionally commented out
    // because the Bionano Solve toolchain is licensed and not containerised on
    // the Galaxy depot. To enable:
    //   1. Add a BIONANO_HYBRIDSCAFFOLD module under modules/local/.
    //   2. Add params.bionano_cmap (path) + params.run_bionano (bool).
    //   3. Wire it here, e.g.:
    //
    // include { BIONANO_HYBRIDSCAFFOLD } from '../../modules/local/bionano_hybridscaffold.nf'
    //
    // if (params.run_bionano && params.bionano_cmap) {
    //     ch_cmap = file(params.bionano_cmap, checkIfExists: true)
    //     BIONANO_HYBRIDSCAFFOLD ( ch_scaffolds, ch_cmap )
    //     ch_versions  = ch_versions.mix(BIONANO_HYBRIDSCAFFOLD.out.versions)
    //     ch_scaffolds = BIONANO_HYBRIDSCAFFOLD.out.scaffolds_fasta
    //     ch_agp       = BIONANO_HYBRIDSCAFFOLD.out.scaffolds_agp
    // }
    // =====================================================================

    emit:
    scaffolds     = ch_scaffolds      // channel: [ val(meta), path(fasta) ]
    agp           = ch_agp            // channel: [ val(meta), path(agp) ]
    multiqc_files = ch_multiqc_files  // channel: [ path(...) ]
    versions      = ch_versions       // channel: [ path(versions.yml) ]
}
