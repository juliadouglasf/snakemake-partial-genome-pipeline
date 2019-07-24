# Snakemake file to process partial genome sequences generated from UCE target enrichment experiments
# Author: Jackson Eyres jackson.eyres@agr.gc.ca
# Copyright: Government of Canada
# License: MIT
# Version 0.4

import glob
import os
from shutil import copyfile

# Configuration Settings

# Location of fastq folder, default "fastq". Phyluce requires files to not mix "-" and "_", so fastq files renamed
for f in glob.glob('fastq/*.fastq.gz'):
    basename = os.path.basename(f)
    new_basename = ""

    new_basename = basename.replace("-","_")
    if new_basename[0].isdigit(): # Phyluce doesn't work with samples starting with digits
        new_basename = "Sample_" + new_basename
    new_path = f.replace(basename, new_basename)
    os.rename(f, new_path)

# Need sample name without the Illumina added information to the fastq files
SAMPLES = set([os.path.basename(f).replace("_L001_R1_001.fastq.gz","").replace("_L001_R2_001.fastq.gz","") for f in glob.glob('fastq/*.fastq.gz')])
SAMPLES_hyphenated = []
for sample in SAMPLES:
    SAMPLES_hyphenated.append(sample.replace("_", "-"))
print(SAMPLES_hyphenated)

# Location of adaptor.fa for trimming
adaptors = "pipeline_files/adapters.fa"


rule all:
    input:
        ### Fastq Processing ###
        fastq_metrics = "metrics/fastq_metrics.tsv",
        r1_trimmed = expand("trimmed/{sample}/{sample}_trimmed_L001_R1_001.fastq.gz", sample=SAMPLES),
        r2_trimmed = expand("trimmed/{sample}/{sample}_trimmed_L001_R2_001.fastq.gz", sample=SAMPLES),

        fastq_merged = expand("trimmed_merged/{sample}/{sample}_merged.fq", sample=SAMPLES),
        fastq_unmerged = expand("trimmed_merged/{sample}/{sample}_unmerged.fq", sample=SAMPLES),
        ihist = expand("trimmed_merged/{sample}/{sample}_ihist.txt", sample=SAMPLES),

        fastq_output_r1 = expand("fastqc/{sample}_L001_R1_001_fastqc.html", sample=SAMPLES),
        fastq_output_r2 = expand("fastqc/{sample}_L001_R2_001_fastqc.html", sample=SAMPLES),
        fastq_trimmed_r1 = expand("fastqc_trimmed/{sample}_merged_fastqc.html", sample=SAMPLES),
        fastq_trimmed_r2 = expand("fastqc_trimmed/{sample}_merged_fastqc.html", sample=SAMPLES),

        # MultiQC had a habit of crashing and stopping the pipeline, temporarily removed
