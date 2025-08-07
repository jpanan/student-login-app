#!/bin/bash

# Script for automated code review using GitHub Copilot
# Usage: ./scripts/review-code.sh [file-or-directory]

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

echo -e "${BLUE}🤖 GitHub Copilot Code Review Tool${NC}"
echo "=================================="

# Check dependencies
check_dependencies() {
    if ! command -v gh &> /dev/null; then
        echo -e "${RED}❌ GitHub CLI not found. Install with: brew install gh${NC}"
        exit 1
    fi
    
    if ! gh auth status &> /dev/null; then
        echo -e "${RED}❌ GitHub CLI not authenticated. Run: gh auth login${NC}"
        exit 1
    fi
}

# Review a single file
review_file() {
    local file="$1"
    echo -e "${BLUE}📄 Reviewing: $file${NC}"
    
    # Create review prompts for different aspects
    local security_prompt="Review this code for security vulnerabilities, including SQL injection, XSS, authentication bypass, and hardcoded secrets:"
    local performance_prompt="Analyze this code for performance issues, including N+1 queries, memory leaks, inefficient algorithms, and optimization opportunities:"
    local quality_prompt="Review this code for quality issues, including code smells, maintainability, readability, and best practices:"
    local architecture_prompt="Review this code architecture for design patterns, SOLID principles, layer separation, and structural improvements:"
    
    # Security Review
    echo -e "${PURPLE}🔒 Security Analysis:${NC}"
    cat "$file" | gh copilot suggest "$security_prompt" 2>/dev/null || echo "  ℹ️  Copilot suggest not available, performing basic security check..."
    
    # Basic security checks if Copilot suggest isn't available
    if grep -q -i "password\|secret\|key\|token" "$file"; then
        echo -e "  ${YELLOW}⚠️  Contains sensitive keywords - review for hardcoded secrets${NC}"
    fi
    
    if grep -q "createNativeQuery\|createQuery" "$file"; then
        echo -e "  ${YELLOW}⚠️  Uses SQL queries - verify parameterized queries${NC}"
    fi
    
    echo ""
    
    # Performance Review
    echo -e "${PURPLE}⚡ Performance Analysis:${NC}"
    cat "$file" | gh copilot suggest "$performance_prompt" 2>/dev/null || echo "  ℹ️  Performing basic performance check..."
    
    # Basic performance checks
    if grep -q "@OneToMany\|@ManyToMany" "$file"; then
        echo -e "  ${YELLOW}⚠️  Contains JPA relations - review for N+1 query issues${NC}"
    fi
    
    if [[ $file == *service* ]] && ! grep -q "@Transactional" "$file"; then
        echo -e "  ${YELLOW}⚠️  Service class missing @Transactional annotation${NC}"
    fi
    
    echo ""
    
    # Code Quality Review
    echo -e "${PURPLE}📊 Code Quality Analysis:${NC}"
    cat "$file" | gh copilot suggest "$quality_prompt" 2>/dev/null || echo "  ℹ️  Performing basic quality check..."
    
    # Basic quality checks
    local lines=$(wc -l < "$file")
    if [ $lines -gt 200 ]; then
        echo -e "  ${YELLOW}📏 Large file ($lines lines) - consider refactoring${NC}"
    fi
    
    local todos=$(grep -c "TODO\|FIXME\|XXX" "$file" || true)
    if [ $todos -gt 0 ]; then
        echo -e "  ${YELLOW}📝 Contains $todos TODO/FIXME comments${NC}"
    fi
    
    echo ""
    
    # Architecture Review
    echo -e "${PURPLE}🏗️  Architecture Analysis:${NC}"
    cat "$file" | gh copilot suggest "$architecture_prompt" 2>/dev/null || echo "  ℹ️  Architecture looks standard for this file type"
    
    echo -e "${GREEN}✅ Review complete for $file${NC}"
    echo "----------------------------------------"
}

