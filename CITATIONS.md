# t2t-flow: Citations

If you use **t2t-flow** for your analysis, please cite the pipeline and the
tools it orchestrates. t2t-flow performs telomere-to-telomere de novo genome
assembly of non-model organisms from long reads and is distributed under the
GNU General Public License v3.0 (GPLv3).

## Pipeline

- **t2t-flow**

  > t2t-flow: a Nextflow DSL2 pipeline for telomere-to-telomere de novo genome
  > assembly of non-model organisms from long reads. GPLv3.
  > Repository: https://github.com/t2t-flow/t2t-flow

## Pipeline framework and conventions

- **Nextflow**

  > Di Tommaso P, Chatzou M, Floden EW, Barja PP, Palumbo E, Notredame C.
  > Nextflow enables reproducible computational workflows. Nat Biotechnol.
  > 2017 Apr 11;35(4):316-319. doi: 10.1038/nbt.3820. PubMed PMID: 28398311.
  >
  > URL: https://www.nextflow.io/

- **nf-core**

  > Ewels PA, Peltzer A, Fillinger S, Patel H, Alneberg J, Wilm A, Garcia MU,
  > Di Tommaso P, Nahnsen S. The nf-core framework for community-curated
  > bioinformatics pipelines. Nat Biotechnol. 2020 Mar;38(3):276-278.
  > doi: 10.1038/s41587-020-0439-x. PubMed PMID: 32055031.
  >
  > URL: https://nf-co.re/

- **nf-schema** (Nextflow plugin for parameter and samplesheet validation)

  > nf-schema: a Nextflow plugin for validating pipeline parameters and input
  > samplesheets against a JSON schema.
  > URL: https://nextflow-io.github.io/nf-schema/

## Read QC and genome profiling

- **NanoPlot**

  > De Coster W, D'Hert S, Schultz DT, Cruts M, Van Broeckhoven C. NanoPack:
  > visualizing and processing long-read sequencing data. Bioinformatics.
  > 2018 Aug 1;34(15):2666-2669. doi: 10.1093/bioinformatics/bty149.
  > PubMed PMID: 29547981.
  >
  > URL: https://github.com/wdecoster/NanoPlot

- **SeqKit**

  > Shen W, Le S, Li Y, Hu F. SeqKit: A Cross-Platform and Ultrafast Toolkit for
  > FASTA/Q File Manipulation. PLoS One. 2016 Oct 5;11(10):e0163962.
  > doi: 10.1371/journal.pone.0163962. PubMed PMID: 27706213.
  >
  > URL: https://bioinf.shenwei.me/seqkit/

- **Meryl** and **Merqury**

  > Rhie A, Walenz BP, Koren S, Phillippy AM. Merqury: reference-free quality,
  > completeness, and phasing assessment for genome assemblies. Genome Biol.
  > 2020 Sep 14;21(1):245. doi: 10.1186/s13059-020-02134-9.
  > PubMed PMID: 32928274.
  >
  > URL: https://github.com/marbl/merqury (Merqury),
  > https://github.com/marbl/meryl (Meryl)

- **GenomeScope2**

  > Ranallo-Benavidez TR, Jaron KS, Schatz MC. GenomeScope 2.0 and Smudgeplot
  > for reference-free profiling of polyploid genomes. Nat Commun.
  > 2020 Mar 18;11(1):1432. doi: 10.1038/s41467-020-14998-3.
  > PubMed PMID: 32188846.
  >
  > URL: https://github.com/tbenavi1/genomescope2.0

## Contamination screening

- **Kraken2**

  > Wood DE, Lu J, Langmead B. Improved metagenomic analysis with Kraken 2.
  > Genome Biol. 2019 Nov 28;20(1):257. doi: 10.1186/s13059-019-1891-0.
  > PubMed PMID: 31779668.
  >
  > URL: https://github.com/DerrickWood/kraken2

- **KrakenTools**

  > Lu J, Rincon N, Wood DE, Breitwieser FP, Pockrandt C, Langmead B,
  > Salzberg SL, Steinegger M. Metagenome analysis using the Kraken software
  > suite. Nat Protoc. 2022 Dec;17(12):2815-2839.
  > doi: 10.1038/s41596-022-00738-y. PubMed PMID: 36171387.
  >
  > URL: https://github.com/jenniferlu717/KrakenTools

