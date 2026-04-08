#!/bin/bash
# Scenario 04: Reorder commits (no conflict — separate files)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../../lib/setup-helpers.sh"

repo_dir=$(create_test_repo "04-reorder")

make_commit "$repo_dir" "src/models/user.py" \
'class User:
    def __init__(self, name):
        self.name = name' \
    "feat: add user model"

make_commit "$repo_dir" "src/models/product.py" \
'class Product:
    def __init__(self, name, price):
        self.name = name
        self.price = price' \
    "feat: add product model"

make_commit "$repo_dir" "src/models/order.py" \
'class Order:
    def __init__(self, user, products):
        self.user = user
        self.products = products' \
    "feat: add order model"

echo "$repo_dir"
