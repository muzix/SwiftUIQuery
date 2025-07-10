#!/bin/bash

echo "🧪 Running SwiftUI Query Tests with Swift Testing..."
echo "================================================"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Run tests with strict concurrency
echo -e "${YELLOW}Running tests with strict concurrency checks...${NC}"

swift test \
    -Xswiftc -strict-concurrency=complete \
    -Xswiftc -warn-concurrency \
    --parallel

# Capture exit code
TEST_EXIT_CODE=$?

if [ $TEST_EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✅ All tests passed!${NC}"
else
    echo -e "${RED}❌ Tests failed with exit code: $TEST_EXIT_CODE${NC}"
    exit $TEST_EXIT_CODE
fi

# Optional: Generate test coverage report
if command -v xcrun &> /dev/null; then
    echo -e "\n${YELLOW}Generating code coverage report...${NC}"
    swift test --enable-code-coverage
    
    # Find the latest .xcresult bundle
    XCRESULT=$(find .build -name '*.xcresult' -type d | head -n 1)
    
    if [ -n "$XCRESULT" ]; then
        echo -e "${GREEN}Coverage report available at: $XCRESULT${NC}"
    fi
fi

echo -e "\n${GREEN}Test run completed!${NC}"