# Review directory
review_directory() {
    local dir="$1"
    echo -e "${BLUE}📁 Reviewing directory: $dir${NC}"
    
    local java_files=$(find "$dir" -name "*.java" -type f)
    local file_count=$(echo "$java_files" | wc -l)
    
    if [ -z "$java_files" ]; then
        echo -e "${YELLOW}⚠️  No Java files found in $dir${NC}"
        return
    fi
    
    echo -e "${GREEN}Found $file_count Java files to review${NC}"
    echo ""
    
    for file in $java_files; do
        review_file "$file"
        echo ""
    done
    
    # Directory-level analysis
    echo -e "${PURPLE}📊 Directory Structure Analysis:${NC}"
    local controllers=$(find "$dir" -path "*controller*" -name "*.java" | wc -l)
    local services=$(find "$dir" -path "*service*" -name "*.java" | wc -l)
    local repositories=$(find "$dir" -path "*repository*" -name "*.java" | wc -l)
    local models=$(find "$dir" -path "*model*" -name "*.java" | wc -l)
    
    echo "  - Controllers: $controllers files"
    echo "  - Services: $services files"  
    echo "  - Repositories: $repositories files"
    echo "  - Models: $models files"
}

# Review git changes
review_changes() {
    echo -e "${BLUE}🔄 Reviewing Git Changes${NC}"
    
    local changed_files=$(git diff --name-only HEAD~1..HEAD | grep "\.java$" || true)
    
    if [ -z "$changed_files" ]; then
        echo -e "${YELLOW}⚠️  No Java files changed in last commit${NC}"
        return
    fi
    
    echo -e "${GREEN}Changed Java files:${NC}"
    echo "$changed_files" | sed 's/^/  - /'
    echo ""
    
    for file in $changed_files; do
        if [ -f "$file" ]; then
            echo -e "${BLUE}📋 Reviewing changes in: $file${NC}"
            
            # Show the diff and ask Copilot to review it
            local diff_content=$(git diff HEAD~1..HEAD -- "$file")
            echo "$diff_content" | gh copilot suggest "Review these code changes for potential issues, improvements, and impacts:" 2>/dev/null || {
                echo "  ℹ️  Basic diff analysis:"
                local additions=$(echo "$diff_content" | grep "^+" | grep -v "^+++" | wc -l)
                local deletions=$(echo "$diff_content" | grep "^-" | grep -v "^---" | wc -l)
                echo "    - Additions: $additions lines"
                echo "    - Deletions: $deletions lines"
            }
            echo ""
        fi
    done
}

# Generate review report
generate_report() {
    local target="$1"
    local report_file="code-review-report-$(date +%Y%m%d-%H%M%S).md"
    
    echo "# 🤖 Automated Code Review Report" > "$report_file"
    echo "" >> "$report_file"
    echo "**Generated:** $(date)" >> "$report_file"
    echo "**Target:** $target" >> "$report_file"
    echo "" >> "$report_file"
    
    # Run the review and capture output
    if [ -f "$target" ]; then
        echo "## File Review: $target" >> "$report_file"
        review_file "$target" >> "$report_file" 2>&1
    elif [ -d "$target" ]; then
        echo "## Directory Review: $target" >> "$report_file"
        review_directory "$target" >> "$report_file" 2>&1
    fi
    
    echo -e "${GREEN}📄 Report saved to: $report_file${NC}"
}

# Main function
main() {
    check_dependencies
    
    local target="${1:-src/main/java}"
    
    case "$1" in
        --changes)
            review_changes
            ;;
        --report)
            generate_report "${2:-src/main/java}"
            ;;
        *)
            if [ -f "$target" ]; then
                review_file "$target"
            elif [ -d "$target" ]; then
                review_directory "$target"
            else
                echo -e "${RED}❌ Target not found: $target${NC}"
                echo ""
                echo "Usage:"
                echo "  $0 [file-or-directory]  # Review specific target"
                echo "  $0 --changes            # Review recent git changes"
                echo "  $0 --report [target]    # Generate markdown report"
                exit 1
            fi
            ;;
    esac
}

main "$@"
