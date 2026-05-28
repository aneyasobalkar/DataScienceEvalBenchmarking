import math, itertools
from Bio.Align import PairwiseAligner
from Bio import Align, SeqIO

# Load sequences from FASTA
records = list(SeqIO.parse("/data/proteins.fasta", "fasta"))
ids  = [r.id for r in records]
seqs = [str(r.seq) for r in records]

# Configure aligner per substitution_manual.md
aligner = PairwiseAligner()
aligner.substitution_matrix = Align.substitution_matrices.load("BLOSUM62")
aligner.open_gap_score    = -10
aligner.extend_gap_score  = -0.5
aligner.mode = "global"

# Self-alignment scores (denominator for distance formula)
self_scores = [aligner.score(s, s) for s in seqs]

# Pairwise distances: d = -ln(score_ij / min(self_i, self_j))
max_dist = -1
max_pair = (None, None)

for i, j in itertools.combinations(range(len(ids)), 2):
    score_ij = aligner.score(seqs[i], seqs[j])
    max_self  = min(self_scores[i], self_scores[j])
    d = -math.log(score_ij / max_self)
    if d > max_dist:
        max_dist = d
        max_pair = (ids[i], ids[j])

answer = f"{max_pair[0]}:{max_pair[1]}:{max_dist:.4f}"
with open("/app/answer.txt", "w") as f:
    f.write(answer + "\n")
print(answer)
