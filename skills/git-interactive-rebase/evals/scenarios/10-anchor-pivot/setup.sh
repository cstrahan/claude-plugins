#!/bin/bash
# Scenario 10: Anchor & Pivot — restructure implementation commits into before/after
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../../lib/setup-helpers.sh"

repo_dir=$(create_test_repo "10-anchor-pivot")

# Base state: an API module without pagination
make_commit "$repo_dir" "src/api.py" \
'def list_items(db):
    """Return all items from the database."""
    return db.query("SELECT * FROM items")' \
    "feat: add items API"

# Implementation commit 1: add pagination support
write_file_and_commit "$repo_dir" "src/api.py" "feat: add pagination to list_items" << 'EOF'
def list_items(db, offset=0, limit=100):
    """Return items with pagination support."""
    query = "SELECT * FROM items LIMIT ? OFFSET ?"
    items = db.query(query, (limit, offset))
    total = db.query("SELECT COUNT(*) FROM items")[0]
    return {
        "items": items,
        "total": total,
        "offset": offset,
        "limit": limit,
    }
EOF

# Implementation commit 2: add tests for the NEW behavior
write_file_and_commit "$repo_dir" "tests/test_api.py" "test: add pagination tests" << 'EOF'
from api import list_items

def test_list_items_default_pagination():
    db = MockDB(items=list(range(200)))
    result = list_items(db)
    assert result["total"] == 200
    assert result["offset"] == 0
    assert result["limit"] == 100
    assert len(result["items"]) == 100

def test_list_items_custom_pagination():
    db = MockDB(items=list(range(200)))
    result = list_items(db, offset=50, limit=25)
    assert result["offset"] == 50
    assert result["limit"] == 25

def test_list_items_returns_dict():
    db = MockDB(items=[1, 2, 3])
    result = list_items(db)
    assert isinstance(result, dict)
    assert "items" in result
    assert "total" in result
EOF

echo "$repo_dir"
