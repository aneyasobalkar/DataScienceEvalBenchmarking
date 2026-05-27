import json
import torch
import torch.nn as nn
import torchvision
from torchvision import transforms
from torch.utils.data import DataLoader

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


def count_nonzero(model):
    return sum((p != 0).sum().item() for p in model.parameters())


def evaluate(model, loader):
    model.eval()
    correct = 0
    total = 0
    with torch.no_grad():
        for x, y in loader:
            pred = model(x).argmax(dim=1)
            correct += (pred == y).sum().item()
            total += len(y)
    return correct / total


def train_one_round(model, mask, train_loader, epochs=20):
    optimizer = torch.optim.Adam(model.parameters(), lr=0.001)
    criterion = nn.CrossEntropyLoss()
    model.train()
    for epoch in range(epochs):
        for x, y in train_loader:
            optimizer.zero_grad()
            loss = criterion(model(x), y)
            loss.backward()
            optimizer.step()
            # Re-apply mask so pruned weights stay at exactly 0
            with torch.no_grad():
                for name, param in model.named_parameters():
                    if name in mask:
                        param.data *= mask[name]


def compute_new_mask(model, weight_names, prune_fraction=0.20):
    """Global magnitude pruning: prune bottom prune_fraction of alive weights."""
    all_alive = []
    for name, param in model.named_parameters():
        if name in weight_names:
            alive = param.data.abs().flatten()
            all_alive.append(alive[alive != 0])

    all_alive = torch.cat(all_alive)
    threshold = torch.quantile(all_alive, prune_fraction)

    new_mask = {}
    for name, param in model.named_parameters():
        if name in weight_names:
            new_mask[name] = (param.data.abs() >= threshold).float()
    return new_mask


def reset_to_theta0(model, theta_0, mask):
    """Reset all parameters to θ₀ then apply mask to weight layers."""
    model.load_state_dict({k: v.clone() for k, v in theta_0.items()})
    with torch.no_grad():
        for name, param in model.named_parameters():
            if name in mask:
                param.data *= mask[name]


def main():
    torch.manual_seed(42)

    transform = transforms.Compose([transforms.ToTensor()])
    train_dataset = torchvision.datasets.MNIST('/data', train=True,  download=False, transform=transform)
    test_dataset  = torchvision.datasets.MNIST('/data', train=False, download=False, transform=transform)
    train_loader  = DataLoader(train_dataset, batch_size=128, shuffle=True)
    test_loader   = DataLoader(test_dataset,  batch_size=256, shuffle=False)

    model = MnistMLP()
    weight_names = [n for n, _ in model.named_parameters() if 'weight' in n]

    # Save initial weights θ₀ BEFORE any training
    theta_0 = {k: v.clone() for k, v in model.state_dict().items()}

    # Initialize mask: all weights alive (1 = keep, 0 = pruned)
    mask = {name: torch.ones_like(param.data)
            for name, param in model.named_parameters() if name in weight_names}

    PARAM_TARGET = 50000
    PRUNE_RATE   = 0.20
    pruning_round = 0

    print(f"Starting params: {count_nonzero(model):,}")

    while True:
        print(f"\n--- Round {pruning_round} | Non-zero params: {count_nonzero(model):,} ---")

        train_one_round(model, mask, train_loader, epochs=20)

        nz  = count_nonzero(model)
        acc = evaluate(model, test_loader)
        print(f"  After training: params={nz:,}, acc={acc:.4f}")

        if nz < PARAM_TARGET:
            print(f"  Reached target (<{PARAM_TARGET:,} params). Stopping.")
            break

        # Compute new mask (prune 20% of surviving non-zero weights globally)
        mask = compute_new_mask(model, weight_names, prune_fraction=PRUNE_RATE)

        # Reset ALL parameters (weights + biases) to θ₀, then apply new mask
        reset_to_theta0(model, theta_0, mask)

        pruning_round += 1

    # Final evaluation
    acc = evaluate(model, test_loader)
    nz  = count_nonzero(model)
    print(f"\nFinal: params={nz:,}, accuracy={acc:.4f}, rounds={pruning_round}")

    import os
    os.makedirs('/output', exist_ok=True)
    torch.save(model.state_dict(), '/output/lottery_ticket.pth')  # state_dict only, safe to load with weights_only=True
    with open('/output/results.json', 'w') as f:
        json.dump({
            "param_count": int(nz),
            "test_accuracy": round(acc, 4),
            "pruning_rounds": pruning_round
        }, f, indent=2)
    print("Saved /output/lottery_ticket.pth and /output/results.json")


if __name__ == '__main__':
    main()
