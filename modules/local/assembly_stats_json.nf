process ASSEMBLY_STATS_JSON {
    tag "$meta.id"
    label 'process_single'

    conda "conda-forge::pandas=2.2.1"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/pandas:2.2.1' :
        'biocontainers/pandas:2.2.1' }"

    input:
    tuple val(meta), path(gfastats_txt), path(busco_json), path(merqury_qv), path(tidk_search), path(telomere_json)

    output:
    tuple val(meta), path("*.assembly_stats.json"), emit: json
    path "versions.yml"                           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def busco_arg = busco_json ? "--busco-json ${busco_json}" : ''
    def merqury_arg = merqury_qv ? "--merqury-qv ${merqury_qv}" : ''
    def tidk_arg = tidk_search ? "--tidk-search ${tidk_search}" : ''
    def telomere_arg = telomere_json ? "--telomere-json ${telomere_json}" : ''
    """
    assembly_stats.py \\
        --sample ${meta.id} \\
        --gfastats $gfastats_txt \\
        $busco_arg \\
        $merqury_arg \\
        $tidk_arg \\
        $telomere_arg \\
        --out ${prefix}.assembly_stats.json \\
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
    touch ${prefix}.assembly_stats.json

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: 3.10
        pandas: 2.2.1
    END_VERSIONS
    """
}
