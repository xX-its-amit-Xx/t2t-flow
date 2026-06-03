process TELOMERE_TABLE {
    tag "$meta.id"
    label 'process_single'

    conda "conda-forge::pandas=2.2.1"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/pandas:2.2.1' :
        'biocontainers/pandas:2.2.1' }"

    input:
    tuple val(meta), path(tidk_search_tsv), path(fai), path(agp)

    output:
    tuple val(meta), path("*.telomere_centromere.tsv") , emit: table_tsv
    tuple val(meta), path("*.telomere_centromere.json"), emit: table_json
    path "versions.yml"                                , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def agp_arg = agp ? "--agp ${agp}" : ''
    """
    telomere_table.py \\
        --tidk-search $tidk_search_tsv \\
        --fai $fai \\
        $agp_arg \\
        --out-tsv ${prefix}.telomere_centromere.tsv \\
        --out-json ${prefix}.telomere_centromere.json \\
        $args

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version 2>&1 | sed 's/Python //')
        pandas: \$(python -c "import pandas; print(pandas.__version__)")
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.telomere_centromere.tsv
    touch ${prefix}.telomere_centromere.json

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: 3.10
        pandas: 2.2.1
    END_VERSIONS
    """
}
