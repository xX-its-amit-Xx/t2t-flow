process KRAKEN2 {
    tag "$meta.id"
    label 'process_high'

    conda "bioconda::kraken2=2.1.3"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/kraken2:2.1.3--pl5321h077b44d_4' :
        'biocontainers/kraken2:2.1.3--pl5321h077b44d_4' }"

    input:
    tuple val(meta), path(reads)
    path  db
    val   save_output_reads

    output:
    tuple val(meta), path("*.kraken2.report.txt")            , emit: report
    tuple val(meta), path("*.classified*.fastq.gz")          , emit: classified_reads_fastq  , optional: true
    tuple val(meta), path("*.unclassified*.fastq.gz")        , emit: unclassified_reads_fastq, optional: true
    tuple val(meta), path("*.kraken2.classifiedreads.txt")   , emit: classified_assignment   , optional: true
    path "versions.yml"                                       , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def classified   = save_output_reads ? "--classified-out ${prefix}.classified.fastq"     : ""
    def unclassified = save_output_reads ? "--unclassified-out ${prefix}.unclassified.fastq" : ""
    def readclassification = save_output_reads ? "--output ${prefix}.kraken2.classifiedreads.txt" : "--output /dev/null"
    def compress_reads_command = save_output_reads ? "gzip --no-name *.fastq" : ""
    """
    kraken2 \\
        --db $db \\
        --threads $task.cpus \\
        --report ${prefix}.kraken2.report.txt \\
        $classified \\
        $unclassified \\
        $readclassification \\
        $args \\
        $reads

    $compress_reads_command

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        kraken2: \$(echo \$(kraken2 --version 2>&1) | sed 's/^.*Kraken version //; s/ .*\$//')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def classified_reads   = save_output_reads ? "touch ${prefix}.classified.fastq.gz"   : ""
    def unclassified_reads = save_output_reads ? "touch ${prefix}.unclassified.fastq.gz" : ""
    def classified_assignment = save_output_reads ? "touch ${prefix}.kraken2.classifiedreads.txt" : ""
    """
    touch ${prefix}.kraken2.report.txt
    $classified_reads
    $unclassified_reads
    $classified_assignment

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        kraken2: 2.1.3
    END_VERSIONS
    """
}