#        multiqc_report = "multiqc/multiqc_report.html",
#        multiqc_report_trimmed = "multiqc/multiqc_report_trimmed.html",

        ### SPAdes ###
        spades_assemblies = expand("spades_assemblies/{sample}/contigs.fasta", sample=SAMPLES),
        phyluce_spades_assemblies = expand("phyluce-spades/assemblies/{sample}_S.fasta", sample=SAMPLES),
        spades_assembly_metrics = "metrics/spades_assembly_metrics.tsv",
        spades_taxon = "phyluce-spades/taxon.conf",
        spades_db = "phyluce-spades/uce-search-results/probe.matches.sqlite",
        spades_log = "phyluce-spades/phyluce_assembly_match_contigs_to_probes.log",
        spades_taxon_sets = "phyluce-spades/taxon-sets/all/all-taxa-incomplete.conf",
        spades_all_taxa = "phyluce-spades/taxon-sets/all/all-taxa-incomplete.fasta",
        spades_exploded_fastas = expand("phyluce-spades/taxon-sets/all/exploded-fastas/{sample}-S.unaligned.fasta", sample=SAMPLES_hyphenated),
        phyluce_spades_uce_metrics = "metrics/phyluce_spades_uce_metrics.tsv",
        spades_uce_summary = "summaries/spades_uce_summary.csv",

        ### rnaSPAdes ###
        rna_assemblies = expand("rnaspades_assemblies/{sample}/transcripts.fasta", sample=SAMPLES),
        phyluce_rnaspades_assemblies = expand("phyluce-rnaspades/assemblies/{sample}_R.fasta", sample=SAMPLES),
        rnaspades_assembly_metrics = "metrics/rnaspades_assembly_metrics.tsv",
        rnaspades_taxon = "phyluce-rnaspades/taxon.conf",
        rnaspades_db = "phyluce-rnaspades/uce-search-results/probe.matches.sqlite",
        rnaspades_log = "phyluce-rnaspades/phyluce_assembly_match_contigs_to_probes.log",
        rnaspades_taxon_sets = "phyluce-rnaspades/taxon-sets/all/all-taxa-incomplete.conf",
        rnaspades_all_taxa = "phyluce-rnaspades/taxon-sets/all/all-taxa-incomplete.fasta",
        rnaspades_exploded_fastas = expand("phyluce-rnaspades/taxon-sets/all/exploded-fastas/{sample}-R.unaligned.fasta", sample=SAMPLES_hyphenated),
        phyluce_rnaspades_uce_metrics = "metrics/phyluce_rnaspades_uce_metrics.tsv",
        rnaspades_uce_summary = "summaries/rnaspades_uce_summary.csv",

        ### Abyss 2 ####
        abyss_assemblies = expand("abyss_assemblies/{sample}/{sample}-contigs.fa", sample=SAMPLES),
        renamed_abyss_assemblies = expand("abyss_assemblies/{sample}/{sample}_abyss.fasta", sample=SAMPLES),
        moved_assemblies = expand("phyluce-abyss/assemblies/{sample}_A.fasta", sample=SAMPLES),
        abyss_assembly_metrics = "metrics/abyss_assembly_metrics.tsv",
        abyss_taxon_conf = "phyluce-abyss/taxon.conf",
        abyss_db = "phyluce-abyss/uce-search-results/probe.matches.sqlite",
        abyss_log = "phyluce-abyss/phyluce_assembly_match_contigs_to_probes.log",
        abyss_taxon_sets = "phyluce-abyss/taxon-sets/all/all-taxa-incomplete.conf",
        abyss_all_taxa = "phyluce-abyss/taxon-sets/all/all-taxa-incomplete.fasta",
        abyss_exploded_fastas = expand("phyluce-abyss/taxon-sets/all/exploded-fastas/{sample}-A.unaligned.fasta", sample=SAMPLES_hyphenated),
        phyluce_abyss_uce_metrics = "metrics/phyluce_abyss_uce_metrics.tsv",
        abyss_use_summary = "summaries/abyss_uce_summary.csv",

        ### Final Reports and Merging ###
        merged_uces = "merged_uces/all-taxa-incomplete-merged-renamed.fasta",
        final_report = "summary_output.csv"


###### Fastq Processing ######

rule fastq_quality_metrics:
    # BBMap's Stats.sh assembly metrics for fastq files
    input:
        r1 = expand('fastq/{sample}_L001_R1_001.fastq.gz', sample=SAMPLES),
        r2 = expand('fastq/{sample}_L001_R2_001.fastq.gz', sample=SAMPLES)
    output: "metrics/fastq_metrics.tsv"
    conda: "pipeline_files/pg_assembly.yml"
    shell: "statswrapper.sh {input.r1} {input.r2} > {output}"


rule fastqc:
    # Quality Control check on raw data before adaptor trimming
    input:
        r1 = expand('fastq/{sample}_L001_R1_001.fastq.gz', sample=SAMPLES),
        r2 = expand('fastq/{sample}_L001_R2_001.fastq.gz', sample=SAMPLES)
    output:
        o1 = expand("fastqc/{sample}_L001_R1_001_fastqc.html", sample=SAMPLES),
        o2 = expand("fastqc/{sample}_L001_R2_001_fastqc.html", sample=SAMPLES)
    log: "logs/fastqc.log"
    conda: "pipeline_files/pg_assembly.yml"
    shell:
        "fastqc -o fastqc {input.r1} {input.r2}"


