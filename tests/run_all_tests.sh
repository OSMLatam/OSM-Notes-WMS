#!/bin/bash

# Run all tests for OSM-Notes-WMS
# Master test runner - executes all test suites
# Author: Andres Gomez (AngocA)
# Version: 2026-01-27

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "======================================"
log_info "OSM-Notes-WMS Test Runner"
echo "======================================"
echo "Project Root: ${PROJECT_ROOT}"
echo ""

# Counter for overall results
TOTAL_SUITES=0
PASSED_SUITES=0
FAILED_SUITES=0

# Function to run a test suite
run_suite() {
    local suite_name="$1"
    local suite_command="$2"

    echo ""
    echo "======================================"
    log_info "Running ${suite_name}"
    echo "======================================"
    echo ""

    TOTAL_SUITES=$((TOTAL_SUITES + 1))

    if eval "$suite_command" 2>&1; then
        log_success "${suite_name} completed successfully"
        PASSED_SUITES=$((PASSED_SUITES + 1))
    else
        log_error "${suite_name} failed"
        FAILED_SUITES=$((FAILED_SUITES + 1))
    fi
}

# Check prerequisites
log_info "Checking prerequisites..."

# Check BATS
if ! command -v bats > /dev/null 2>&1; then
    log_warning "BATS not found. Unit and integration tests will be skipped."
    log_warning "Install BATS: git clone https://github.com/bats-core/bats-core.git && cd bats-core && ./install.sh /usr/local"
else
    log_success "BATS found"
fi

# Check PostgreSQL (optional for some tests)
if command -v psql > /dev/null 2>&1; then
    log_success "PostgreSQL client found"
else
    log_warning "PostgreSQL client not found (some tests may be skipped)"
fi

echo ""

# Run Unit Tests (BATS)
if command -v bats > /dev/null 2>&1 && [ -d "${SCRIPT_DIR}/unit/bash" ]; then
    UNIT_TEST_FILES=$(find "${SCRIPT_DIR}/unit/bash" -name "*.bats" -type f 2>/dev/null | wc -l)
    if [ "${UNIT_TEST_FILES}" -gt 0 ]; then
        run_suite "Unit Tests (BATS)" "bats -r ${SCRIPT_DIR}/unit/bash/"
    else
        log_warning "No unit test files found"
    fi
else
    log_warning "Skipping unit tests (BATS not available or no test files)"
fi

# Run Integration Tests (BATS)
if command -v bats > /dev/null 2>&1 && [ -d "${SCRIPT_DIR}/integration" ]; then
    INTEGRATION_TEST_FILES=$(find "${SCRIPT_DIR}/integration" -name "*.bats" -type f 2>/dev/null | wc -l)
    if [ "${INTEGRATION_TEST_FILES}" -gt 0 ]; then
        run_suite "Integration Tests (BATS)" "bats -r ${SCRIPT_DIR}/integration/"
    else
        log_warning "No integration test files found"
    fi
else
    log_warning "Skipping integration tests (BATS not available or no test files)"
fi

# Run CI Tests (if script exists)
if [ -f "${PROJECT_ROOT}/scripts/run_ci_tests.sh" ]; then
    run_suite "CI Tests (Formatting & Validation)" "bash ${PROJECT_ROOT}/scripts/run_ci_tests.sh"
else
    log_warning "CI tests script not found: scripts/run_ci_tests.sh"
fi

# Show final summary
echo ""
echo "======================================"
log_info "Overall Test Summary"
echo "======================================"
echo "Total Test Suites: ${TOTAL_SUITES}"
echo "Passed: ${PASSED_SUITES} ✅"
echo "Failed: ${FAILED_SUITES} ❌"
echo ""

if [[ ${FAILED_SUITES} -eq 0 ]]; then
    log_success "🎉 All test suites passed!"
    exit 0
else
    log_error "❌ ${FAILED_SUITES} test suite(s) failed"
    exit 1
fi
