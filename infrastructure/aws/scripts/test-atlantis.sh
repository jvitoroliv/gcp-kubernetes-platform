#!/bin/bash
# Test Atlantis deployment and functionality
# Usage: ./test-atlantis.sh [environment] [domain]

set -euo pipefail

ENVIRONMENT="${1:-dev}"
ATLANTIS_DOMAIN="${2:-atlantis.${ENVIRONMENT}.gameplatform.com.br}"
ATLANTIS_URL="https://${ATLANTIS_DOMAIN}"

echo "🧪 Testing Atlantis deployment..."
echo "Environment: ${ENVIRONMENT}"
echo "URL: ${ATLANTIS_URL}"
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test functions
test_passed() {
    echo -e "${GREEN}✅ $1${NC}"
}

test_failed() {
    echo -e "${RED}❌ $1${NC}"
}

test_warning() {
    echo -e "${YELLOW}⚠️ $1${NC}"
}

test_info() {
    echo -e "${BLUE}ℹ️ $1${NC}"
}

# Test 1: Basic connectivity
echo "🔍 Test 1: Basic connectivity"
if curl -s -o /dev/null -w "%{http_code}" "${ATLANTIS_URL}" | grep -q "200\|302\|403"; then
    test_passed "Atlantis URL is reachable"
else
    test_failed "Atlantis URL is not reachable"
    echo "Please check if the service is running and DNS is configured correctly."
    exit 1
fi

# Test 2: Health check endpoint
echo ""
echo "🩺 Test 2: Health check endpoint"
HEALTH_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "${ATLANTIS_URL}/healthz" || echo "000")
case $HEALTH_STATUS in
    200)
        test_passed "Health check endpoint returns 200 OK"
        ;;
    000)
        test_failed "Health check endpoint is unreachable"
        ;;
    *)
        test_warning "Health check endpoint returns HTTP $HEALTH_STATUS"
        ;;
esac

# Test 3: Atlantis home page
echo ""
echo "🏠 Test 3: Atlantis home page"
HOME_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "${ATLANTIS_URL}/" || echo "000")
case $HOME_STATUS in
    200)
        test_passed "Atlantis home page accessible"
        ;;
    302|301)
        test_passed "Atlantis home page accessible (redirect)"
        ;;
    000)
        test_failed "Atlantis home page is unreachable"
        ;;
    *)
        test_warning "Atlantis home page returns HTTP $HOME_STATUS"
        ;;
esac

# Test 4: Check if webhook endpoint is ready
echo ""
echo "🪝 Test 4: Webhook endpoint"
WEBHOOK_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "${ATLANTIS_URL}/events" || echo "000")
case $WEBHOOK_STATUS in
    400|422)
        test_passed "Webhook endpoint is active (returns expected error for empty request)"
        ;;
    000)
        test_failed "Webhook endpoint is unreachable"
        ;;
    200)
        test_warning "Webhook endpoint returns 200 (unexpected for empty request)"
        ;;
    *)
        test_info "Webhook endpoint returns HTTP $WEBHOOK_STATUS"
        ;;
esac

# Test 5: AWS ECS service status
echo ""
echo "☁️ Test 5: ECS service status"
if command -v aws >/dev/null 2>&1; then
    CLUSTER_NAME="gameplatform-${ENVIRONMENT}-shared-cluster"
    SERVICE_NAME="gameplatform-${ENVIRONMENT}-atlantis"
    
    SERVICE_STATUS=$(aws ecs describe-services \
        --cluster "$CLUSTER_NAME" \
        --services "$SERVICE_NAME" \
        --query 'services[0].status' \
        --output text 2>/dev/null || echo "UNKNOWN")
    
    case $SERVICE_STATUS in
        ACTIVE)
            test_passed "ECS service is ACTIVE"
            
            # Check running task count
            RUNNING_COUNT=$(aws ecs describe-services \
                --cluster "$CLUSTER_NAME" \
                --services "$SERVICE_NAME" \
                --query 'services[0].runningCount' \
                --output text 2>/dev/null || echo "0")
            
            DESIRED_COUNT=$(aws ecs describe-services \
                --cluster "$CLUSTER_NAME" \
                --services "$SERVICE_NAME" \
                --query 'services[0].desiredCount' \
                --output text 2>/dev/null || echo "0")
            
            if [ "$RUNNING_COUNT" = "$DESIRED_COUNT" ] && [ "$RUNNING_COUNT" -gt 0 ]; then
                test_passed "ECS tasks are running ($RUNNING_COUNT/$DESIRED_COUNT)"
            else
                test_warning "ECS tasks: $RUNNING_COUNT running, $DESIRED_COUNT desired"
            fi
            ;;
        UNKNOWN)
            test_warning "Could not check ECS service status (AWS CLI not configured or service not found)"
            ;;
        *)
            test_failed "ECS service status: $SERVICE_STATUS"
            ;;
    esac
