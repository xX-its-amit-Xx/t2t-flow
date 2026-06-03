process VERKKO {
    tag "$meta.id"
    label 'process_high_memory'

    conda "bioconda::verkko=2.2"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/verkko:2.2--h45dadce_0' :
        'biocontainers/verkko:2.2--h45dadce_0' }"

    input:
    tuple val(meta), path(hifi), path(ont)

    output:
    tuple val(meta), path("*.fasta"), emit: assembly
    tuple val(meta), path("*.gfa")  , emit: graph
    path "versions.yml"             , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def nano_arg = ont ? "--nano ${ont}" : ''
    """
    verkko \\
        -d ${prefix}_verkko \\
        --hifi $hifi \\
        $nano_arg \\
        --local-cpus $task.cpus \\
        $args

    # Surface the primary assembly + graph with the sample prefix
    cp ${prefix}_verkko/assembly.fasta ${prefix}.assembly.fasta
    cp ${prefix}_verkko/assembly.homopolymer-compressed.gfa ${prefix}.assembly.gfa

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        verkko: \$(verkko --version 2>&1 | sed 's/^verkko //g')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.assembly.fasta
    touch ${prefix}.assembly.gfa

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        verkko: 2.2
    END_VERSIONS
    """
}