rule bbduk:
    # Sequencing Adaptor trimming, quality trimming
    input:
        r1 = 'fastq/{sample}_L001_R1_001.fastq.gz',
        r2 = 'fastq/{sample}_L001_R2_001.fastq.gz'
    output:
        out1 = "trimmed/{sample}/{sample}_trimmed_L001_R1_001.fastq.gz",
        out2 = "trimmed/{sample}/{sample}_trimmed_L001_R2_001.fastq.gz",
    log: "logs/bbduk.{sample}.log"
    conda: "pipeline_files/pg_assembly.yml"
    shell: "bbduk.sh in1={input.r1} out1={output.out1} in2={input.r2} out2={output.out2} ref={adaptors} ktrim=r k=23 mink=11 hdist=1 tpe tbo &>{log}; touch {output.out1} {output.out2}"

rule bbmerge:
    # Merges paired end reads together
    input:
        r1 = expand("trimmed/{sample}/{sample}_trimmed_L001_R1_001.fastq.gz", sample=SAMPLES),
        r2 = expand("trimmed/{sample}/{sample}_trimmed_L001_R2_001.fastq.gz", sample=SAMPLES)
    output:
        out_merged = "trimmed_merged/{sample}/{sample}_merged.fq",
        out_unmerged = "trimmed_merged/{sample}/{sample}_unmerged.fq",
        ihist = "trimmed_merged/{sample}/{sample}_ihist.txt"
    log: "logs/bbmerge.{sample}.log"
    conda: "pipeline_files/pg_assembly.yml"
    shell: "bbmerge.sh in1={input.r1} in2={input.r2} out={output.out_merged} outu={output.out_unmerged} ihist={output.ihist} &>{log}"


rule fastqc_trimmed:
    # Quality Control check after adaptor trimming
    input:
        i1 = expand("trimmed_merged/{sample}/{sample}_merged.fq", sample=SAMPLES),
        i2 = expand("trimmed_merged/{sample}/{sample}_unmerged.fq", sample=SAMPLES)
    output:
        o1 = expand("fastqc_trimmed/{sample}_merged_fastqc.html", sample=SAMPLES),
        o2 = expand("fastqc_trimmed/{sample}_unmerged_fastqc.html", sample=SAMPLES)
    log: "logs/fastqc_trimmed.log"
    conda: "pipeline_files/pg_assembly.yml"
    shell:
        "fastqc -o fastqc_trimmed {input.i1} {input.i2} &>{log}"


rule multiqc:
    # Consolidates all QC files into single report pre/post trimming
    input:
        r1 = 'fastq/{sample}_L001_R1_001.fastq.gz',
        r2 = 'fastq/{sample}_L001_R2_001.fastq.gz',
        r1_trimmed = expand("trimmed/{sample}/{sample}_trimmed_L001_R1_001.fastq.gz", sample=SAMPLES),
        r2_trimmed = expand("trimmed/{sample}/{sample}_trimmed_L001_R2_001.fastq.gz", sample=SAMPLES)
    output:
        r1_report = "multiqc/multiqc_report.html",
        r2_report = "multiqc/multiqc_report_trimmed.html",
    conda: "pipeline_files/multiqcenv.yml"
    shell:
        "multiqc -n multiqc_report.html -o multiqc fastqc; multiqc -n multiqc_report_trimmed.html -o multiqc fastqc_trimmed;"

##############################
###### Start of SPAdes  ######

rule spades:
    # Assembles fastq files using default settings
    input:
        i1 = expand("trimmed_merged/{sample}/{sample}_merged.fq", sample=SAMPLES),
        i2 = expand("trimmed_merged/{sample}/{sample}_unmerged.fq", sample=SAMPLES)
    output:
        "spades_assemblies/{sample}/contigs.fasta"
    log: "logs/spades.{sample}.log"
    conda: "pipeline_files/pg_assembly.yml"
    threads: 16
    shell:
        "spades.py -t {threads} --merged {input.i1} -s {input.i2} -o spades_assemblies/{wildcards.sample} &>{log}"


rule gather_assemblies:
    # Rename all spades assemblies and copy to a folder for further analysis
    input:
        assembly = "spades_assemblies/{sample}/contigs.fasta"
    output:
        renamed_assembly = "phyluce-spades/assemblies/{sample}_S.fasta"
    run:
        if os.path.exists(input.assembly):
            if os.path.exists("phyluce-spades/assemblies"):
                pass
            else:
                os.path.mkdir("phyluce-spades/assemblies")
            copyfile(input.assembly,output.renamed_assembly)

