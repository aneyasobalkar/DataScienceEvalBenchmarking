# Protein Phylogenetics

You have 20 protein sequences from the same structural classification family in the
PDB database (lysozyme C, derived from UniProt reviewed Swiss-Prot entries).

## Data

All files are at `/data/`:

- `proteins.csv` — 20 protein records with columns: `structureId`, `classification`, `sequence`
- `proteins.fasta` — the same 20 sequences in FASTA format (header: `>structureId`)
- `substitution_manual.md` — substitution matrix and evolutionary distance methods — **READ THIS FIRST**

**Read `substitution_manual.md` before doing any analysis.** It defines the correct
distance metric and explains why simpler approaches fail.

## Task

Identify the **two most evolutionarily distant** proteins in this set.

Use the method described in the substitution manual:
- Pairwise alignment for each pair of sequences
- BLOSUM62 substitution matrix with affine gap penalties (open: −10, extend: −0.5)
- Distance formula from the manual

## Output

Write your answer to `/app/answer.txt` in **exactly** this format:

```
structureId1:structureId2:distance
```

- List the two structureIds in either order (both orderings are accepted)
- Round distance to **4 decimal places**
- Example format (not real values): `P00698:Q9D925:3.1416`
