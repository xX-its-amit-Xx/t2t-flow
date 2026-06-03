//
// POLISHING: optional consensus polishing with Racon.
//
// When params.run_polishing is true, map the long reads back to the assembly
// with MINIMAP2_ALIGN (PAF) and polish with RACON. Otherwise the assembly
// passes through unchanged so a polished channel is always emitted.
//

include { MINIMAP2_ALIGN } from '../../modules/local/minimap2_align.nf'
include { RACON          } from '../../modules/local/racon.nf'

workflow POLISHING {

    take:
    ch_assembly // channel: [ val(meta), path(fasta) ]
    ch_reads    // channel: [ val(meta), path(reads) ]

    main:

    ch_versions = Channel.empty()

    if (params.run_polishing) {

        //
        // Map reads to the assembly -> PAF. Join reads + assembly by meta.
        //
        ch_align_in = ch_reads
            .join(ch_assembly, by: 0)
            .multiMap { meta, reads, asm ->
                reads     : tuple(meta, reads)
                reference : tuple(meta, asm)
            }

        MINIMAP2_ALIGN (
            ch_align_in.reads,
            ch_align_in.reference,
            false,        // bam_format = false -> emit PAF (racon consumes PAF)
            'map-hifi'    // preset
        )
        ch_versions = ch_versions.mix(MINIMAP2_ALIGN.out.versions)

        //
        // RACON needs (meta, reads, paf, assembly). Join all three by meta.
        //
        ch_racon_in = ch_reads
            .join(MINIMAP2_ALIGN.out.paf, by: 0)
            .join(ch_assembly, by: 0)
            .map { meta, reads, paf, asm -> tuple(meta, reads, paf, asm) }

        RACON ( ch_racon_in )
        ch_versions = ch_versions.mix(RACON.out.versions)

        ch_polished = RACON.out.polished

    }
    else {
        // Polishing disabled: pass the assembly through unchanged.
        ch_polished = ch_assembly
    }

    emit:
    polished = ch_polished  // channel: [ val(meta), path(fasta) ]
    versions = ch_versions  // channel: [ path(versions.yml) ]
}