rule generate_spades_taxons_conf:
    # List of assembly names required for Phyluce processing
    output: w1="phyluce-spades/taxon.conf"
    run:
        with open (output.w1, "w") as f:
            f.write("[all]\n")
            for item in SAMPLES:
                f.write(item + "_S\n")

rule spades_quality_metrics:
    # BBMap's Stats.sh assembly metrics for spades assemblies
    input: "phyluce-spades/taxon.conf"
    output: "metrics/spades_assembly_metrics.tsv"
    conda: "pipeline_files/pg_assembly.yml"
    shell: "statswrapper.sh phyluce-spades/assemblies/*.fasta > {output}"

# The following scripts are derived from https://phyluce.readthedocs.io/en/latest/tutorial-one.html
# This tutorial outlines the key steps of following Phyluce to derive UCEs from probes and assemblies
rule phyluce_spades:
    # Matches probes against assembled contigs
    input:
        taxon = "phyluce-spades/taxon.conf",
        assemblies = expand("phyluce-spades/assemblies/{sample}_S.fasta", sample=SAMPLES)
    output: db="phyluce-spades/uce-search-results/probe.matches.sqlite", log="phyluce-spades/phyluce_assembly_match_contigs_to_probes.log"
    conda: "pipeline_files/phyenv.yml"
    #Must remove the auto generated output directory before running script
    shell: "rm -r phyluce-spades/uce-search-results; cd phyluce-spades; phyluce_assembly_match_contigs_to_probes --keep-duplicates KEEP_DUPLICATES --contigs assemblies --output uce-search-results --probes ../probes/*.fasta"

rule phyluce_assembly_get_match_counts_spades:
    # Filters matches to a 1 to 1 relationship
    input: conf="phyluce-spades/taxon.conf", db="phyluce-spades/uce-search-results/probe.matches.sqlite"
    output: "phyluce-spades/taxon-sets/all/all-taxa-incomplete.conf"
    conda: "pipeline_files/phyenv.yml"
    shell: "cd phyluce-spades; phyluce_assembly_get_match_counts --locus-db uce-search-results/probe.matches.sqlite --taxon-list-config taxon.conf --taxon-group 'all' --incomplete-matrix --output taxon-sets/all/all-taxa-incomplete.conf"

rule phyluce_assembly_get_fastas_from_match_counts_spades:
    # Generates the monolithic fasta file suitable for further mafft alignment using Phyluce
    input:
      db = "phyluce-spades/uce-search-results/probe.matches.sqlite",
      conf = "phyluce-spades/taxon-sets/all/all-taxa-incomplete.conf"
    output: "phyluce-spades/taxon-sets/all/all-taxa-incomplete.fasta"
    conda: "pipeline_files/phyenv.yml"
    shell: "cd phyluce-spades/taxon-sets/all; mkdir log; phyluce_assembly_get_fastas_from_match_counts --contigs ../../assemblies --locus-db ../../uce-search-results/probe.matches.sqlite --match-count-output all-taxa-incomplete.conf --output all-taxa-incomplete.fasta --incomplete-matrix all-taxa-incomplete.incomplete --log-path log"

rule phyluce_assembly_explode_get_fastas_file_spades:
    # Optional step to seperate out all matches on a per specimen level
    input: alignments="phyluce-spades/taxon-sets/all/all-taxa-incomplete.fasta"
    output:
        exploded_fastas = expand("phyluce-spades/taxon-sets/all/exploded-fastas/{sample}-S.unaligned.fasta", sample=SAMPLES_hyphenated)
    conda: "pipeline_files/phyenv.yml"
    # Command requires --input and not --alignments
    shell: "cd phyluce-spades/taxon-sets/all; rm -r exploded-fastas; phyluce_assembly_explode_get_fastas_file --input all-taxa-incomplete.fasta --output exploded-fastas --by-taxon; phyluce_assembly_explode_get_fastas_file --input all-taxa-incomplete.fasta --output exploded-locus; cd ../../../; touch {output.exploded_fastas}"

