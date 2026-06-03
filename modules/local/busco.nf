process BUSCO {
    tag "$meta.id"
    label 'process_high'

    conda "bioconda::busco=5.8.2"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/busco:5.8.2--pyhdfd78af_0' :
        'biocontainers/busco:5.8.2--pyhdfd78af_0' }"

    input:
    tuple val(meta), path(assembly)
    val lineage
    val mode
    path busco_db

    output:
    tuple val(meta), path("*short_summary*.txt") , emit: short_summary_txt
    tuple val(meta), path("*short_summary*.json"), emit: short_summary_json
    tuple val(meta), path("**/full_table.tsv")   , emit: full_table, optional: true
    tuple val(meta), path("${meta.id}-busco")    , emit: busco_dir
    path "versions.yml"                           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def lineage_arg = (lineage && lineage != 'auto') ? "--lineage_dataset ${lineage}" : '--auto-lineage'
    def db_arg = busco_db ? "--offline --download_path ${busco_db}" : ''
    """
    busco \\
        $args \\
        --in $assembly \\
        --mode $mode \\
        $lineage_arg \\
        $db_arg \\
        --cpu $task.cpus \\
        --out ${prefix}-busco

    # Surface short summary files at top level with predictable globs
    cp ${prefix}-busco/short_summary.*.txt  ${prefix}.short_summary.txt  2>/dev/null || true
    cp ${prefix}-busco/short_summary.*.json ${prefix}.short_summary.json 2>/dev/null || true

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        busco: \$(busco --version 2>&1 | sed 's/^BUSCO //')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    mkdir -p ${prefix}-busco
    touch ${prefix}.short_summary.txt
    touch ${prefix}.short_summary.json
    touch ${prefix}-busco/full_table.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        busco: 5.8.2
    END_VERSIONS
    """
}
