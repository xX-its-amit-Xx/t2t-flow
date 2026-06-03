process TIDK_EXPLORE {
    tag "$meta.id"
    label 'process_low'

    conda "bioconda::tidk=0.2.63"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/tidk:0.2.63--h3dc2dae_2' :
        'biocontainers/tidk:0.2.63--h3dc2dae_2' }"

    input:
    tuple val(meta), path(assembly)

    output:
    tuple val(meta), path("*.explore.tsv"), emit: explore_tsv
    path "versions.yml"                   , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    tidk explore \\
        --minimum 5 \\
        --maximum 12 \\
        $args \\
        $assembly \\
        > ${prefix}.explore.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        tidk: \$(echo \$(tidk --version 2>&1) | sed 's/^.*tidk //')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.explore.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        tidk: 0.2.63
    END_VERSIONS
    """
}

process TIDK_SEARCH {
    tag "$meta.id"
    label 'process_low'

    conda "bioconda::tidk=0.2.63"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/tidk:0.2.63--h3dc2dae_2' :
        'biocontainers/tidk:0.2.63--h3dc2dae_2' }"

    input:
    tuple val(meta), path(assembly)
    val motif

    output:
    tuple val(meta), path("*.tidk.search.tsv"), emit: search_tsv
    tuple val(meta), path("*.bedgraph")       , emit: bedgraph, optional: true
    path "versions.yml"                       , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    tidk search \\
        --string $motif \\
        --output $prefix \\
        --dir . \\
        --extension tsv \\
        $args \\
        $assembly

    # Normalise tidk's default output name to the expected glob
    cp ${prefix}_telomeric_repeat_windows.tsv ${prefix}.tidk.search.tsv 2>/dev/null || \\
        cp *_telomeric_repeat_windows.tsv ${prefix}.tidk.search.tsv 2>/dev/null || \\
        touch ${prefix}.tidk.search.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        tidk: \$(echo \$(tidk --version 2>&1) | sed 's/^.*tidk //')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.tidk.search.tsv
    touch ${prefix}.bedgraph

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        tidk: 0.2.63
    END_VERSIONS
    """
}

process TIDK_PLOT {
    tag "$meta.id"
    label 'process_low'

    conda "bioconda::tidk=0.2.63"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/tidk:0.2.63--h3dc2dae_2' :
        'biocontainers/tidk:0.2.63--h3dc2dae_2' }"

    input:
    tuple val(meta), path(search_tsv)

    output:
    tuple val(meta), path("*.tidk.plot.svg"), emit: svg
    path "versions.yml"                     , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    tidk plot \\
        --tsv $search_tsv \\
        --output ${prefix}.tidk.plot \\
        $args

    # tidk appends .svg automatically; ensure expected name exists
    [ -f ${prefix}.tidk.plot.svg ] || cp *.svg ${prefix}.tidk.plot.svg 2>/dev/null || touch ${prefix}.tidk.plot.svg

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        tidk: \$(echo \$(tidk --version 2>&1) | sed 's/^.*tidk //')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.tidk.plot.svg

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        tidk: 0.2.63
    END_VERSIONS
    """
}