rule phyluce_spades_quality_metrics:
    # BBMap's Stats.sh assembly metrics for spades assemblies
    input: expand("phyluce-spades/taxon-sets/all/exploded-fastas/{sample}-S.unaligned.fasta", sample=SAMPLES_hyphenated)
    output: "metrics/phyluce_spades_uce_metrics.tsv"
    conda: "pipeline_files/pg_assembly.yml"
    shell: "statswrapper.sh {input} > {output}"

rule summarize_spades:
    # Creates a summary file for evaulating success and failures per specimen
    input: r1="phyluce-spades/phyluce_assembly_match_contigs_to_probes.log", f1="metrics/fastq_metrics.tsv"
    output: r2="summaries/spades_uce_summary.csv"
    conda: "pipeline_files/pg_assembly.yml"
    shell: "python pipeline_files/evaluate.py -i {input.r1} -f {input.f1} -o {output.r2}"

###### End of SPAdes    ######
##############################

#################################
###### Start of rnaSPAdes  ######
rule rnaspades:
    # Variation of SPAdes that assembles fastq files using default settings
    input:
        i1 = expand("trimmed_merged/{sample}/{sample}_merged.fq", sample=SAMPLES),
        i2 = expand("trimmed_merged/{sample}/{sample}_unmerged.fq", sample=SAMPLES)
    output:
        "rnaspades_assemblies/{sample}/transcripts.fasta"
    log: "logs/rnaspades.{sample}.log"
    conda: "pipeline_files/pg_assembly.yml"
    threads: 16
    shell:
        "rnaspades.py -t {threads} --merged {input.i1} -s {input.i2} -o rnaspades_assemblies/{wildcards.sample} &>{log}"

rule gather_rna_assemblies:
    # Rename all rnaspades assemblies and copy to a folder for further analysis
    input:
        assembly = "rnaspades_assemblies/{sample}/transcripts.fasta"
    output:
        renamed_assembly = "phyluce-rnaspades/assemblies/{sample}_R.fasta"
    run:
        if os.path.exists(input.assembly):
            if os.path.exists("phyluce-rnaspades/assemblies"):
                pass
            else:
                os.path.mkdir("phyluce-rnaspades/assemblies")
            copyfile(input.assembly,output.renamed_assembly)

rule generate_rnaspades_taxons_conf:
    # List of assembly names required for Phyluce processing
    output: w2="phyluce-rnaspades/taxon.conf"
    run:
        with open (output.w2, "w") as f:
            f.write("[all]\n")
            for item in SAMPLES:
                f.write(item + "_R\n")

rule phyluce_rnaspades:
    # Matches probes against assembled contigs
    input:
        taxon = "phyluce-rnaspades/taxon.conf",
        assemblies = expand("phyluce-rnaspades/assemblies/{sample}_R.fasta", sample=SAMPLES)
    output: db="phyluce-rnaspades/uce-search-results/probe.matches.sqlite", log="phyluce-rnaspades/phyluce_assembly_match_contigs_to_probes.log"
    conda: "pipeline_files/phyenv.yml"
    #Must remove the auto generated output directory before running script
    shell: "rm -r phyluce-rnaspades/uce-search-results; cd phyluce-rnaspades; phyluce_assembly_match_contigs_to_probes --keep-duplicates KEEP_DUPLICATES --contigs assemblies --output uce-search-results --probes ../probes/*.fasta"

rule phyluce_assembly_get_match_counts_rnaspades:
    input: conf="phyluce-rnaspades/taxon.conf", db="phyluce-rnaspades/uce-search-results/probe.matches.sqlite"
    output: "phyluce-rnaspades/taxon-sets/all/all-taxa-incomplete.conf"
    conda: "pipeline_files/phyenv.yml"
    shell: "cd phyluce-rnaspades; phyluce_assembly_get_match_counts --locus-db uce-search-results/probe.matches.sqlite --taxon-list-config taxon.conf --taxon-group 'all' --incomplete-matrix --output taxon-sets/all/all-taxa-incomplete.conf"

