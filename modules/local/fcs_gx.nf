process FCS_GX {
    tag "$meta.id"
    label 'process_high_memory'

    // NOTE: fcs-gx is distributed only as an NCBI image (ncbi/fcs-gx:0.5.4);
    // it is NOT available on the Galaxy depot, so both singularity and docker
    // engines use the same NCBI container reference below.
    conda "bioconda::fcs-gx=0.5.4"
    container "ncbi/fcs-gx:0.5.4"

    input:
    tuple val(meta), path(assembly)
    val   tax_id
    path  gxdb

    output:
    tuple val(meta), path("*.fcs_gx_report.txt"), emit: report
    tuple val(meta), path("*.taxonomy.rpt")     , emit: taxonomy
    tuple val(meta), path("*.clean.fasta")      , emit: cleaned
    tuple val(meta), path("*.contam.fasta")     , emit: contam
    path "versions.yml"                          , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def args2 = task.ext.args2 ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    # Screen the assembly against the GX database for foreign contamination
    run_gx \\
        --fasta $assembly \\
        --gx-db $gxdb \\
        --tax-id $tax_id \\
        --out-dir ./ \\
        --out-basename ${prefix} \\
        $args

    # Standardise the GX report / taxonomy report names
    mv ${prefix}*.fcs_gx_report.txt ${prefix}.fcs_gx_report.txt 2>/dev/null || \\
        cp \$(ls *.fcs_gx_report.txt | head -n1) ${prefix}.fcs_gx_report.txt
    mv ${prefix}*.taxonomy.rpt ${prefix}.taxonomy.rpt 2>/dev/null || \\
        cp \$(ls *.taxonomy.rpt | head -n1) ${prefix}.taxonomy.rpt

    # Split the assembly into clean and contaminant sequences
    cat $assembly | gx clean-genome \\
        --action-report ${prefix}.fcs_gx_report.txt \\
        --output ${prefix}.clean.fasta \\
        --contam-fasta-out ${prefix}.contam.fasta \\
        $args2

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        fcs-gx: \$(run_gx --version 2>&1 | sed 's/^.*version: //; s/ .*\$//' || echo 0.5.4)
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.fcs_gx_report.txt
    touch ${prefix}.taxonomy.rpt
    touch ${prefix}.clean.fasta
    touch ${prefix}.contam.fasta

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        fcs-gx: 0.5.4
    END_VERSIONS
    """
}
