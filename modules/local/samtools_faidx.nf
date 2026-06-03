process SAMTOOLS_FAIDX {
    tag "$meta.id"
    label 'process_single'

    conda "bioconda::samtools=1.21"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/samtools:1.21--h96c455f_1' :
        'biocontainers/samtools:1.21--h96c455f_1' }"

    input:
    tuple val(meta), path(fasta)

    output:
    tuple val(meta), path("*.fai"), emit: fai
    path "versions.yml"           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    """
    samtools faidx $args $fasta

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        samtools: \$(echo \$(samtools --version 2>&1) | sed 's/^.*samtools //; s/ .*\$//')
    END_VERSIONS
    """

    stub:
    """
    touch ${fasta}.fai

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        samtools: 1.21
    END_VERSIONS
    """
}
