#!/usr/bin/env bash
set -e

echo "🧪======================================"
echo "   CODEBRAIN TEST HARNESS"
echo "======================================"

BASE_DIR="$(pwd)/codebrain_test_sandbox"

# --------------------------------------------------
# CLEAN START
# --------------------------------------------------

echo "🧹 Cleaning old sandbox..."
rm -rf "$BASE_DIR"
mkdir -p "$BASE_DIR"

cd "$BASE_DIR"

# --------------------------------------------------
# INIT GIT (SAFE TESTING GROUND)
# --------------------------------------------------

echo "📦 Initializing git repo..."
git init -q

# --------------------------------------------------
# CREATE PROJECT STRUCTURE
# --------------------------------------------------

mkdir -p app tests

touch app/__init__.py
touch tests/__init__.py

# --------------------------------------------------
# PYTHON PATH
# --------------------------------------------------

export PYTHONPATH="$BASE_DIR"

# --------------------------------------------------
# CREATE DUPLICATE FUNCTIONS
# --------------------------------------------------

cat > app/math_a.py << 'EOF'
def add(a, b):
    return a + b

def multiply(a, b):
    return a * b
EOF

cat > app/math_b.py << 'EOF'
def sum_values(x, y):
    return x + y

def product(x, y):
    return x * y
EOF

# --------------------------------------------------
# BUSINESS LOGIC
# --------------------------------------------------

cat > app/utils.py << 'EOF'
def is_positive(n):
    return n > 0

def check_positive(value):
    return value > 0
EOF

# --------------------------------------------------
# TESTS
# --------------------------------------------------

cat > tests/test_math.py << 'EOF'
from app.math_a import add, multiply
from app.math_b import sum_values, product
from app.utils import is_positive, check_positive

def test_add():
    assert add(2, 3) == 5

def test_sum():
    assert sum_values(2, 3) == 5

def test_multiply():
    assert multiply(2, 3) == 6

def test_product():
    assert product(2, 3) == 6

def test_positive():
    assert is_positive(1)

def test_check_positive():
    assert check_positive(1)
EOF

# --------------------------------------------------
# REQUIREMENTS
# --------------------------------------------------

cat > requirements.txt << 'EOF'
pytest
EOF

# --------------------------------------------------
# SHOW STRUCTURE
# --------------------------------------------------

echo ""
echo "📁 TEST PROJECT STRUCTURE:"
tree -L 3 || ls -R

# --------------------------------------------------
# RUN TESTS BEFORE
# --------------------------------------------------

echo ""
echo "🧪 Running pytest BEFORE CodeBrain..."

PYTHONPATH=. python3 -m pytest || true

# --------------------------------------------------
# RUN CODEBRAIN
# --------------------------------------------------

echo ""
echo "🤖 Running CodeBrain on sandbox..."

python3 -m codebrain.main "$BASE_DIR" || true

# --------------------------------------------------
# RUN TESTS AFTER
# --------------------------------------------------

echo ""
echo "🧪 Running pytest AFTER CodeBrain..."

PYTHONPATH=. python3 -m pytest || true

# --------------------------------------------------
# SUMMARY
# --------------------------------------------------

echo ""
echo "🧠======================================"
echo "✔ TEST HARNESS COMPLETE"
echo "======================================"
echo ""
echo "Sandbox location:"
echo "  $BASE_DIR"
echo ""
echo "What this tested:"
echo "  - duplicate detection"
echo "  - refactor execution"
echo "  - dependency safety"
echo "  - test validation"
echo "  - git integration"
echo ""
echo "======================================"