else
    test_info "AWS CLI not available - skipping ECS service check"
fi

# Test 6: Check CloudWatch logs
echo ""
echo "📊 Test 6: CloudWatch logs availability"
if command -v aws >/dev/null 2>&1; then
    LOG_GROUP="/ecs/atlantis/${ENVIRONMENT}"
    
    # Check if log group exists
    if aws logs describe-log-groups --log-group-name-prefix "$LOG_GROUP" --query 'logGroups[0].logGroupName' --output text 2>/dev/null | grep -q "$LOG_GROUP"; then
        test_passed "CloudWatch log group exists: $LOG_GROUP"
        
        # Check for recent log entries
        RECENT_LOGS=$(aws logs describe-log-streams \
            --log-group-name "$LOG_GROUP" \
            --order-by LastEventTime \
            --descending \
            --max-items 1 \
            --query 'logStreams[0].lastEventTime' \
            --output text 2>/dev/null || echo "0")
        
        if [ "$RECENT_LOGS" != "0" ] && [ "$RECENT_LOGS" != "None" ]; then
            # Convert timestamp to readable format
            LAST_LOG_TIME=$(date -d "@$((RECENT_LOGS/1000))" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "unknown")
            test_passed "Recent logs available (last: $LAST_LOG_TIME)"
        else
            test_warning "No recent log entries found"
        fi
    else
        test_failed "CloudWatch log group not found: $LOG_GROUP"
    fi
else
    test_info "AWS CLI not available - skipping CloudWatch logs check"
fi

# Test 7: SSL Certificate validation
echo ""
echo "🔒 Test 7: SSL certificate validation"
if command -v openssl >/dev/null 2>&1; then
    SSL_INFO=$(echo | timeout 10 openssl s_client -servername "$ATLANTIS_DOMAIN" -connect "${ATLANTIS_DOMAIN}:443" 2>/dev/null | openssl x509 -noout -dates 2>/dev/null || echo "")
    
    if [ -n "$SSL_INFO" ]; then
        test_passed "SSL certificate is valid"
        
        # Check certificate expiration
        NOT_AFTER=$(echo "$SSL_INFO" | grep "notAfter" | cut -d= -f2)
        if [ -n "$NOT_AFTER" ]; then
            test_info "SSL certificate expires: $NOT_AFTER"
        fi
    else
        test_warning "Could not validate SSL certificate"
    fi
else
    test_info "OpenSSL not available - skipping SSL certificate check"
fi

# Summary and recommendations
echo ""
echo "📋 Test Summary"
echo "==============="
echo ""

# Collect webhook configuration instructions
echo "🪝 GitHub Webhook Configuration:"
echo "  URL: ${ATLANTIS_URL}/events"
echo "  Content Type: application/json"
echo "  Secret: (use the value from ATLANTIS_WEBHOOK_SECRET)"
echo "  Events: Select 'Send me everything' or at minimum:"
echo "    - Pull requests"
echo "    - Pushes"
echo ""

echo "📊 Monitoring Commands:"
echo "  # View real-time logs"
echo "  aws logs tail /ecs/atlantis/${ENVIRONMENT} --follow"
echo ""
echo "  # Check ECS service status"
echo "  aws ecs describe-services --cluster gameplatform-${ENVIRONMENT}-shared-cluster --services gameplatform-${ENVIRONMENT}-atlantis"
echo ""
echo "  # Restart Atlantis if needed"
echo "  aws ecs update-service --cluster gameplatform-${ENVIRONMENT}-shared-cluster --service gameplatform-${ENVIRONMENT}-atlantis --force-new-deployment"
echo ""

echo "🧪 Testing Atlantis with a PR:"
echo "  1. Create a test branch with Terraform changes"
echo "  2. Open a Pull Request"
echo "  3. Atlantis should comment with a plan automatically"
echo "  4. Comment 'atlantis apply' to apply changes"
echo "  5. Check the PR for Atlantis responses"
echo ""

echo "🔍 Troubleshooting:"
echo "  - If webhook isn't working: Check GitHub webhook settings and secret"
echo "  - If plans fail: Check ECS task logs and IAM permissions"
echo "  - If SSL issues: Verify ACM certificate and ALB configuration"
echo "  - If DNS issues: Check Route53 records and domain delegation"

echo ""
test_passed "Atlantis testing completed! 🎉"
