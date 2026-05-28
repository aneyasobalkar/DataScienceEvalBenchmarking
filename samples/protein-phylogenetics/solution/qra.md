# QRA: Protein Phylogenetics — Most Evolutionarily Distant Lysozyme C Pair

## Question

Given 20 protein sequences from the lysozyme C family (UniProt Swiss-Prot reviewed entries), identify the two most evolutionarily distant proteins using BLOSUM62 pairwise alignment. Report their structureIds and the evolutionary distance rounded to 4 decimal places.

## Protein Family and Dataset

**Family**: Lysozyme C (EC 3.2.1.17) — a hydrolase that cleaves peptidoglycans in bacterial cell walls. Present in secretions of vertebrates and widely studied.

**20 selected UniProt accessions** (filtered: standard amino acids only, length 125–142):
Q1XG90, P00709, O76357, P05105, Q7LZQ1, P48816, P85345, P00708, P29615, P83972, P37159, P37161, P16973, P12067, P22910, P80190, P12066, P00711, D9J142, Q6L6Q6

## Reasoning

### Step 1 — Read substitution_manual.md
The manual defines:
- BLOSUM62 matrix (20×20, log-odds substitution scores)
- Why edit distance and Hamming distance fail for protein evolution
- Why pairwise alignment is required before comparing sequences
- Distance formula: d = −ln(S(i,j) / min(S(i,i), S(j,j)))

### Step 2 — Configure aligner
Use BioPython's `PairwiseAligner` with:
- substitution_matrix = BLOSUM62
- mode = "global" (Needleman-Wunsch)
- open_gap_score = −10
- extend_gap_score = −0.5

### Step 3 — Compute self-alignment scores
For each of the 20 sequences, compute S(i,i) = self-alignment score. These serve as denominators in the distance formula. Self-scores range from ~500 to ~900 depending on sequence length and composition.

### Step 4 — Compute all 190 pairwise distances
For each pair (i,j): d = −ln(aligner.score(seq_i, seq_j) / min(self_i, self_j))

### Step 5 — Find maximum distance pair
Sorted by distance (descending):
| Rank | Pair | Distance |
|---|---|---|
| 1 | O76357 : P22910 | **6.5848** |
| 2 | O76357 : P00711 | 5.7379 |
| 3 | O76357 : P80190 | 5.2040 |
| 4 | O76357 : P85345 | 4.9877 |
| 5 | Q1XG90 : P00709 | 4.9312 |

The gap between 1st and 2nd place is 0.85, making the answer unambiguous.

### Key traps

**Trap 1 — Edit/Hamming distance**: Produces entirely different rankings. Conservative substitutions (e.g. V→I) score 0 penalty in edit distance vs. a lenient BLOSUM62 penalty, while disruptive substitutions (e.g. C→G) score 1 in edit distance vs. a heavy BLOSUM62 penalty. The most distant pair under edit distance is not O76357:P22910.

**Trap 2 — No alignment**: Comparing raw sequence positions (position 1 vs position 1, etc.) ignores insertions and deletions. Sequences of different length cannot be compared without alignment. O76357 is 139 aa and P22910 is 129 aa — direct position comparison is meaningless.

**Trap 3 — Wrong normalization**: Using max(self_i, self_j) instead of min(self_i, self_j) as the denominator produces systematically lower distances and could change the ranking. The manual specifies min (self-score of the shorter/less self-similar sequence).

## Answer

```
O76357:P22910:6.5848
```

Both orderings are accepted: `O76357:P22910:6.5848` and `P22910:O76357:6.5848`.

### Biological interpretation

O76357 is a lysozyme from *Trichosurus vulpecula* (common brushtail possum, a marsupial). P22910 is a lysozyme from *Anas platyrhynchos* (mallard duck, a bird). The large evolutionary distance (~6.58) reflects their substantial divergence across the marsupial–bird lineage split, despite both proteins performing the same enzymatic function and adopting the same fold. Other pairs in the set are predominantly from placental mammals and show much smaller pairwise distances (0.03–2.5).