- **FCS-GX** (NCBI Foreign Contamination Screen)

  > Astashyn A, Tvedte ES, Sweeney D, Sapojnikov V, Bouk N, Joukov V, Mozes E,
  > Strope PK, Sylla PM, Wagner L, Bidwell SL, Brown LC, Clark K, Davis EW,
  > Smith-White B, Hlavina W, Pruitt KD, Schneider VA, Murphy TD. Rapid and
  > sensitive detection of genome contamination at scale with FCS-GX.
  > Genome Biol. 2024 Feb 28;25(1):60. doi: 10.1186/s13059-024-03198-7.
  > PubMed PMID: 38416456.
  >
  > URL: https://github.com/ncbi/fcs

## Genome assembly

- **hifiasm**

  > Cheng H, Concepcion GT, Feng X, Zhang H, Li H. Haplotype-resolved de novo
  > assembly using phased assembly graphs with hifiasm. Nat Methods.
  > 2021 Feb;18(2):170-175. doi: 10.1038/s41592-020-01056-5.
  > PubMed PMID: 33526886.
  >
  > URL: https://github.com/chhylp123/hifiasm

- **Verkko**

  > Rautiainen M, Nurk S, Walenz BP, Logsdon GA, Porubsky D, Rhie A, Eichler EE,
  > Phillippy AM, Koren S. Telomere-to-telomere assembly of diploid chromosomes
  > with Verkko. Nat Biotechnol. 2023 Oct;41(10):1474-1482.
  > doi: 10.1038/s41587-023-01662-6. PubMed PMID: 36750770.
  >
  > URL: https://github.com/marbl/verkko

- **Flye**

  > Kolmogorov M, Yuan J, Lin Y, Pevzner PA. Assembly of long, error-prone reads
  > using repeat graphs. Nat Biotechnol. 2019 May;37(5):540-546.
  > doi: 10.1038/s41587-019-0072-8. PubMed PMID: 30936562.
  >
  > URL: https://github.com/fenderglass/Flye

- **gfastats**

  > Formenti G, Abueg L, Brajuka A, Brajuka N, Gallardo-Alba C, Giani A,
  > Fedrigo O, Jarvis ED. Gfastats: conversion, evaluation and manipulation of
  > genome sequences using assembly graphs. Bioinformatics.
  > 2022 Aug 30;38(17):4214-4216. doi: 10.1093/bioinformatics/btac460.
  > PubMed PMID: 35799367.
  >
  > URL: https://github.com/vgl-hub/gfastats

## Read mapping and duplicate purging

- **minimap2**

  > Li H. Minimap2: pairwise alignment for nucleotide sequences. Bioinformatics.
  > 2018 Sep 15;34(18):3094-3100. doi: 10.1093/bioinformatics/bty191.
  > PubMed PMID: 29750242.
  >
  > URL: https://github.com/lh3/minimap2

- **purge_dups**

  > Guan D, McCarthy SA, Wood J, Howe K, Wang Y, Durbin R. Identifying and
  > removing haplotypic duplication in primary genome assemblies.
  > Bioinformatics. 2020 May 1;36(9):2896-2898.
  > doi: 10.1093/bioinformatics/btaa025. PubMed PMID: 31971576.
  >
  > URL: https://github.com/dfguan/purge_dups

- **SAMtools**

  > Danecek P, Bonfield JK, Liddle J, Marshall J, Ohan V, Pollard MO,
  > Whitwham A, Keane T, McCarthy SA, Davies RM, Li H. Twelve years of SAMtools
  > and BCFtools. Gigascience. 2021 Feb 16;10(2):giab008.
  > doi: 10.1093/gigascience/giab008. PubMed PMID: 33590861.
  >
  > URL: https://www.htslib.org/

## Hi-C scaffolding

- **chromap**

  > Zhang H, Song L, Wang X, Cheng H, Wang C, Meyer CA, Liu T, Tang M,
  > Aluru S, Yue F, Liu XS, Li H. Fast alignment and preprocessing of chromatin
  > profiles with Chromap. Nat Commun. 2021 Nov 29;12(1):6566.
  > doi: 10.1038/s41467-021-26865-w. PubMed PMID: 34845218.
  >
  > URL: https://github.com/haowenz/chromap

- **BWA**

  > Li H, Durbin R. Fast and accurate short read alignment with Burrows-Wheeler
  > transform. Bioinformatics. 2009 Jul 15;25(14):1754-60.
  > doi: 10.1093/bioinformatics/btp324. PubMed PMID: 19451168.
  >
  > URL: https://github.com/lh3/bwa

- **YaHS**

  > Zhou C, McCarthy SA, Durbin R. YaHS: yet another Hi-C scaffolding tool.
  > Bioinformatics. 2023 Jan 1;39(1):btac808.
  > doi: 10.1093/bioinformatics/btac808. PubMed PMID: 36525368.
  >
  > URL: https://github.com/c-zhou/yahs

