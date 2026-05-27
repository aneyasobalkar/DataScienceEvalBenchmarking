# Lottery Ticket Hypothesis on MNIST

You are a machine learning engineer implementing the Lottery Ticket Hypothesis (Frankle & Carlin, NeurIPS 2019).

## Background

The Lottery Ticket Hypothesis states that a randomly initialized dense neural network contains a sparse subnetwork — the "winning ticket" — that, when trained in isolation **from the same initialization**, can match the full network's accuracy.

The winning ticket is discovered via **iterative magnitude pruning with weight rewinding**:

1. Randomly initialize the network; **save a copy of the initial weights as θ₀** (before any training).
2. Train the network to convergence.
3. Globally prune the 20% lowest-magnitude weights (set to exactly 0; do not remove them).
4. **Reset the surviving weights to their values in θ₀** — NOT to random values, NOT to the current round's weights.
5. Repeat from step 2 until the non-zero parameter count drops below 50,000.

## Data

MNIST is pre-downloaded. Load it with:

```python
import torchvision
from torchvision import transforms

transform = transforms.Compose([transforms.ToTensor()])
train_data = torchvision.datasets.MNIST('/data', train=True,  download=False, transform=transform)
test_data  = torchvision.datasets.MNIST('/data', train=False, download=False, transform=transform)
```

## Required Architecture

You **MUST** use exactly this architecture (do not modify the class name, layer sizes, or forward pass):

```python
import torch
import torch.nn as nn

class MnistMLP(nn.Module):
    def __init__(self):
        super().__init__()
        self.fc1 = nn.Linear(784, 300)
        self.fc2 = nn.Linear(300, 100)
        self.fc3 = nn.Linear(100, 10)

    def forward(self, x):
        x = x.view(-1, 784)
        x = torch.relu(self.fc1(x))
        x = torch.relu(self.fc2(x))
        return self.fc3(x)
```

This network has **266,610 total parameters**.

## Training Details

- Loss: `nn.CrossEntropyLoss()`
- Optimizer: `torch.optim.Adam(model.parameters(), lr=0.001)`
- Batch size: 128
- Epochs per round: 20
- **After each optimizer step, re-apply the pruning mask** to prevent pruned weights from recovering:
  ```python
  with torch.no_grad():
      for name, param in model.named_parameters():
          if name in mask:
              param.data *= mask[name]
  ```

## Pruning Algorithm Details

- Pruning is **global** across all weight matrices (fc1.weight, fc2.weight, fc3.weight).
- Do NOT prune biases.
- To compute the threshold for pruning 20% of remaining non-zero weights:
  ```python
  all_weights = torch.cat([model.fc1.weight.data.abs().flatten(),
                           model.fc2.weight.data.abs().flatten(),
                           model.fc3.weight.data.abs().flatten()])
  alive = all_weights[all_weights != 0]
  threshold = torch.quantile(alive, 0.20)
  ```
- Update the mask: any weight with `|w| < threshold` gets masked to 0.
- Reset surviving weights to θ₀ and apply the new mask.

## Stopping Criterion

Stop pruning when:

```
non_zero_params = sum((p != 0).sum().item() for p in model.parameters()) < 50000
```

(This counts all parameters — weights AND biases.)

## Required Output

1. **Save the winning ticket model** (with pruned weights set to exactly 0.0):
   ```python
   torch.save(model.state_dict(), '/output/lottery_ticket.pth')
   ```

2. **Write results** to `/output/results.json`:
   ```json
   {
     "param_count": <int — total non-zero parameters in saved model>,
     "test_accuracy": <float — fraction correct on MNIST test set, e.g. 0.971>,
     "pruning_rounds": <int — number of pruning rounds completed>
   }
   ```

## Success Criteria

Your winning ticket must satisfy **both**:
- `param_count < 50000` (non-zero parameters)
- `test_accuracy > 0.95` (on the 10,000-sample MNIST test set)

## Notes

- The original LTH paper achieves ~98% accuracy at ~21% parameter density on this MLP; your target of >95% at <19% density is achievable.
- Do not use GPU — run on CPU only.

