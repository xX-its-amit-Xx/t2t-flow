//
// ASSEMBLY: de novo contig assembly.
//
// Dispatches on params.assembler:
//   hifiasm -> HIFIASM (HiFi + optional ONT ultra-long + optional Hi-C phasing)
//   flye    -> FLYE   (HiFi if present else ONT, with params.flye_mode)
//   verkko  -> VERKKO (HiFi + optional ONT)
// Optional ONT / Hi-C inputs are joined by meta and missing entries are filled
// with empty lists [] so the module flag-building logic can detect absence.
//

include { HIFIASM  } from '../../modules/local/hifiasm.nf'
include { FLYE     } from '../../modules/local/flye.nf'
include { VERKKO   } from '../../modules/local/verkko.nf'

workflow ASSEMBLY {

    take:
    ch_hifi // channel: [ val(meta), path(hifi) ]
    ch_ont  // channel: [ val(meta), path(ont)  ]
    ch_hic  // channel: [ val(meta), [ path(hic1), path(hic2) ] ]

    main:

    ch_versions      = Channel.empty()
    ch_multiqc_files = Channel.empty()
    ch_assembly      = Channel.empty()
    ch_haplotigs     = Channel.empty()
    ch_gfa           = Channel.empty()

    if (params.assembler == 'hifiasm') {

        //
        // Join hifi with optional ont and hic by meta. Use remainder joins so
        // samples lacking ont/hic still flow through; fill the gaps with [].
        //
        ch_hifiasm_in = ch_hifi
            .map { meta, hifi -> [ meta.id, meta, hifi ] }
            .join( ch_ont.map { meta, ont -> [ meta.id, ont ] }, remainder: true )
            .join( ch_hic.map { meta, hic -> [ meta.id, hic ] }, remainder: true )
            .map { id, meta, hifi, ont, hic ->
                def ont_in  = ont ?: []
                def hic1_in = (hic && hic.size() > 0) ? hic[0] : []
                def hic2_in = (hic && hic.size() > 1) ? hic[1] : []
                tuple(meta, hifi, ont_in, hic1_in, hic2_in)
            }

        HIFIASM ( ch_hifiasm_in )
        ch_versions      = ch_versions.mix(HIFIASM.out.versions)
        ch_multiqc_files = ch_multiqc_files.mix(HIFIASM.out.log.map { meta, f -> f })

        ch_assembly  = HIFIASM.out.assembly
        // hap1/hap2 are the alternate haplotype contig sets.
        ch_haplotigs = HIFIASM.out.hap1_fasta.mix(HIFIASM.out.hap2_fasta)
        ch_gfa       = HIFIASM.out.primary_contigs_gfa

    }
    else if (params.assembler == 'flye') {

        //
        // Flye takes a single read set: prefer HiFi, fall back to ONT. Tag by
        // type, group by sample id and select HiFi when present.
        //
        ch_flye_in = ch_hifi.map    { meta, reads -> [ meta.id, [ meta: meta, type: 'hifi', reads: reads ] ] }
            .mix( ch_ont.map { meta, reads -> [ meta.id, [ meta: meta, type: 'ont',  reads: reads ] ] } )
            .groupTuple()
            .map { id, entries ->
                def hifi = entries.find { it.type == 'hifi' }
                def chosen = hifi ?: entries.find { it.type == 'ont' }
                tuple( chosen.meta, chosen.reads )
            }

        FLYE ( ch_flye_in, params.flye_mode )
        ch_versions      = ch_versions.mix(FLYE.out.versions)
        ch_multiqc_files = ch_multiqc_files.mix(FLYE.out.txt.map { meta, f -> f })

        ch_assembly = FLYE.out.assembly
        ch_gfa      = FLYE.out.gfa

    }
    else if (params.assembler == 'verkko') {

        //
        // Verkko takes HiFi + optional ONT.
        //
        ch_verkko_in = ch_hifi
            .map { meta, hifi -> [ meta.id, meta, hifi ] }
            .join( ch_ont.map { meta, ont -> [ meta.id, ont ] }, remainder: true )
            .map { id, meta, hifi, ont ->
                tuple(meta, hifi, ont ?: [])
            }

        VERKKO ( ch_verkko_in )
        ch_versions = ch_versions.mix(VERKKO.out.versions)

        ch_assembly = VERKKO.out.assembly
        ch_gfa      = VERKKO.out.graph

    }
    else {
        error "Unknown assembler '${params.assembler}'. Choose one of: hifiasm, flye, verkko."
    }

    emit:
    assembly      = ch_assembly       // channel: [ val(meta), path(fasta) ]
    haplotigs     = ch_haplotigs      // channel: [ val(meta), path(fasta) ] (may be empty)
    gfa           = ch_gfa            // channel: [ val(meta), path(gfa) ]
    multiqc_files = ch_multiqc_files  // channel: [ path(...) ]
    versions      = ch_versions       // channel: [ path(versions.yml) ]
}
