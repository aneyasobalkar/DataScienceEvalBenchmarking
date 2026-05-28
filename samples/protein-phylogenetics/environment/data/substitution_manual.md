# Protein Substitution Matrices and Evolutionary Distance Methods

## 1. Why Amino Acid Distances Require Specialised Matrices

Protein sequences cannot be compared using character-level edit distance or Hamming
distance. Unlike DNA, where all four bases are roughly equivalent, the twenty standard
amino acids differ enormously in their biochemical properties — charge, polarity,
size, aromaticity. Evolutionary substitutions are highly non-uniform: a mutation
that replaces valine with isoleucine (both non-polar, similar size) is far more
common and far less disruptive than one that replaces valine with aspartate (polar,
charged). A distance metric that treats both substitutions identically produces
biologically meaningless results.

A principled solution is to use an empirical substitution matrix, derived from
large collections of aligned protein sequences, that encodes the relative frequency
of observed substitutions across evolution. The most widely used such matrix is
BLOSUM62.

---

## 2. BLOSUM62 — Derivation and Interpretation

BLOSUM62 (BLOcks SUbstitution Matrix, 62% identity) was derived by Henikoff and
Henikoff (1992) from ungapped local alignments of conserved protein regions (blocks)
in the BLOCKS database. Only sequence pairs sharing at most 62% sequence identity
were used, ensuring that the matrix reflects divergent rather than redundant evolution.

Each entry M[a][b] in the matrix represents the log-odds score of observing amino
acid `a` aligned to amino acid `b` in a homologous protein pair, versus the
frequency expected by chance under independent amino acid composition. Positive
values indicate that the substitution is observed more frequently than random
(conservative substitution); negative values indicate it is less frequent
(disruptive substitution); diagonal entries (self-substitutions) are always
the most positive, reflecting the near-certainty of identity conservation.

### BLOSUM62 Matrix

|   | A  | R  | N  | D  | C  | Q  | E  | G  | H  | I  | L  | K  | M  | F  | P  | S  | T  | W  | Y  | V  |
|---|----|----|----|----|----|----|----|----|----|----|----|----|----|----|----|----|----|----|----|----|
| A |  4 | -1 | -2 | -2 |  0 | -1 | -1 |  0 | -2 | -1 | -1 | -1 | -1 | -2 | -1 |  1 |  0 | -3 | -2 |  0 |
| R | -1 |  5 |  0 | -2 | -3 |  1 |  0 | -2 |  0 | -3 | -2 |  2 | -1 | -3 | -2 | -1 | -1 | -3 | -2 | -3 |
| N | -2 |  0 |  6 |  1 | -3 |  0 |  0 |  0 |  1 | -3 | -3 |  0 | -2 | -3 | -2 |  1 |  0 | -4 | -2 | -3 |
| D | -2 | -2 |  1 |  6 | -3 |  0 |  2 | -1 | -1 | -3 | -4 | -1 | -3 | -3 | -1 |  0 | -1 | -4 | -3 | -3 |
| C |  0 | -3 | -3 | -3 |  9 | -3 | -4 | -3 | -3 | -1 | -1 | -3 | -1 | -2 | -3 | -1 | -1 | -2 | -2 | -1 |
| Q | -1 |  1 |  0 |  0 | -3 |  5 |  2 | -2 |  0 | -3 | -2 |  1 |  0 | -3 | -1 |  0 | -1 | -2 | -1 | -2 |
| E | -1 |  0 |  0 |  2 | -4 |  2 |  5 | -2 |  0 | -3 | -3 |  1 | -2 | -3 | -1 |  0 | -1 | -3 | -2 | -2 |
| G |  0 | -2 |  0 | -1 | -3 | -2 | -2 |  6 | -2 | -4 | -4 | -2 | -3 | -3 | -2 |  0 | -2 | -2 | -3 | -3 |
| H | -2 |  0 |  1 | -1 | -3 |  0 |  0 | -2 |  8 | -3 | -3 | -1 | -2 | -1 | -2 | -1 | -2 | -2 |  2 | -3 |
| I | -1 | -3 | -3 | -3 | -1 | -3 | -3 | -4 | -3 |  4 |  2 | -3 |  1 |  0 | -3 | -2 | -1 | -3 | -1 |  3 |
| L | -1 | -2 | -3 | -4 | -1 | -2 | -3 | -4 | -3 |  2 |  4 | -2 |  2 |  0 | -3 | -2 | -1 | -2 | -1 |  1 |
| K | -1 |  2 |  0 | -1 | -3 |  1 |  1 | -2 | -1 | -3 | -2 |  5 | -1 | -3 | -1 |  0 | -1 | -3 | -2 | -2 |
| M | -1 | -1 | -2 | -3 | -1 |  0 | -2 | -3 | -2 |  1 |  2 | -1 |  5 |  0 | -2 | -1 | -1 | -1 | -1 |  1 |
| F | -2 | -3 | -3 | -3 | -2 | -3 | -3 | -3 | -1 |  0 |  0 | -3 |  0 |  6 | -4 | -2 | -2 |  1 |  3 | -1 |
| P | -1 | -2 | -2 | -1 | -3 | -1 | -1 | -2 | -2 | -3 | -3 | -1 | -2 | -4 |  7 | -1 | -1 | -4 | -3 | -2 |
| S |  1 | -1 |  1 |  0 | -1 |  0 |  0 |  0 | -1 | -2 | -2 |  0 | -1 | -2 | -1 |  4 |  1 | -3 | -2 | -2 |
| T |  0 | -1 |  0 | -1 | -1 | -1 | -1 | -2 | -2 | -1 | -1 | -1 | -1 | -2 | -1 |  1 |  5 | -2 | -2 |  0 |
| W | -3 | -3 | -4 | -4 | -2 | -2 | -3 | -2 | -2 | -3 | -2 | -3 | -1 |  1 | -4 | -3 | -2 | 11 |  2 | -3 |
| Y | -2 | -2 | -2 | -3 | -2 | -1 | -2 | -3 |  2 | -1 | -1 | -2 | -1 |  3 | -3 | -2 | -2 |  2 |  7 | -1 |
| V |  0 | -3 | -3 | -3 | -1 | -2 | -2 | -3 | -3 |  3 |  1 | -2 |  1 | -1 | -2 | -2 |  0 | -3 | -1 |  4 |

