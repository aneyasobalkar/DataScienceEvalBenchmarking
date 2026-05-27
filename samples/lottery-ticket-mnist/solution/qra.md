## Question
Given the Spanish MNIST handwritten digit dataset, implement the Lottery
Ticket Hypothesis from Frankle & Carlin (2019) to find a sparse winning
ticket subnetwork that achieves greater than 95% test accuracy with fewer
than 50,000 trainable parameters.

## Reasoning
This requires implementing the full LTH procedure — simply training a small
network from scratch does NOT satisfy the task:
1. Define a full dense CNN and save original weights θ0 before any training
2. Train the full network to convergence
3. Prune 20% of lowest-magnitude weights per round, creating mask m
4. Reset surviving weights back to θ0 — this is the critical step most
   agents miss
5. Retrain the masked network from the reset weights
6. Repeat steps 3-5 until parameter count falls below 50k
7. Verify final network hits >95% test accuracy
8. Weight reset to θ0 is what distinguishes a winning ticket from just a
   small network

## Answer
```json
{
  "test_accuracy": ">0.95",
  "total_parameters": "<50000",
  "pruning_rounds": "5-10",
  "sparsity": "<0.15",
  "weight_reset_correct": true
}
```
