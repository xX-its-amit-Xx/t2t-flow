process YAHS {
    tag "$meta.id"
    label 'process_high'

    conda "bioconda::yahs=1.2.2"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/yahs:1.2.2--h7132678_0' :
        'biocontainers/yahs:1.2.2--h7132678_0' }"

    input:
    tuple val(meta), path(assembly), path(fai), path(hic_alignments)

    output:
    tuple val(meta), path("*_scaffolds_final.fa") , emit: scaffolds_fasta
    tuple val(meta), path("*_scaffolds_final.agp"), emit: scaffolds_agp
    tuple val(meta), path("*.bin")                , emit: bin
    path "versions.yml"                           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    yahs \\
        $args \\
        -o $prefix \\
        $assembly \\
        $hic_alignments

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        yahs: \$(echo \$(yahs --version 2>&1) | sed 's/^.*yahs //; s/ .*\$//')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}_scaffolds_final.fa
    touch ${prefix}_scaffolds_final.agp
    touch ${prefix}.bin

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        yahs: 1.2.2
    END_VERSIONS
    """
}