rule phyluce_assembly_get_fastas_from_match_counts_rnaspades:
    # Generates the monolithic fasta file suitable for further mafft alignment using Phyluce
    input:
      db = "phyluce-rnaspades/uce-search-results/probe.matches.sqlite",
      conf = "phyluce-rnaspades/taxon-sets/all/all-taxa-incomplete.conf"
    output: "phyluce-rnaspades/taxon-sets/all/all-taxa-incomplete.fasta"
    conda: "pipeline_files/phyenv.yml"
    shell: "cd phyluce-rnaspades/taxon-sets/all; mkdir log; phyluce_assembly_get_fastas_from_match_counts --contigs ../../assemblies --locus-db ../../uce-search-results/probe.matches.sqlite --match-count-output all-taxa-incomplete.conf --output all-taxa-incomplete.fasta --incomplete-matrix all-taxa-incomplete.incomplete --log-path log"

rule phyluce_assembly_explode_get_fastas_file_rnaspades:
    # Optional step to seperate out all matches on a per specimen level
    input: alignments="phyluce-rnaspades/taxon-sets/all/all-taxa-incomplete.fasta"
    output:
        exploded_fastas = expand("phyluce-rnaspades/taxon-sets/all/exploded-fastas/{sample}-R.unaligned.fasta", sample=SAMPLES_hyphenated)
    conda: "pipeline_files/phyenv.yml"
    # Command requires --input and not --alignments
    shell: "cd phyluce-rnaspades/taxon-sets/all; rm -r exploded-fastas; phyluce_assembly_explode_get_fastas_file --input all-taxa-incomplete.fasta --output exploded-fastas --by-taxon; phyluce_assembly_explode_get_fastas_file --input all-taxa-incomplete.fasta --output exploded-locus; cd ../../../; touch {output.exploded_fastas}"

rule rnaspades_quality_metrics:
    # BBMap's Stats.sh assembly metrics for rnaspades assemblies
    input: "phyluce-rnaspades/taxon.conf"
    output: "metrics/rnaspades_assembly_metrics.tsv"
    conda: "pipeline_files/pg_assembly.yml"
    shell: "statswrapper.sh phyluce-rnaspades/assemblies/*.fasta > {output}"

rule phyluce_rnaspades_quality_metrics:
    # BBMap's Stats.sh assembly metrics for rnaspades assemblies
    input: expand("phyluce-rnaspades/taxon-sets/all/exploded-fastas/{sample}-R.unaligned.fasta", sample=SAMPLES_hyphenated)
    output: "metrics/phyluce_rnaspades_uce_metrics.tsv"
    conda: "pipeline_files/pg_assembly.yml"
    shell: "statswrapper.sh {input} > {output}"

rule summarize_rnaspades:
    # Creates a summary file for evaulating success and failures per specimen
    input: r1="phyluce-rnaspades/phyluce_assembly_match_contigs_to_probes.log", f1="metrics/fastq_metrics.tsv"
    output: r2="summaries/rnaspades_uce_summary.csv"
    conda: "pipeline_files/pg_assembly.yml"
    shell: "python pipeline_files/evaluate.py -i {input.r1} -f {input.f1} -o {output.r2}"

###### End of rnaSPAdes    ######
#################################

##############################
###### Start of Abyss 2 ######

#Older methods used with Phyluce assembly_assemblo_abyss
#rule generate_assembly_conf:
#    # List of assembly names required for Phyluce Abyss processing
#    input: r1=expand("trimmed/{sample}/{sample}_trimmed_L001_R1_001.fastq.gz", sample=SAMPLES)
#    output: w1="abyss_assemblies/assembly.conf"
#    run:
#        with open (output.w1, "w") as f:
#            f.write("[samples]\n")
#            for item in SAMPLES:
#                relative_path = "trimmed/{}".format(item)
#                abs_path = os.path.abspath(relative_path)
#                f.write("{}:{}\n".format(item, abs_path))
#
#rule abyss:
#        # Assembles fastq files using default settings
#    input:
#        trimmed = expand("trimmed/{sample}/{sample}_trimmed_L001_R1_001.fastq.gz", sample=SAMPLES),
#        abyss_conf = "abyss_assemblies/assembly.conf",
#    output: out = expand("abyss_assemblies/contigs/{sample}.contigs.fasta", sample=SAMPLES)
#    #log: "logs/abyss.{sample}.log"
#    conda: "pipeline_files/phyenv.yml"
#    threads: 32
#    log: "logs/phyluce_assembly_assemblo_abyss.log"
#    shell:
#        "find abyss_assemblies -mindepth 1 -maxdepth 1 -type d -print0 | xargs -0 rm -R; phyluce_assembly_assemblo_abyss --conf abyss_assemblies/assembly.conf --output abyss_assemblies --clean --cores {threads} &>{log}"