- **SALSA2**

  > Ghurye J, Rhie A, Walenz BP, Schmitt A, Selvaraj S, Pop M, Phillippy AM,
  > Koren S. Integrating Hi-C links with assembly graphs for chromosome-scale
  > assembly. PLoS Comput Biol. 2019 Aug 23;15(8):e1007273.
  > doi: 10.1371/journal.pcbi.1007273. PubMed PMID: 31433799.
  >
  > URL: https://github.com/marbl/SALSA

## Assembly polishing

- **Racon**

  > Vaser R, Sović I, Nagarajan N, Šikić M. Fast and accurate de novo genome
  > assembly from long uncorrected reads. Genome Res. 2017 May;27(5):737-746.
  > doi: 10.1101/gr.214270.116. PubMed PMID: 28100585.
  >
  > URL: https://github.com/isovic/racon

## Assembly evaluation and benchmarking

- **BUSCO**

  > Manni M, Berkeley MR, Seppey M, Simão FA, Zdobnov EM. BUSCO Update: Novel
  > and Streamlined Workflows along with Broader and Deeper Phylogenetic
  > Coverage for Scoring of Eukaryotic, Prokaryotic, and Viral Genomes.
  > Mol Biol Evol. 2021 Sep 27;38(10):4647-4654. doi: 10.1093/molbev/msab199.
  > PubMed PMID: 34320186.
  >
  > URL: https://busco.ezlab.org/

- **QUAST**

  > Gurevich A, Saveliev V, Vyahhi N, Tesler G. QUAST: quality assessment tool
  > for genome assemblies. Bioinformatics. 2013 Apr 15;29(8):1072-5.
  > doi: 10.1093/bioinformatics/btt086. PubMed PMID: 23422339.
  >
  > URL: https://github.com/ablab/quast

- **tidk** (Telomere Identification toolKit)

  > Brown M, González De la Rosa PM, Mark B. A telomere identification toolkit
  > (tidk). Zenodo. doi: 10.5281/zenodo.10091385.
  >
  > URL: https://github.com/tolkit/telomeric-identifier

## Reporting

- **MultiQC**

  > Ewels P, Magnusson M, Lundin S, Käller M. MultiQC: summarize analysis
  > results for multiple tools and samples in a single report. Bioinformatics.
  > 2016 Oct 1;32(19):3047-8. doi: 10.1093/bioinformatics/btw354.
  > PubMed PMID: 27312411.
  >
  > URL: https://multiqc.info/

## Software packaging and containers

- **Anaconda / Bioconda**

  > Grüning B, Dale R, Sjödin A, Chapman BA, Rowe J, Tomkins-Tinch CH,
  > Valieris R, Köster J; Bioconda Team. Bioconda: sustainable and
  > comprehensive software distribution for the life sciences. Nat Methods.
  > 2018 Jul;15(7):475-476. doi: 10.1038/s41592-018-0046-7.
  > PubMed PMID: 29967506.
  >
  > URL: https://bioconda.github.io/

- **BioContainers**

  > da Veiga Leprevost F, Grüning BA, Alves Aflitos S, Röst HL, Uszkoreit J,
  > Barsnes H, Vaudel M, Moreno P, Gatto L, Weber J, Bai M, Jimenez RC,
  > Sachsenberg T, Pfeuffer J, Vera Alvarez R, Griss J, Nesvizhskii AI,
  > Perez-Riverol Y. BioContainers: an open-source and community-driven
  > framework for software standardization. Bioinformatics.
  > 2017 Aug 15;33(16):2580-2582. doi: 10.1093/bioinformatics/btx192.
  > PubMed PMID: 28379341.
  >
  > URL: https://biocontainers.pro/

- **Singularity / Apptainer**

  > Kurtzer GM, Sochat V, Bauer MW. Singularity: Scientific containers for
  > mobility of compute. PLoS One. 2017 May 11;12(5):e0177459.
  > doi: 10.1371/journal.pone.0177459. PubMed PMID: 28494014.
  >
  > URL: https://apptainer.org/

- **Docker**

  > Merkel D. Docker: lightweight Linux containers for consistent development
  > and deployment. Linux Journal. 2014;2014(239):2.
  >
  > URL: https://www.docker.com/

## Supporting Python libraries

- **pandas**

  > The pandas development team. pandas-dev/pandas: Pandas. Zenodo.
  > doi: 10.5281/zenodo.3509134.
  >
  > McKinney W. Data Structures for Statistical Computing in Python.
  > Proceedings of the 9th Python in Science Conference. 2010:56-61.
  > doi: 10.25080/Majora-92bf1922-00a.
  >
  > URL: https://pandas.pydata.org/
