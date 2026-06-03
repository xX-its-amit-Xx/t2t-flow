process MERYL_COUNT {
    tag "$meta.id"
    label 'process_medium'

    conda "bioconda::meryl=1.4.1"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/meryl:1.4.1--h9948957_2' :
        'biocontainers/meryl:1.4.1--h9948957_2' }"

    input:
    tuple val(meta), path(reads)
    val kmer

    output:
    tuple val(meta), path("*.meryldb"), emit: meryl_db
    path "versions.yml"               , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    meryl \\
        count \\
        k=$kmer \\
        threads=$task.cpus \\
        memory=${task.memory.toGiga()} \\
        $args \\
        output ${prefix}.meryldb \\
        $reads

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        meryl: \$(meryl --version 2>&1 | sed 's/meryl //g')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    mkdir -p ${prefix}.meryldb

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        meryl: 1.4.1
    END_VERSIONS
    """
}