Gap opening penalty: −10. Gap extension penalty: −0.5.

---

## 3. Why Multiple Sequence Alignment Is Required

A common error in phylogenetic analysis is to compute pairwise distances directly
from raw, unaligned sequences — for instance, by scanning both sequences from
position 1 and summing substitution scores. This fails because proteins of similar
function but different origin may differ in length, contain insertions or deletions
(indels), or have different N- and C-terminal regions. Comparing positions that do
not correspond homologously — a gap in one sequence aligned against a residue in
another — is biologically incoherent.

The correct procedure is to first perform pairwise alignment for each pair: finding
the optimal alignment of two sequences that maximises the total substitution score
minus gap penalties, according to the chosen scoring scheme. Global pairwise
alignment (Needleman-Wunsch algorithm with BLOSUM62 and affine gap penalties) is
appropriate when the sequences are expected to be homologous across their full
length. Local alignment (Smith-Waterman) is preferred when only a domain is shared.

For a set of closely related proteins from the same structural family, global
pairwise alignment with BLOSUM62 is the standard approach.

---

## 4. Distance Conversion Formula

A pairwise alignment score S(i, j) computed using BLOSUM62 represents similarity,
not distance. Higher scores mean more similar sequences. To convert to an
evolutionary distance suitable for phylogenetics, normalize and take the
negative logarithm:

    max_score = min(S(i, i), S(j, j))
    d(i, j)   = −ln( S(i, j) / max_score )

where S(i, i) is the self-alignment score of sequence i (aligning the sequence
to itself with the same scoring parameters), and max_score uses the lower of the
two self-scores — that of the shorter or less internally similar sequence.

This formula produces:
- d = 0 when sequences are identical (S(i,j) = max_score)
- d > 0 when sequences differ; larger d means greater evolutionary distance
- d increases without bound as sequences become more divergent

The formula is undefined (or infinite) when S(i, j) ≤ 0, which occurs only for
truly unrelated sequences. For sequences from the same structural family, this
situation should not arise.

---

## 5. Edit Distance Is Not an Evolutionary Distance

Edit distance (Levenshtein distance) counts the minimum number of single-character
insertions, deletions, or substitutions required to transform one sequence into
another. Hamming distance counts positions where two equal-length sequences differ.
Neither is appropriate for protein evolutionary analysis because:

1. They treat all substitutions equally, ignoring the highly non-uniform biochemical
   constraints on amino acid substitutions.
2. They have no principled relationship to the probability of a substitution
   occurring over evolutionary time.
3. They are not calibrated against the empirical substitution rates encoded in
   BLOSUM62.

A phylogenetic analysis based on edit or Hamming distance will produce incorrect
evolutionary rankings — typically failing to identify the most distant pair because
conservative substitutions (which BLOSUM62 scores leniently) are penalised as
harshly as disruptive ones.

---

*End of substitution manual.*
