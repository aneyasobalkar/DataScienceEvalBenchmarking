## Question
Given a multi-source Bengali fake news dataset with articles labeled as real
or fake from multiple news outlets, build a lightweight text classification
pipeline to distinguish real from fake news. Evaluate appropriately for this
problem type.

## Reasoning
This is a multilingual NLP classification problem with several non-obvious
challenges:
1. Bengali text requires Unicode normalization — same characters can have
   multiple representations
2. Standard English tokenizers will fail on Bengali script — need
   Bengali-aware tokenization
3. Class imbalance is likely — real news typically outnumbers fake news
4. Must use macro F1 as the evaluation metric, not accuracy — accuracy is
   misleading with imbalance
5. TF-IDF vectorization with Bengali stopword removal is appropriate for
   a lightweight approach
6. Logistic regression with class_weight='balanced' handles imbalance
   correctly
7. Per-source evaluation is essential — a model that only works on one
   source is not generalizable

## Answer
```json
{
  "macro_f1": ">0.82",
  "per_class_f1": {"real": ">0.80", "fake": ">0.78"},
  "per_source_f1": {"<all sources present>": ">0.70 each"},
  "class_imbalance_handled": true,
  "bengali_preprocessing": true
}
```