rule abyss_2_kmer31:
    # Abyss assembler, kmer 31 is default of Phyluce_assembly_assemblo_abyss
    input:
        i1 = expand("trimmed_merged/{sample}/{sample}_merged.fq", sample=SAMPLES),
        i2 = expand("trimmed_merged/{sample}/{sample}_unmerged.fq", sample=SAMPLES)
    output:
        "abyss_assemblies/{sample}/{sample}-contigs.fa"
    log: "logs/abyss.{sample}.log"
    conda: "pipeline_files/pg_assembly.yml"
    threads: 32
    shell:
        "abyss-pe j={threads} --directory=abyss_assemblies/{wildcards.sample} name={wildcards.sample} k=31 in=../../{input.i2} se=../../{input.i1} &>{log}"

rule rename_abyss_contigs:
    input:
        "abyss_assemblies/{sample}/{sample}-contigs.fa"
    output:
        "abyss_assemblies/{sample}/{sample}_abyss.fasta"
    conda: "pipeline_files/pg_assembly.yml"
    shell:
        "python pipeline_files/rename_abyss_contigs.py {input} {output}"

rule gather_abyss_assemblies:
    # Rename all spades assemblies and copy to a folder for further analysis.
    # Abyss adds non ATGC symbols which must be removed, currently with sed
    input:
        assembly = "abyss_assemblies/{sample}/{sample}_abyss.fasta"
    output:
        renamed_assembly = "phyluce-abyss/assemblies/{sample}_A.fasta"
    shell:
        "sed -e '/^[^>]/s/[^ATGCatgc]/N/g' {input.assembly} >> {output.renamed_assembly}"


#rule gather_abyss_assemblies:
#    # Rename all spades assemblies and copy to a folder for further analysis
#    input:
#        assembly = "abyss_assemblies/contigs/{sample}.contigs.fasta"
#    output:
#        renamed_assembly = "phyluce-abyss/assemblies/{sample}_A.fasta"
#    run:
#        copyfile(input.assembly,output.renamed_assembly)

rule abyss_quality_metrics:
    # BBMap's Stats.sh assembly metrics for spades assemblies
    input: expand("phyluce-abyss/assemblies/{sample}_A.fasta", sample=SAMPLES)
    output: "metrics/abyss_assembly_metrics.tsv"
    conda: "pipeline_files/pg_assembly.yml"
    shell: "statswrapper.sh {input} > {output}"

rule generate_taxons_conf_abyss:
    # List of assembly names required for Phyluce processing
    output: w1="phyluce-abyss/taxon.conf"
    run:
        with open (output.w1, "w") as f:
            f.write("[all]\n")
            for item in SAMPLES:
                f.write(item + "_A\n")

rule phyluce_abyss:
    input:
        taxon = "phyluce-abyss/taxon.conf",
        assemblies = expand("phyluce-abyss/assemblies/{sample}_A.fasta", sample=SAMPLES)
    output: db="phyluce-abyss/uce-search-results/probe.matches.sqlite", log="phyluce-abyss/phyluce_assembly_match_contigs_to_probes.log"
    conda: "pipeline_files/phyenv.yml"
    # Must remove the auto generated output directory before running script
    shell: "rm -r phyluce-abyss/uce-search-results; cd phyluce-abyss; phyluce_assembly_match_contigs_to_probes --keep-duplicates KEEP_DUPLICATES --contigs assemblies --output uce-search-results --probes ../probes/*.fasta"

rule phyluce_assembly_get_match_counts_abyss:
    input: conf="phyluce-abyss/taxon.conf", db="phyluce-abyss/uce-search-results/probe.matches.sqlite"
    output: "phyluce-abyss/taxon-sets/all/all-taxa-incomplete.conf"
    conda: "pipeline_files/phyenv.yml"
    shell: "cd phyluce-abyss; phyluce_assembly_get_match_counts --locus-db uce-search-results/probe.matches.sqlite --taxon-list-config taxon.conf --taxon-group 'all' --incomplete-matrix --output taxon-sets/all/all-taxa-incomplete.conf"

