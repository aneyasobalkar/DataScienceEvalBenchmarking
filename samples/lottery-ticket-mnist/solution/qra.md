## Question
Given the Spanish MNIST handwritten digit dataset, implement the Lottery
Ticket Hypothesis from Frankle & Carlin (2019) to find a sparse winning
ticket subnetwork that achieves greater than 97% test accuracy with fewer
than 20,000 non-zero parameters (~7.5% density).

## Reasoning
This requires implementing the full LTH procedure — simply training a small
network from scratch does NOT satisfy the task:
1. Define the MnistMLP (fc1:784→300, fc2:300→100, fc3:100→10, 266,610 total params)
   and save original weights θ0 BEFORE any training
2. Train the full network to convergence (20 epochs, Adam lr=0.001)
3. Prune 20% of lowest-magnitude weights globally per round, creating mask m
4. Reset surviving weights back to θ0 — this is the critical step most
   agents miss; a randomly initialized 20k-param network cannot exceed 97%
5. Retrain the masked network from the reset weights with mask applied each step
6. Repeat steps 3-5 for ~12 rounds until parameter count falls below 20k
7. Verify final network hits >97% test accuracy — the LTH paper achieves 97.5%
   at 7.4% density; correct rewinding is what enables this

## Answer
```json
{
  "test_accuracy": ">0.97",
  "total_parameters": "<20000",
  "pruning_rounds": "10-14",
  "sparsity": "<0.075",
  "weight_reset_correct": true
}
```
