# Bengali Fake News Detection

You are a data scientist building a text classification pipeline to detect fake news in Bengali.

## Dataset

The dataset is a multi-source Bengali fake news benchmark. Data files are at:

- `/data/train.csv` — training set
- `/data/val.csv` — validation set
- `/data/test.csv` — held-out test set

Each file has these columns:

- `text` — the Bengali news article
- `label` — 0 = real news, 1 = fake news
- `source` — which dataset this article came from
- `word_count`, `char_count`, `bengali_ratio` — pre-computed statistics

## Your Task

1. **Explore the data** — understand the class distribution, source breakdown, and text characteristics. Save all visualizations to `/output/plots/`.

2. **Build a classification pipeline** — process the Bengali text and train a classifier to distinguish real from fake news. Use the training set to train and the test set for final evaluation.

3. **Evaluate properly** — choose metrics appropriate for this problem and report both overall and per-class performance, as well as per-source performance.

4. **Write results** to `/output/results.json` in exactly this format:
```json
{
  "macro_f1": <float, 4 decimal places>,
  "per_class_f1": {"0": <float>, "1": <float>},
  "per_source_f1": {"<source_name>": <float>, ...},
  "model": "<description of classifier used>",
  "vectorizer": "<description of text representation used>"
}
```

## Constraints

- **Lightweight only** — no transformers, no deep learning, no neural networks
- All plots must be saved to `/output/plots/` before writing `results.json`