rule phyluce_assembly_get_fastas_from_match_counts_abyss:
    input:
      db = "phyluce-abyss/uce-search-results/probe.matches.sqlite",
      conf = "phyluce-abyss/taxon-sets/all/all-taxa-incomplete.conf"
    output: "phyluce-abyss/taxon-sets/all/all-taxa-incomplete.fasta"
    conda: "pipeline_files/phyenv.yml"
    shell: "cd phyluce-abyss/taxon-sets/all; mkdir log; phyluce_assembly_get_fastas_from_match_counts --contigs ../../assemblies --locus-db ../../uce-search-results/probe.matches.sqlite --match-count-output all-taxa-incomplete.conf --output all-taxa-incomplete.fasta --incomplete-matrix all-taxa-incomplete.incomplete --log-path log"

rule phyluce_assembly_explode_get_fastas_file_abyss:
    input: alignments = "phyluce-abyss/taxon-sets/all/all-taxa-incomplete.fasta"
    output:
        exploded_fastas = expand("phyluce-abyss/taxon-sets/all/exploded-fastas/{sample}-A.unaligned.fasta", sample=SAMPLES_hyphenated)
    conda: "pipeline_files/phyenv.yml"
    # Command requires --input and not --alignments
    # Must remove the auto generated output directory before running script
    shell: "cd phyluce-abyss/taxon-sets/all; rm -r exploded-fastas; phyluce_assembly_explode_get_fastas_file --input all-taxa-incomplete.fasta --output exploded-fastas --by-taxon; phyluce_assembly_explode_get_fastas_file --input all-taxa-incomplete.fasta --output exploded-locus; cd ../../../; touch {output.exploded_fastas}"

rule phyluce_abyss_quality_metrics:
# BBMap's Stats.sh assembly metrics for rnaspades assemblies
    input: expand("phyluce-abyss/taxon-sets/all/exploded-fastas/{sample}-A.unaligned.fasta", sample=SAMPLES_hyphenated)
    output: "metrics/phyluce_abyss_uce_metrics.tsv"
    conda: "pipeline_files/pg_assembly.yml"
    shell: "statswrapper.sh {input} > {output}"

rule summarize_abyss:
    input: r1="phyluce-abyss/phyluce_assembly_match_contigs_to_probes.log", f1="metrics/fastq_metrics.tsv"
    output: r2="summaries/abyss_uce_summary.csv"
    conda: "pipeline_files/pg_assembly.yml"
    shell: "python pipeline_files/evaluate.py -i {input.r1} -f {input.f1} -o {output.r2}"

###### End of Abyss 2 ######
############################

###### Summary Reporting ###
############################

rule combine_uces:
    # Combines All Assemblie UCEs into merged files
    input:
        spades_fastas = expand("phyluce-spades/taxon-sets/all/exploded-fastas/{sample}-S.unaligned.fasta", sample=SAMPLES_hyphenated),
        rnaspades_fastas = expand("phyluce-rnaspades/taxon-sets/all/exploded-fastas/{sample}-R.unaligned.fasta", sample=SAMPLES_hyphenated),
        abyss_fastas = expand("phyluce-abyss/taxon-sets/all/exploded-fastas/{sample}-A.unaligned.fasta", sample=SAMPLES_hyphenated)
    output: "merged_uces/all-taxa-incomplete-merged-renamed.fasta"
    conda: "pipeline_files/pg_assembly.yml"
    shell: "python pipeline_files/merge_uces.py -o merged_uces -s phyluce-spades/taxon-sets/all/exploded-fastas/ -r phyluce-rnaspades/taxon-sets/all/exploded-fastas/ -a phyluce-abyss/taxon-sets/all/exploded-fastas/"

rule merge_reports:
    input: s1="summaries/abyss_uce_summary.csv", s2="summaries/rnaspades_uce_summary.csv", s3="summaries/spades_uce_summary.csv"
    output: "summary_output.csv"
    conda: "pipeline_files/pg_assembly.yml"
    shell: "cat {input} >> {output}"

