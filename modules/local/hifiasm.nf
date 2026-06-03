process HIFIASM {
    tag "$meta.id"
    label 'process_high_memory'

    conda "bioconda::hifiasm=0.20.0"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/hifiasm:0.20.0--h5ca1c30_0' :
        'biocontainers/hifiasm:0.20.0--h5ca1c30_0' }"

    input:
    tuple val(meta), path(hifi), path(ont), path(hic1), path(hic2)

    output:
    tuple val(meta), path("*.primary.p_ctg.gfa")  , emit: primary_contigs_gfa
    tuple val(meta), path("*.hap1.p_ctg.gfa")     , emit: hap1_contigs_gfa, optional: true
    tuple val(meta), path("*.hap2.p_ctg.gfa")     , emit: hap2_contigs_gfa, optional: true
    tuple val(meta), path("*.primary.p_ctg.fasta"), emit: assembly
    tuple val(meta), path("*.hap1.p_ctg.fasta")   , emit: hap1_fasta, optional: true
    tuple val(meta), path("*.hap2.p_ctg.fasta")   , emit: hap2_fasta, optional: true
    tuple val(meta), path("*.hifiasm.log")        , emit: log
    path "versions.yml"                           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    // ont and hic1/hic2 may be staged as empty lists -> build flags conditionally.
    def ul_arg  = ont ? "--ul ${ont}" : ''
    def hic_arg = (hic1 && hic2) ? "--h1 ${hic1} --h2 ${hic2}" : ''
    """
    hifiasm \\
        -o ${prefix}.asm \\
        -t $task.cpus \\
        $ul_arg \\
        $hic_arg \\
        $args \\
        $hifi \\
        2> ${prefix}.hifiasm.log

    # hifiasm writes GFA contig graphs whose names vary by mode (.bp.*, .hic.*).
    # Classify each *.p_ctg.gfa as primary / hap1 / hap2 and convert to FASTA with
    # STABLE names so the primary emit glob does not also capture the haplotypes
    # (awk ships in the hifiasm image).
    shopt -s nullglob
    for gfa in *.p_ctg.gfa; do
        case "\$gfa" in
            *hap1.p_ctg.gfa) tag=hap1 ;;
            *hap2.p_ctg.gfa) tag=hap2 ;;
            *)               tag=primary ;;
        esac
        awk '/^S/{print ">"\$2; print \$3}' "\$gfa" > "${prefix}.\${tag}.p_ctg.fasta"
        cp "\$gfa" "${prefix}.\${tag}.p_ctg.gfa"
    done

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        hifiasm: \$(hifiasm --version 2>&1 | sed 's/^hifiasm //g')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.primary.p_ctg.gfa
    touch ${prefix}.hap1.p_ctg.gfa
    touch ${prefix}.hap2.p_ctg.gfa
    touch ${prefix}.primary.p_ctg.fasta
    touch ${prefix}.hap1.p_ctg.fasta
    touch ${prefix}.hap2.p_ctg.fasta
    touch ${prefix}.hifiasm.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        hifiasm: 0.20.0
    END_VERSIONS
    """
}
